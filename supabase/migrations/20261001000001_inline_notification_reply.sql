-- =============================================================================
-- VISAL Android notification inline reply capability
-- Eski uygulamalar normal FCM notification payload'ı almaya devam eder.
-- Yeni Android sürümü token'ı inline_reply=true olarak kaydeder ve data-only
-- push alarak RemoteInput / "Yanıtla" aksiyonunu kendisi oluşturur.
-- =============================================================================

alter table public.device_tokens
  add column if not exists inline_reply boolean not null default false;

-- Eski istemciler iki parametreli RPC'yi çağırır. Bir downgrade durumunda
-- capability yanlış kalmasın diye açıkça false'a çekeriz.
create or replace function public.claim_device_token(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapmalısınız.' using errcode = '28000';
  end if;
  if p_token is null or char_length(p_token) not between 20 and 4096 then
    raise exception 'Geçersiz jeton.' using errcode = 'P0001';
  end if;
  insert into public.device_tokens (token, user_id, platform, inline_reply, updated_at)
  values (p_token, auth.uid(), left(coalesce(p_platform, ''), 16), false, now())
  on conflict (token) do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    inline_reply = false,
    updated_at = now();
end;
$$;

-- Yeni istemci capability bilgisini üçüncü parametreyle bildirir.
create or replace function public.claim_device_token(
  p_token text,
  p_platform text,
  p_inline_reply boolean
)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then
    raise exception 'Giriş yapmalısınız.' using errcode = '28000';
  end if;
  if p_token is null or char_length(p_token) not between 20 and 4096 then
    raise exception 'Geçersiz jeton.' using errcode = 'P0001';
  end if;
  insert into public.device_tokens (token, user_id, platform, inline_reply, updated_at)
  values (
    p_token,
    auth.uid(),
    left(coalesce(p_platform, ''), 16),
    coalesce(p_inline_reply, false),
    now()
  )
  on conflict (token) do update set
    user_id = excluded.user_id,
    platform = excluded.platform,
    inline_reply = excluded.inline_reply,
    updated_at = now();
end;
$$;

revoke execute on function public.claim_device_token(text, text) from public, anon;
revoke execute on function public.claim_device_token(text, text, boolean) from public, anon;
grant execute on function public.claim_device_token(text, text) to authenticated;
grant execute on function public.claim_device_token(text, text, boolean) to authenticated;

-- take_push eski `tokens` alanını aynen korur. Yeni Edge Function ek olarak
-- `replyTokens` alanını okur; böylece migration ile function deploy sırası güvenlidir.
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
  reply_tokens text[];
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

  select
    array_agg(token),
    array_agg(token) filter (where lower(platform) = 'android' and inline_reply)
  into tokens, reply_tokens
  from public.device_tokens
  where user_id = row.user_id;

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
    'replyTokens', coalesce(reply_tokens, array[]::text[]),
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

revoke execute on function public.take_push(bigint, text) from public, anon, authenticated;
grant execute on function public.take_push(bigint, text) to service_role;
