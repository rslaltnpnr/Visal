-- =============================================================================
-- Zamanlanmış işler (pg_cron) ve push gönderimi (pg_net → send-push Edge Function)
-- =============================================================================

create extension if not exists pg_cron;
create extension if not exists pg_net with schema extensions;

-- Push kuyruğuna eklenen her satır send-push fonksiyonuna iletilir.
-- URL ve paylaşılan gizli anahtar private.config tablosundadır (CI doldurur);
-- tanımlı değilse push atlanır, uygulama içi bildirim kutusu yine çalışır.
create or replace function private.dispatch_push()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  url text := (select value from private.config where key = 'push_url');
  secret text := (select value from private.config where key = 'push_secret');
begin
  if url is null or secret is null then
    if new.inbox then
      insert into public.inbox (user_id, type, title, body, route)
      values (new.user_id, new.type, new.title, new.body, new.route);
    end if;
    delete from private.push_queue where id = new.id;
    return null;
  end if;
  perform net.http_post(
    url := url,
    headers := jsonb_build_object('Content-Type', 'application/json', 'x-visal-secret', secret),
    body := jsonb_build_object('id', new.id),
    timeout_milliseconds := 10000
  );
  return null;
end;
$$;

create trigger push_queue_dispatch after insert on private.push_queue
  for each row execute function private.dispatch_push();

-- Edge Function'ın kuyruk satırını okuyup silmesi için (service role ile çağrılır).
create or replace function public.take_push(p_id bigint, p_secret text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  row private.push_queue;
  prof public.profiles;
  tokens text[];
begin
  if p_secret is distinct from (select value from private.config where key = 'push_secret') then
    raise exception 'unauthorized' using errcode = '42501';
  end if;
  delete from private.push_queue where id = p_id returning * into row;
  if row is null then return null; end if;
  select * into prof from public.profiles where id = row.user_id;
  if row.inbox then
    insert into public.inbox (user_id, type, title, body, route)
    values (row.user_id, row.type, row.title, row.body, row.route);
  end if;
  if prof is null
     or (row.category <> 'pairing'
         and coalesce((prof.settings -> 'notifications' ->> row.category)::boolean, true) = false) then
    return null;
  end if;
  select array_agg(token) into tokens from public.device_tokens where user_id = row.user_id;
  return jsonb_build_object(
    'tokens', coalesce(tokens, '{}'),
    'hidden', coalesce((prof.settings -> 'privacy' ->> 'notificationPreview')::boolean, true) = false,
    'title', row.title,
    'body', row.body,
    'hiddenBody', coalesce(row.hidden_body, 'Yeni bildirim'),
    'type', row.type,
    'route', row.route,
    'collapseKey', row.collapse_key
  );
end;
$$;

create or replace function public.drop_device_tokens(p_tokens text[], p_secret text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_secret is distinct from (select value from private.config where key = 'push_secret') then
    raise exception 'unauthorized' using errcode = '42501';
  end if;
  delete from public.device_tokens where token = any (p_tokens);
end;
$$;

revoke execute on function public.take_push(bigint, text), public.drop_device_tokens(text[], text)
  from public, anon, authenticated;
grant execute on function public.take_push(bigint, text), public.drop_device_tokens(text[], text) to service_role;

-- CI (service_role) push uç noktasını ve paylaşılan gizli anahtarı yazar.
create or replace function public.set_push_config(p_url text, p_secret text)
returns void
language sql
security definer
set search_path = ''
as $$
  insert into private.config (key, value) values ('push_url', p_url), ('push_secret', p_secret)
  on conflict (key) do update set value = excluded.value;
$$;

revoke execute on function public.set_push_config(text, text) from public, anon, authenticated;
grant execute on function public.set_push_config(text, text) to service_role;

-- İşler (UTC). İstanbul = UTC+3.
select cron.schedule('visal-tick', '*/5 * * * *', $$select private.tick_five_minutes()$$);
select cron.schedule('visal-daily-morning', '0 6 * * *', $$select private.daily_morning()$$);
select cron.schedule('visal-purge', '30 0 * * *', $$
  select private.purge_archived();
  delete from private.push_queue where created_at < now() - interval '1 day';
$$);
