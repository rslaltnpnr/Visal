-- Yerel test için Supabase ortamının asgari taklidi (üretimde KULLANILMAZ).
create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;
grant usage on schema public to anon, authenticated, service_role;

create schema auth;
create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  raw_user_meta_data jsonb default '{}'::jsonb
);
create function auth.uid() returns uuid language sql stable as $$
  select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid
$$;
grant usage on schema auth to anon, authenticated;
grant execute on function auth.uid() to anon, authenticated;

create schema extensions;
create schema storage;
create table storage.buckets (
  id text primary key, name text, public boolean, file_size_limit bigint, allowed_mime_types text[]
);
create table storage.objects (
  id uuid primary key default gen_random_uuid(),
  bucket_id text references storage.buckets(id),
  name text
);
alter table storage.objects enable row level security;
grant usage on schema storage to authenticated;
grant select, insert, delete on storage.objects to authenticated;

create schema realtime;
create table realtime.messages (id bigserial primary key, topic text, payload jsonb);
create function realtime.topic() returns text language sql stable as $$
  select current_setting('realtime.topic', true)
$$;
alter table realtime.messages enable row level security;
grant usage on schema realtime to authenticated;
grant select, insert on realtime.messages to authenticated;
grant execute on function realtime.topic() to authenticated;
create publication supabase_realtime;

-- pg_cron / pg_net taklitleri
create schema cron;
create table cron.jobs (name text, schedule text, command text);
create function cron.schedule(n text, s text, c text) returns bigint language sql as $$
  insert into cron.jobs values (n, s, c); select 1::bigint;
$$;
create schema net;
create table net.requests (id bigserial, url text, headers jsonb, body jsonb);
create function net.http_post(url text, headers jsonb, body jsonb, timeout_milliseconds int)
returns bigint language sql as $$
  insert into net.requests (url, headers, body) values (url, headers, body) returning id;
$$;
