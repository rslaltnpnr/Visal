-- =============================================================================
-- VISAL production hardening
-- - Kapsül oluşturma tek transaction/RPC
-- - Push kuyruğu ACK + retry; FCM gönderilmeden kayıt silinmez
-- =============================================================================

-- ---------- Kapsüller: üst veri + içerik atomik --------------------------------
create or replace function public.create_capsule_atomic(
  p_id uuid,
  p_couple_id uuid,
  p_recipient_id uuid,
  p_open_at timestamptz,
  p_title text,
  p_message text,
  p_media jsonb,
  p_has_photo boolean,
  p_has_video boolean,
  p_has_audio boolean
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  insert into public.capsules (
    id, couple_id, created_by, recipient_id, open_at, title,
    has_photo, has_video, has_audio
  ) values (
    p_id, p_couple_id, auth.uid(), p_recipient_id, p_open_at, trim(p_title),
    p_has_photo, p_has_video, p_has_audio
  );

  insert into public.capsule_contents (capsule_id, message, media)
  values (p_id, trim(p_message), coalesce(p_media, '[]'::jsonb));
end;
$$;

revoke execute on function public.create_capsule_atomic(
  uuid, uuid, uuid, timestamptz, text, text, jsonb, boolean, boolean, boolean
) from public, anon;
grant execute on function public.create_capsule_atomic(
  uuid, uuid, uuid, timestamptz, text, text, jsonb, boolean, boolean, boolean
) to authenticated;

-- ---------- Push: teslim edilene kadar kuyrukta tut ------------------------------
alter table private.push_queue
  add column if not exists attempts integer not null default 0,
  add column if not exists next_attempt_at timestamptz not null default now(),
  add column if not exists processing_at timestamptz,
  add column if not exists inbox_delivered boolean not null default false,
  add column if not exists last_error text;

-- Edge Function kaydı alır ama SİLMEZ. Başarılı FCM sonrası complete_push siler.
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

  select * into row
  from private.push_queue
  where id = p_id
  for update;

  if row is null then return null; end if;
  if row.next_attempt_at > now() then return null; end if;
  if row.processing_at is not null and row.processing_at > now() - interval '5 minutes' then
    return null;
  end if;

  if row.inbox and not row.inbox_delivered then
    insert into public.inbox (user_id, type, title, body, route)
    values (row.user_id, row.type, row.title, row.body, row.route);
    update private.push_queue set inbox_delivered = true where id = p_id;
  end if;

  select * into prof from public.profiles where id = row.user_id;
  if prof is null
     or (row.category <> 'pairing'
         and coalesce((prof.settings -> 'notifications' ->> row.category)::boolean, true) = false) then
    delete from private.push_queue where id = p_id;
    return null;
  end if;

  select array_agg(token) into tokens from public.device_tokens where user_id = row.user_id;
  if coalesce(cardinality(tokens), 0) = 0 then
    delete from private.push_queue where id = p_id;
    return null;
  end if;

  update private.push_queue
  set attempts = attempts + 1,
      processing_at = now(),
      last_error = null
  where id = p_id;

  return jsonb_build_object(
    'tokens', tokens,
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

create or replace function public.complete_push(p_id bigint, p_secret text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_secret is distinct from (select value from private.config where key = 'push_secret') then
    raise exception 'unauthorized' using errcode = '42501';
  end if;
  delete from private.push_queue where id = p_id;
end;
$$;

create or replace function public.retry_push(p_id bigint, p_secret text, p_error text default null)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_secret is distinct from (select value from private.config where key = 'push_secret') then
    raise exception 'unauthorized' using errcode = '42501';
  end if;

  update private.push_queue
  set processing_at = null,
      last_error = left(coalesce(p_error, 'push failed'), 1000),
      next_attempt_at = now() + make_interval(
        secs => least(900, (30 * power(2, greatest(attempts - 1, 0)))::integer)
      )
  where id = p_id;
end;
$$;

revoke execute on function public.take_push(bigint, text),
  public.complete_push(bigint, text), public.retry_push(bigint, text, text)
  from public, anon, authenticated;
grant execute on function public.take_push(bigint, text),
  public.complete_push(bigint, text), public.retry_push(bigint, text, text)
  to service_role;

-- İlk HTTP çağrısı ağ/Edge Function seviyesinde kaybolursa veya işlem ortada
-- kalırsa kuyruktaki hazır kayıtları yeniden gönderir.
create or replace function private.dispatch_due_pushes()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  url text := (select value from private.config where key = 'push_url');
  secret text := (select value from private.config where key = 'push_secret');
  r record;
begin
  if url is null or secret is null then return; end if;

  for r in
    select id
    from private.push_queue
    where next_attempt_at <= now()
      and (processing_at is null or processing_at < now() - interval '5 minutes')
      and attempts < 6
    order by id
    limit 100
  loop
    perform net.http_post(
      url := url,
      headers := jsonb_build_object('Content-Type', 'application/json', 'x-visal-secret', secret),
      body := jsonb_build_object('id', r.id),
      timeout_milliseconds := 10000
    );
  end loop;
end;
$$;

select cron.schedule('visal-push-retry', '* * * * *', $$select private.dispatch_due_pushes()$$);
