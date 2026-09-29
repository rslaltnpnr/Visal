-- =============================================================================
-- VISAL — veritabanı şeması, güvenlik politikaları (RLS) ve sunucu fonksiyonları
--
-- İlkeler:
--  * Kullanıcı yalnızca kendi profiles satırını okur/yazar.
--  * couples ve ona bağlı tüm tablolar yalnızca members dizisindeki iki kişiye
--    açıktır; couple_id tahmin edilse bile üçüncü kişi erişemez.
--  * Eşleşme (couple_id / members) yalnızca SECURITY DEFINER fonksiyonlarla
--    yazılır; istemcinin bu kolonlara doğrudan yazma yetkisi yoktur.
--  * Arşivlenen (eşleşmesi biten) çift alanı herkese kapanır.
-- =============================================================================

create extension if not exists pgcrypto with schema extensions;

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

-- -----------------------------------------------------------------------------
-- Tablolar
-- -----------------------------------------------------------------------------

create table public.couples (
  id uuid primary key default gen_random_uuid(),
  members uuid[] not null check (cardinality(members) = 2),
  status text not null default 'active' check (status in ('active', 'archived')),
  relationship_start_date date,
  anniversary_date date,
  theme text not null default 'default',
  cover_photo text,
  cover_path text,
  created_at timestamptz not null default now(),
  archived_at timestamptz,
  archived_by uuid,
  purge_at timestamptz
);
create index couples_members_idx on public.couples using gin (members);

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  name text not null default '' check (char_length(name) <= 80),
  email text not null default '',
  photo_url text,
  couple_id uuid references public.couples (id) on delete set null,
  birthday date,
  created_at timestamptz not null default now(),
  last_seen timestamptz,
  chat_last_read_at timestamptz,
  settings jsonb not null default '{
    "privacy": {"showOnline": true, "showLastSeen": true, "readReceipts": true,
                "notificationPreview": true, "moodVisible": true},
    "notifications": {"messages": true, "love": true, "memories": true,
                      "capsules": true, "events": true, "dailyQuestion": true}
  }'::jsonb
);

-- Partnerin görebildiği profil kopyası (profiles yalnızca sahibine açık).
create table public.couple_members (
  couple_id uuid not null references public.couples (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null default '',
  photo_url text,
  birthday date,
  mood_visible boolean not null default true,
  last_seen timestamptz,
  primary key (couple_id, user_id)
);

create table public.device_tokens (
  token text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  platform text not null default '',
  updated_at timestamptz not null default now()
);
create index device_tokens_user_idx on public.device_tokens (user_id);

create table public.inbox (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  type text not null,
  title text not null,
  body text not null default '',
  route text,
  read boolean not null default false,
  created_at timestamptz not null default now()
);
create index inbox_user_idx on public.inbox (user_id, created_at desc);

create table private.invites (
  code text primary key,
  user_id uuid not null references auth.users (id) on delete cascade,
  used boolean not null default false,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null
);

create table public.pair_requests (
  id uuid primary key default gen_random_uuid(),
  from_uid uuid not null references auth.users (id) on delete cascade,
  from_name text not null default '',
  from_photo text,
  to_uid uuid not null references auth.users (id) on delete cascade,
  to_name text not null default '',
  code text not null,
  status text not null default 'pending'
    check (status in ('pending', 'accepted', 'rejected', 'cancelled', 'expired')),
  couple_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);
create index pair_requests_to_idx on public.pair_requests (to_uid, status);
create index pair_requests_from_idx on public.pair_requests (from_uid, created_at desc);

create table public.messages (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  sender_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  type text not null check (type in ('text', 'image', 'video', 'voice', 'file', 'gif', 'love')),
  text text check (char_length(text) <= 4000),
  media_url text,
  media jsonb,
  reply_to jsonb,
  reactions jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  edited_at timestamptz,
  seen_by uuid[] not null default '{}',
  deleted_for uuid[] not null default '{}',
  deleted_for_all boolean not null default false,
  pinned boolean not null default false,
  pinned_at timestamptz,
  love_kind text check (love_kind in ('love', 'miss', 'home', 'coffee', 'call', 'kiss')),
  check (type <> 'text' or char_length(coalesce(text, '')) > 0),
  check (type <> 'love' or love_kind is not null),
  check (type in ('text', 'love') or media_url is not null or deleted_for_all)
);
create index messages_couple_created_idx on public.messages (couple_id, created_at desc);

create table public.memories (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  description text not null default '' check (char_length(description) <= 2000),
  date date not null,
  month_day text generated always as (
    lpad(extract(month from date)::int::text, 2, '0') || '-' || lpad(extract(day from date)::int::text, 2, '0')
  ) stored,
  media jsonb not null default '[]'::jsonb check (jsonb_typeof(media) = 'array' and jsonb_array_length(media) <= 30),
  location text check (char_length(location) <= 120),
  emoji text check (char_length(emoji) <= 16),
  music_url text check (char_length(music_url) <= 2048),
  is_special boolean not null default false,
  is_travel boolean not null default false,
  has_photo boolean not null default false,
  has_video boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz
);
create index memories_couple_date_idx on public.memories (couple_id, date desc);
create index memories_couple_md_idx on public.memories (couple_id, month_day);

create table public.timeline (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  type text not null check (type in ('firstMessage', 'firstDate', 'engagement', 'marriage', 'firstTrip', 'custom')),
  title text not null check (char_length(title) between 1 and 80),
  date date not null,
  description text not null default '' check (char_length(description) <= 1000),
  photo_url text,
  photo_path text,
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  updated_at timestamptz
);
create index timeline_couple_idx on public.timeline (couple_id, date);

create table public.events (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  category text not null check (category in ('special', 'date', 'activity', 'travel', 'home', 'birthday', 'anniversary')),
  date date not null,
  starts_at timestamptz not null,
  time text check (time ~ '^[0-2][0-9]:[0-5][0-9]$'),
  location text check (char_length(location) <= 120),
  note text check (char_length(note) <= 1000),
  reminder int check (reminder between 0 and 43200),
  repeat text not null default 'none' check (repeat in ('none', 'daily', 'weekly', 'monthly', 'yearly')),
  color bigint,
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz,
  next_reminder_at timestamptz
);
create index events_couple_date_idx on public.events (couple_id, date);
create index events_reminder_idx on public.events (next_reminder_at) where next_reminder_at is not null;

create table public.tasks (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 120),
  description text not null default '' check (char_length(description) <= 1000),
  due_date date,
  assignee text not null default 'both',
  done boolean not null default false,
  done_by uuid,
  done_at timestamptz,
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);
create index tasks_couple_idx on public.tasks (couple_id, created_at desc);

create table public.goals (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  title text not null check (char_length(title) between 1 and 80),
  current numeric not null default 0 check (current >= 0),
  target numeric not null check (target > 0),
  unit text not null default '' check (char_length(unit) <= 24),
  emoji text not null default '🎯',
  step numeric not null default 1 check (step > 0),
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  created_at timestamptz not null default now()
);

create table public.moods (
  couple_id uuid not null references public.couples (id) on delete cascade,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  day date not null,
  emoji text not null check (emoji in ('😍', '😊', '🙂', '😐', '😔', '😡', '🥱', '🤒')),
  created_at timestamptz not null default now(),
  primary key (couple_id, user_id, day)
);

create table public.questions (
  couple_id uuid not null references public.couples (id) on delete cascade,
  id text not null check (id ~ '^(d_[0-9]{4}-[0-9]{2}-[0-9]{2}|b_[0-9]+)$'),
  text text not null check (char_length(text) between 1 and 300),
  category text not null,
  bank_id text,
  day date,
  answered_by uuid[] not null default '{}',
  created_at timestamptz not null default now(),
  primary key (couple_id, id)
);

create table public.answers (
  couple_id uuid not null,
  question_id text not null,
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  text text not null check (char_length(text) between 1 and 1000),
  created_at timestamptz not null default now(),
  primary key (couple_id, question_id, user_id),
  foreign key (couple_id, question_id) references public.questions (couple_id, id) on delete cascade
);

create table public.capsules (
  id uuid primary key default gen_random_uuid(),
  couple_id uuid not null references public.couples (id) on delete cascade,
  created_by uuid not null default auth.uid() references auth.users (id) on delete cascade,
  recipient_id uuid not null references auth.users (id) on delete cascade,
  open_at timestamptz not null,
  title text not null default '' check (char_length(title) <= 60),
  has_photo boolean not null default false,
  has_video boolean not null default false,
  has_audio boolean not null default false,
  notified boolean not null default false,
  created_at timestamptz not null default now()
);
create index capsules_couple_idx on public.capsules (couple_id, open_at);
create index capsules_due_idx on public.capsules (open_at) where not notified;

-- İçerik ayrı tabloda: açılma zamanından önce yalnızca oluşturana açık.
create table public.capsule_contents (
  capsule_id uuid primary key references public.capsules (id) on delete cascade,
  message text not null default '' check (char_length(message) <= 5000),
  media jsonb not null default '[]'::jsonb check (jsonb_typeof(media) = 'array' and jsonb_array_length(media) <= 10)
);

-- Push kuyruğu: tetikleyiciler yazar, send-push Edge Function işler.
create table private.push_queue (
  id bigint generated always as identity primary key,
  user_id uuid not null,
  category text not null,
  type text not null,
  title text not null,
  body text not null,
  hidden_body text,
  route text not null,
  collapse_key text,
  inbox boolean not null default false,
  created_at timestamptz not null default now()
);

-- Ortam ayarları (Edge Function URL'si ve paylaşılan gizli anahtar). CI doldurur.
create table private.config (
  key text primary key,
  value text not null
);

-- -----------------------------------------------------------------------------
-- Yardımcı fonksiyonlar
-- -----------------------------------------------------------------------------

create or replace function public.is_member(cid uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.couples c
    where c.id = cid and auth.uid() = any (c.members) and c.status = 'active'
  );
$$;

create or replace function public.my_couple_id()
returns uuid
language sql
stable
security definer
set search_path = ''
as $$
  select p.couple_id from public.profiles p where p.id = auth.uid();
$$;

-- RLS içinde kendi tablosunu sorgulamamak için (özyineleme olmasın).
create or replace function public.has_answered(cid uuid, qid text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.answers a
    where a.couple_id = cid and a.question_id = qid and a.user_id = auth.uid()
  );
$$;

create or replace function private.partner_of(cid uuid, uid uuid)
returns uuid
language sql
stable
set search_path = ''
as $$
  select m from public.couples c, unnest(c.members) m where c.id = cid and m <> uid limit 1;
$$;

create or replace function private.first_name(n text)
returns text
language sql
immutable
as $$ select coalesce(nullif(split_part(trim(coalesce(n, '')), ' ', 1), ''), 'Partnerin'); $$;

create or replace function private.enqueue_push(
  p_user uuid, p_category text, p_type text, p_title text, p_body text,
  p_route text, p_hidden text default null, p_inbox boolean default false,
  p_collapse text default null
) returns void
language sql
security definer
set search_path = ''
as $$
  insert into private.push_queue (user_id, category, type, title, body, hidden_body, route, inbox, collapse_key)
  values (p_user, p_category, p_type, p_title, p_body, p_hidden, p_route, p_inbox, p_collapse);
$$;

-- -----------------------------------------------------------------------------
-- Yeni kullanıcı → profiles satırı
-- -----------------------------------------------------------------------------

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, name, email, photo_url)
  values (
    new.id,
    left(coalesce(
      nullif(new.raw_user_meta_data ->> 'name', ''),
      nullif(new.raw_user_meta_data ->> 'full_name', ''),
      split_part(coalesce(new.email, ''), '@', 1),
      'VISAL'
    ), 80),
    coalesce(new.email, ''),
    new.raw_user_meta_data ->> 'avatar_url'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- profiles değişince partnerin gördüğü kopyayı güncelle.
create or replace function private.sync_member_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  if new.couple_id is not null then
    update public.couple_members m set
      name = new.name,
      photo_url = new.photo_url,
      birthday = new.birthday,
      mood_visible = coalesce((new.settings -> 'privacy' ->> 'moodVisible')::boolean, true),
      last_seen = case
        when coalesce((new.settings -> 'privacy' ->> 'showLastSeen')::boolean, true) then new.last_seen
        else null end
    where m.couple_id = new.couple_id and m.user_id = new.id;
  end if;
  return new;
end;
$$;

create trigger profiles_sync_member
  after update of name, photo_url, birthday, settings, last_seen on public.profiles
  for each row execute function private.sync_member_profile();

-- -----------------------------------------------------------------------------
-- Satır düzeyi güvenlik (RLS)
-- -----------------------------------------------------------------------------

alter table public.couples enable row level security;
alter table public.profiles enable row level security;
alter table public.couple_members enable row level security;
alter table public.device_tokens enable row level security;
alter table public.inbox enable row level security;
alter table public.pair_requests enable row level security;
alter table public.messages enable row level security;
alter table public.memories enable row level security;
alter table public.timeline enable row level security;
alter table public.events enable row level security;
alter table public.tasks enable row level security;
alter table public.goals enable row level security;
alter table public.moods enable row level security;
alter table public.questions enable row level security;
alter table public.answers enable row level security;
alter table public.capsules enable row level security;
alter table public.capsule_contents enable row level security;

-- Tablo yetkileri: varsayılanları kapat, gerekenleri tek tek aç.
revoke all on all tables in schema public from anon, authenticated;

-- profiles: yalnızca sahibi; couple_id / email / id yazılamaz.
grant select on public.profiles to authenticated;
grant update (name, photo_url, birthday, settings, last_seen, chat_last_read_at) on public.profiles to authenticated;
create policy profiles_select on public.profiles for select to authenticated using (id = auth.uid());
create policy profiles_update on public.profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());

-- couples: üyeler okur; yalnızca tarih/tema/kapak güncellenir.
grant select on public.couples to authenticated;
grant update (relationship_start_date, anniversary_date, theme, cover_photo, cover_path) on public.couples to authenticated;
create policy couples_select on public.couples for select to authenticated
  using (auth.uid() = any (members) and status = 'active');
create policy couples_update on public.couples for update to authenticated
  using (public.is_member(id)) with check (public.is_member(id));

grant select on public.couple_members to authenticated;
create policy couple_members_select on public.couple_members for select to authenticated
  using (public.is_member(couple_id));

grant select, insert, update, delete on public.device_tokens to authenticated;
create policy device_tokens_all on public.device_tokens for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select on public.inbox to authenticated;
grant update (read) on public.inbox to authenticated;
create policy inbox_select on public.inbox for select to authenticated using (user_id = auth.uid());
create policy inbox_update on public.inbox for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

grant select on public.pair_requests to authenticated;
create policy pair_requests_select on public.pair_requests for select to authenticated
  using (from_uid = auth.uid() or to_uid = auth.uid());

-- messages: ekleme doğrudan; düzenleme/silme/tepki/okundu RPC ile.
grant select, insert on public.messages to authenticated;
create policy messages_select on public.messages for select to authenticated
  using (public.is_member(couple_id));
create policy messages_insert on public.messages for insert to authenticated
  with check (
    public.is_member(couple_id)
    and sender_id = auth.uid()
    and seen_by = array[auth.uid()]
    and deleted_for = '{}'
    and reactions = '{}'::jsonb
    and not deleted_for_all
    and not pinned
    and edited_at is null
  );

-- memories / timeline / events / tasks / goals: iki üye de okur, yazar, siler.
grant select, insert, update, delete on public.memories, public.timeline, public.events, public.tasks, public.goals to authenticated;
revoke update (created_by, couple_id) on public.memories, public.timeline, public.events, public.tasks, public.goals from authenticated;
revoke update (next_reminder_at) on public.events from authenticated;

create policy memories_select on public.memories for select to authenticated using (public.is_member(couple_id));
create policy memories_insert on public.memories for insert to authenticated
  with check (public.is_member(couple_id) and created_by = auth.uid());
create policy memories_update on public.memories for update to authenticated
  using (public.is_member(couple_id)) with check (public.is_member(couple_id));
create policy memories_delete on public.memories for delete to authenticated using (public.is_member(couple_id));

create policy timeline_select on public.timeline for select to authenticated using (public.is_member(couple_id));
create policy timeline_insert on public.timeline for insert to authenticated
  with check (public.is_member(couple_id) and created_by = auth.uid());
create policy timeline_update on public.timeline for update to authenticated
  using (public.is_member(couple_id)) with check (public.is_member(couple_id));
create policy timeline_delete on public.timeline for delete to authenticated using (public.is_member(couple_id));

create policy events_select on public.events for select to authenticated using (public.is_member(couple_id));
create policy events_insert on public.events for insert to authenticated
  with check (public.is_member(couple_id) and created_by = auth.uid());
create policy events_update on public.events for update to authenticated
  using (public.is_member(couple_id)) with check (public.is_member(couple_id));
create policy events_delete on public.events for delete to authenticated using (public.is_member(couple_id));

create policy tasks_select on public.tasks for select to authenticated using (public.is_member(couple_id));
create policy tasks_insert on public.tasks for insert to authenticated
  with check (
    public.is_member(couple_id) and created_by = auth.uid()
    and (assignee = 'both' or exists (select 1 from public.couples c where c.id = couple_id and assignee = any (c.members::text[])))
  );
create policy tasks_update on public.tasks for update to authenticated
  using (public.is_member(couple_id))
  with check (
    public.is_member(couple_id)
    and (assignee = 'both' or exists (select 1 from public.couples c where c.id = couple_id and assignee = any (c.members::text[])))
  );
create policy tasks_delete on public.tasks for delete to authenticated using (public.is_member(couple_id));

create policy goals_select on public.goals for select to authenticated using (public.is_member(couple_id));
create policy goals_insert on public.goals for insert to authenticated
  with check (public.is_member(couple_id) and created_by = auth.uid());
create policy goals_update on public.goals for update to authenticated
  using (public.is_member(couple_id)) with check (public.is_member(couple_id));
create policy goals_delete on public.goals for delete to authenticated using (public.is_member(couple_id));

-- moods: kendi kaydını yazar; partnerinki yalnızca görünür yaptıysa okunur.
grant select, insert, update on public.moods to authenticated;
revoke update (couple_id, user_id, day) on public.moods from authenticated;
create policy moods_select on public.moods for select to authenticated
  using (
    public.is_member(couple_id) and (
      user_id = auth.uid()
      or exists (
        select 1 from public.couple_members m
        where m.couple_id = moods.couple_id and m.user_id = moods.user_id and m.mood_visible
      )
    )
  );
create policy moods_insert on public.moods for insert to authenticated
  with check (public.is_member(couple_id) and user_id = auth.uid());
create policy moods_update on public.moods for update to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid() and public.is_member(couple_id));

-- questions: üyeler açar; answered_by yalnızca cevap tetikleyicisiyle güncellenir.
grant select, insert on public.questions to authenticated;
create policy questions_select on public.questions for select to authenticated using (public.is_member(couple_id));
create policy questions_insert on public.questions for insert to authenticated
  with check (public.is_member(couple_id) and answered_by = '{}');

-- answers: partnerin cevabı, kullanıcı kendi cevabını yazmadan okunamaz.
grant select, insert on public.answers to authenticated;
create policy answers_select on public.answers for select to authenticated
  using (
    public.is_member(couple_id) and (
      user_id = auth.uid() or public.has_answered(couple_id, question_id)
    )
  );
create policy answers_insert on public.answers for insert to authenticated
  with check (public.is_member(couple_id) and user_id = auth.uid());

-- capsules: üst veri çifte açık; içerik açılma zamanına kadar yalnızca oluşturana.
grant select, insert, delete on public.capsules to authenticated;
create policy capsules_select on public.capsules for select to authenticated using (public.is_member(couple_id));
create policy capsules_insert on public.capsules for insert to authenticated
  with check (
    public.is_member(couple_id)
    and created_by = auth.uid()
    and recipient_id <> auth.uid()
    and exists (select 1 from public.couples c where c.id = couple_id and recipient_id = any (c.members))
    and open_at > now()
    and not notified
  );
create policy capsules_delete on public.capsules for delete to authenticated
  using (created_by = auth.uid() and now() < open_at and public.is_member(couple_id));

grant select, insert on public.capsule_contents to authenticated;
create policy capsule_contents_select on public.capsule_contents for select to authenticated
  using (exists (
    select 1 from public.capsules c
    where c.id = capsule_id and public.is_member(c.couple_id)
      and (c.created_by = auth.uid() or now() >= c.open_at)
  ));
create policy capsule_contents_insert on public.capsule_contents for insert to authenticated
  with check (exists (
    select 1 from public.capsules c
    where c.id = capsule_id and c.created_by = auth.uid() and public.is_member(c.couple_id)
  ));

-- -----------------------------------------------------------------------------
-- Eşleşme (RPC)
-- -----------------------------------------------------------------------------

create or replace function public.create_invite()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  alphabet constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
  expires timestamptz := now() + interval '24 hours';
  i int;
begin
  if uid is null then raise exception 'Giriş yapmalısınız.' using errcode = '28000'; end if;
  if (select couple_id from public.profiles where id = uid) is not null then
    raise exception 'Zaten bir partnerle eşleşmişsiniz.' using errcode = 'P0001';
  end if;
  delete from private.invites where user_id = uid;
  loop
    code := 'VISAL-';
    for i in 1..5 loop
      code := code || substr(alphabet, 1 + floor(random() * length(alphabet))::int, 1);
    end loop;
    begin
      insert into private.invites (code, user_id, expires_at) values (code, uid, expires);
      exit;
    exception when unique_violation then
      -- çakışma: yeni kod dene
    end;
  end loop;
  return jsonb_build_object('code', code, 'expiresAt', (extract(epoch from expires) * 1000)::bigint);
end;
$$;

create or replace function public.request_pairing(p_code text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  inv private.invites;
  me public.profiles;
  inviter public.profiles;
  req_id uuid;
  norm text := upper(trim(coalesce(p_code, '')));
begin
  if uid is null then raise exception 'Giriş yapmalısınız.' using errcode = '28000'; end if;
  if norm !~ '^VISAL-[A-HJ-NP-Z2-9]{5}$' then
    raise exception 'Kod geçersiz.' using errcode = 'P0001';
  end if;
  select * into inv from private.invites where code = norm;
  if inv is null or inv.used or inv.expires_at < now() then
    raise exception 'Bu kod geçersiz veya süresi dolmuş.' using errcode = 'P0001';
  end if;
  if inv.user_id = uid then raise exception 'Kendi kodunuzu giremezsiniz.' using errcode = 'P0001'; end if;
  select * into me from public.profiles where id = uid;
  select * into inviter from public.profiles where id = inv.user_id;
  if me.couple_id is not null then raise exception 'Zaten bir partnerle eşleşmişsiniz.' using errcode = 'P0001'; end if;
  if inviter.couple_id is not null then
    raise exception 'Bu kullanıcı başka biriyle eşleşmiş.' using errcode = 'P0001';
  end if;

  update public.pair_requests set status = 'cancelled', updated_at = now()
    where from_uid = uid and status = 'pending';
  insert into public.pair_requests (from_uid, from_name, from_photo, to_uid, to_name, code)
    values (uid, me.name, me.photo_url, inviter.id, inviter.name, norm)
    returning id into req_id;

  perform private.enqueue_push(inviter.id, 'pairing', 'pairing', 'Eşleşme isteği',
    private.first_name(me.name) || ' sizinle VISAL''da eşleşmek istiyor.',
    '/pairing/request/' || req_id, 'Yeni bir eşleşme isteği', true);

  return jsonb_build_object('requestId', req_id, 'inviterName', inviter.name);
end;
$$;

create or replace function public.respond_pairing(p_request_id uuid, p_accept boolean)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  r public.pair_requests;
  a public.profiles;
  b public.profiles;
  cid uuid;
begin
  if uid is null then raise exception 'Giriş yapmalısınız.' using errcode = '28000'; end if;
  select * into r from public.pair_requests where id = p_request_id for update;
  if r is null or r.to_uid <> uid then raise exception 'Bu istek size ait değil.' using errcode = '42501'; end if;
  if r.status <> 'pending' then raise exception 'Bu istek artık geçerli değil.' using errcode = 'P0001'; end if;

  if not coalesce(p_accept, false) then
    update public.pair_requests set status = 'rejected', updated_at = now() where id = r.id;
    perform private.enqueue_push(r.from_uid, 'pairing', 'pairing', 'Eşleşme isteği',
      private.first_name(r.to_name) || ' isteğinizi kabul etmedi.', '/pairing', null, true);
    return jsonb_build_object('ok', true);
  end if;

  -- İki profili sabit sırayla kilitle (kilitlenme olmaması için).
  perform 1 from public.profiles where id in (r.to_uid, r.from_uid) order by id for update;
  select * into a from public.profiles where id = r.to_uid;
  select * into b from public.profiles where id = r.from_uid;
  if a.couple_id is not null or b.couple_id is not null then
    update public.pair_requests set status = 'expired', updated_at = now() where id = r.id;
    raise exception 'Taraflardan biri zaten eşleşmiş.' using errcode = 'P0001';
  end if;

  insert into public.couples (members) values (array[a.id, b.id]) returning id into cid;
  insert into public.couple_members (couple_id, user_id, name, photo_url, birthday, mood_visible)
  values
    (cid, a.id, a.name, a.photo_url, a.birthday, coalesce((a.settings -> 'privacy' ->> 'moodVisible')::boolean, true)),
    (cid, b.id, b.name, b.photo_url, b.birthday, coalesce((b.settings -> 'privacy' ->> 'moodVisible')::boolean, true));
  update public.profiles set couple_id = cid where id in (a.id, b.id);
  update public.pair_requests set status = 'accepted', couple_id = cid, updated_at = now() where id = r.id;
  update private.invites set used = true where code = r.code;
  update public.pair_requests set status = 'expired', updated_at = now()
    where status = 'pending' and (to_uid in (a.id, b.id) or from_uid in (a.id, b.id));

  perform private.enqueue_push(b.id, 'pairing', 'pairing', 'Artık burası ikinize ait 💞',
    private.first_name(a.name) || ' eşleşme isteğinizi kabul etti.', '/home', null, true);
  return jsonb_build_object('coupleId', cid);
end;
$$;

create or replace function public.cancel_pairing(p_request_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.pair_requests set status = 'cancelled', updated_at = now()
  where id = p_request_id and from_uid = auth.uid() and status = 'pending';
$$;

create or replace function public.unpair()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  cid uuid;
  partner uuid;
  me_name text;
begin
  select couple_id, name into cid, me_name from public.profiles where id = uid;
  if cid is null then raise exception 'Eşleşme bulunamadı.' using errcode = 'P0001'; end if;
  partner := private.partner_of(cid, uid);
  update public.couples set status = 'archived', archived_at = now(), archived_by = uid,
    purge_at = now() + interval '30 days' where id = cid;
  update public.profiles set couple_id = null where couple_id = cid;
  if partner is not null then
    perform private.enqueue_push(partner, 'pairing', 'pairing', 'Eşleşme sona erdi',
      private.first_name(me_name) || ' ortak alanınızı kapattı.', '/pairing', null, true);
  end if;
end;
$$;

-- -----------------------------------------------------------------------------
-- Sohbet (RPC) — güncellemeler yalnızca bu fonksiyonlarla
-- -----------------------------------------------------------------------------

create or replace function public.edit_message(p_id uuid, p_text text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if char_length(trim(coalesce(p_text, ''))) = 0 then raise exception 'Mesaj boş olamaz.'; end if;
  update public.messages set text = trim(p_text), edited_at = now()
  where id = p_id and sender_id = auth.uid() and type = 'text' and not deleted_for_all
    and public.is_member(couple_id);
  if not found then raise exception 'Bu mesaj düzenlenemez.' using errcode = '42501'; end if;
end;
$$;

create or replace function public.delete_message_for_all(p_id uuid)
returns text
language plpgsql
security definer
set search_path = ''
as $$
declare
  path text;
begin
  update public.messages m set deleted_for_all = true, text = null, media_url = null, reply_to = null,
    pinned = false, pinned_at = null, media = null
  from (select id, media ->> 'path' as p from public.messages where id = p_id) old
  where m.id = old.id and m.sender_id = auth.uid() and public.is_member(m.couple_id)
  returning old.p into path;
  if not found then raise exception 'Bu mesaj silinemez.' using errcode = '42501'; end if;
  return path; -- istemci Storage dosyasını da siler
end;
$$;

create or replace function public.delete_message_for_me(p_id uuid)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.messages set deleted_for = array_append(deleted_for, auth.uid())
  where id = p_id and public.is_member(couple_id) and not (auth.uid() = any (deleted_for));
$$;

create or replace function public.react_message(p_id uuid, p_emoji text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if p_emoji is not null and char_length(p_emoji) > 16 then raise exception 'Geçersiz tepki.'; end if;
  update public.messages set reactions = case
      when p_emoji is null then reactions - auth.uid()::text
      else reactions || jsonb_build_object(auth.uid()::text, p_emoji) end
  where id = p_id and public.is_member(couple_id) and not deleted_for_all;
end;
$$;

create or replace function public.set_message_pinned(p_id uuid, p_pinned boolean)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.messages set pinned = p_pinned, pinned_at = case when p_pinned then now() end
  where id = p_id and public.is_member(couple_id) and not deleted_for_all;
$$;

create or replace function public.mark_messages_seen(p_ids uuid[])
returns void
language sql
security definer
set search_path = ''
as $$
  update public.messages set seen_by = array_append(seen_by, auth.uid())
  where id = any (p_ids) and public.is_member(couple_id) and not (auth.uid() = any (seen_by));
$$;

-- Cihaz jetonu: aynı cihazda hesap değişirse jeton yeni kullanıcıya geçer.
create or replace function public.claim_device_token(p_token text, p_platform text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
begin
  if auth.uid() is null then raise exception 'Giriş yapmalısınız.' using errcode = '28000'; end if;
  if p_token is null or char_length(p_token) not between 20 and 4096 then
    raise exception 'Geçersiz jeton.' using errcode = 'P0001';
  end if;
  insert into public.device_tokens (token, user_id, platform, updated_at)
  values (p_token, auth.uid(), left(coalesce(p_platform, ''), 16), now())
  on conflict (token) do update set user_id = excluded.user_id, platform = excluded.platform, updated_at = now();
end;
$$;

create or replace function public.increment_goal(p_id uuid, p_delta numeric)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.goals set current = greatest(0, current + p_delta)
  where id = p_id and public.is_member(couple_id);
$$;

-- Cevap yazılınca soruya "cevapladı" işareti.
create or replace function private.on_answer_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.questions set answered_by = array_append(answered_by, new.user_id)
  where couple_id = new.couple_id and id = new.question_id and not (new.user_id = any (answered_by));
  return new;
end;
$$;
create trigger answers_mark_question after insert on public.answers
  for each row execute function private.on_answer_insert();

-- -----------------------------------------------------------------------------
-- Hesap (RPC)
-- -----------------------------------------------------------------------------

create or replace function public.export_user_data()
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  cid uuid;
  result jsonb;
begin
  select couple_id into cid from public.profiles where id = uid;
  result := jsonb_build_object(
    'exportedAt', now(),
    'app', 'VISAL',
    'user', (select to_jsonb(p) from public.profiles p where p.id = uid)
  );
  if cid is not null then
    result := result || jsonb_build_object(
      'couple', (select to_jsonb(c) from public.couples c where c.id = cid),
      'messages', coalesce((select jsonb_agg(to_jsonb(m) order by m.created_at) from public.messages m
                            where m.couple_id = cid and not (uid = any (m.deleted_for))), '[]'),
      'memories', coalesce((select jsonb_agg(to_jsonb(x)) from public.memories x where x.couple_id = cid), '[]'),
      'timeline', coalesce((select jsonb_agg(to_jsonb(x)) from public.timeline x where x.couple_id = cid), '[]'),
      'events', coalesce((select jsonb_agg(to_jsonb(x)) from public.events x where x.couple_id = cid), '[]'),
      'tasks', coalesce((select jsonb_agg(to_jsonb(x)) from public.tasks x where x.couple_id = cid), '[]'),
      'goals', coalesce((select jsonb_agg(to_jsonb(x)) from public.goals x where x.couple_id = cid), '[]'),
      'questions', coalesce((select jsonb_agg(to_jsonb(x)) from public.questions x where x.couple_id = cid), '[]'),
      'answers', coalesce((select jsonb_agg(to_jsonb(x)) from public.answers x where x.couple_id = cid and x.user_id = uid), '[]'),
      'moods', coalesce((select jsonb_agg(to_jsonb(x)) from public.moods x where x.couple_id = cid and x.user_id = uid), '[]'),
      'capsules', coalesce((
        select jsonb_agg(to_jsonb(c) || jsonb_build_object('content', to_jsonb(cc)))
        from public.capsules c left join public.capsule_contents cc on cc.capsule_id = c.id
        where c.couple_id = cid and (c.created_by = uid or now() >= c.open_at)), '[]')
    );
  end if;
  return result;
end;
$$;

-- Hesabı ve varsa çift alanını kalıcı olarak siler (Storage dosyalarını istemci önce siler).
create or replace function public.delete_account()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  uid uuid := auth.uid();
  cid uuid;
  partner uuid;
begin
  if uid is null then raise exception 'Giriş yapmalısınız.' using errcode = '28000'; end if;
  select couple_id into cid from public.profiles where id = uid;
  if cid is not null then
    partner := private.partner_of(cid, uid);
    update public.profiles set couple_id = null where couple_id = cid;
    delete from public.couples where id = cid;
    if partner is not null then
      perform private.enqueue_push(partner, 'pairing', 'pairing', 'Eşleşme sona erdi',
        'Partnerin VISAL hesabını sildi. Ortak alanınız kapatıldı.', '/pairing', null, true);
    end if;
  end if;
  delete from auth.users where id = uid;
end;
$$;

-- -----------------------------------------------------------------------------
-- Bildirim tetikleyicileri
-- -----------------------------------------------------------------------------

create or replace function private.on_message_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  partner uuid := private.partner_of(new.couple_id, new.sender_id);
  sender text := private.first_name((select name from public.profiles where id = new.sender_id));
  body text;
begin
  if partner is null then return new; end if;
  if new.type = 'love' then
    perform private.enqueue_push(partner, 'love', 'love', 'VISAL',
      split_part(coalesce(new.text, '❤️'), ' ', 1) || ' ' || sender || ' ' || case new.love_kind
        when 'miss' then 'seni özledi.'
        when 'kiss' then 'sana bir öpücük gönderdi.'
        when 'home' then 'eve geliyor.'
        when 'coffee' then 'kahve içmek istiyor.'
        when 'call' then 'müsait misin diye soruyor.'
        else 'seni düşünüyor.' end,
      '/chat', 'Yeni mesaj', false, 'chat');
    return new;
  end if;
  body := case new.type
    when 'text' then left(new.text, 180)
    when 'image' then '📷 Fotoğraf'
    when 'video' then '🎬 Video'
    when 'voice' then '🎤 Sesli mesaj'
    when 'file' then '📎 ' || coalesce(new.media ->> 'name', 'Dosya')
    when 'gif' then 'GIF'
    else 'Yeni mesaj' end;
  perform private.enqueue_push(partner, 'messages', 'message', sender, body, '/chat', 'Yeni mesaj', false, 'chat');
  return new;
end;
$$;
create trigger messages_notify after insert on public.messages
  for each row execute function private.on_message_insert();

create or replace function private.on_memory_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  partner uuid := private.partner_of(new.couple_id, new.created_by);
begin
  if partner is not null then
    perform private.enqueue_push(partner, 'memories', 'memory', 'Yeni anı ✨',
      private.first_name((select name from public.profiles where id = new.created_by))
        || ' bir anı ekledi: ' || left(new.title, 80),
      '/memory/' || new.id, 'Yeni bir anı eklendi', true);
  end if;
  return new;
end;
$$;
create trigger memories_notify after insert on public.memories
  for each row execute function private.on_memory_insert();

create or replace function private.on_capsule_insert()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  perform private.enqueue_push(new.recipient_id, 'capsules', 'capsule', 'Sana bir kapsül bırakıldı ⏳',
    private.first_name((select name from public.profiles where id = new.created_by))
      || ' sana bir anı kapsülü bıraktı. ' || to_char(new.open_at at time zone 'Europe/Istanbul', 'DD.MM.YYYY')
      || ' tarihinde açılacak.',
    '/capsule/' || new.id, 'Yeni bir kapsül', true);
  return new;
end;
$$;
create trigger capsules_notify after insert on public.capsules
  for each row execute function private.on_capsule_insert();

-- Etkinlik hatırlatma zamanı (tekrarlar dahil).
create or replace function private.next_reminder(
  p_starts timestamptz, p_time text, p_repeat text, p_reminder int, p_after timestamptz
) returns timestamptz
language plpgsql
immutable
as $$
declare
  base timestamptz := case when p_time is null then p_starts + interval '9 hours' else p_starts end;
  occ timestamptz := base;
  step interval;
  i int := 0;
begin
  if p_reminder is null then return null; end if;
  step := case p_repeat
    when 'daily' then interval '1 day'
    when 'weekly' then interval '7 days'
    when 'monthly' then interval '1 month'
    when 'yearly' then interval '1 year'
    else null end;
  while occ - make_interval(mins => p_reminder) <= p_after loop
    if step is null then return null; end if;
    i := i + 1;
    occ := base + step * i;
    if i > 5000 then return null; end if;
  end loop;
  return occ - make_interval(mins => p_reminder);
end;
$$;

create or replace function private.events_set_reminder()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  new.next_reminder_at := private.next_reminder(new.starts_at, new.time, new.repeat, new.reminder, now());
  return new;
end;
$$;
create trigger events_reminder before insert or update of starts_at, time, repeat, reminder on public.events
  for each row execute function private.events_set_reminder();

-- -----------------------------------------------------------------------------
-- Zamanlanmış işler (pg_cron tarafından çağrılır)
-- -----------------------------------------------------------------------------

create or replace function private.tick_five_minutes()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  c record;
  e record;
  m uuid;
begin
  for c in
    update public.capsules cap set notified = true
    from public.couples cp
    where cap.couple_id = cp.id and cp.status = 'active' and not cap.notified and cap.open_at <= now()
    returning cap.id, cap.recipient_id
  loop
    perform private.enqueue_push(c.recipient_id, 'capsules', 'capsule', 'Kapsül açıldı 🔓',
      'Partnerinin sana bıraktığı bir kapsül açıldı.', '/capsule/' || c.id, 'Bir kapsül açıldı', true);
  end loop;

  for e in
    select ev.*, cp.members from public.events ev join public.couples cp on cp.id = ev.couple_id
    where ev.next_reminder_at <= now() and cp.status = 'active'
    limit 300
  loop
    update public.events set next_reminder_at =
      private.next_reminder(e.starts_at, e.time, e.repeat, e.reminder, now() + interval '1 minute')
      where id = e.id;
    foreach m in array e.members loop
      perform private.enqueue_push(m, 'events', 'event', '⏰ ' || e.title,
        coalesce(e.time, 'Bugün') || coalesce(' · ' || e.location, ''),
        '/event/' || e.id, 'Yaklaşan bir planınız var', true);
    end loop;
  end loop;
end;
$$;

create or replace function private.daily_morning()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  today date := (now() at time zone 'Europe/Istanbul')::date;
  cp record;
  mem record;
  ann date;
  d int;
  m uuid;
begin
  for cp in select * from public.couples where status = 'active' loop
    ann := coalesce(cp.anniversary_date, cp.relationship_start_date);
    if ann is not null then
      d := private.days_until_yearly(ann, today);
      if d in (0, 1, 7) then
        foreach m in array cp.members loop
          perform private.enqueue_push(m, 'events', 'event', 'Yıldönümü 💍',
            case when d = 0 then 'Bugün sizin gününüz. Mutlu yıldönümü! ❤️'
                 else 'Yıldönümünüze ' || d || ' gün kaldı.' end, '/plans', null, true);
        end loop;
      end if;
    end if;
    for mem in select * from public.couple_members where couple_id = cp.id and birthday is not null loop
      d := private.days_until_yearly(mem.birthday, today);
      if d in (0, 1, 7) then
        perform private.enqueue_push(private.partner_of(cp.id, mem.user_id), 'events', 'event', 'Doğum günü 🎂',
          case when d = 0 then 'Bugün ' || private.first_name(mem.name) || '''in doğum günü! 🎉'
               else private.first_name(mem.name) || '''in doğum gününe ' || d || ' gün kaldı.' end,
          '/plans', null, true);
      end if;
    end loop;
    foreach m in array cp.members loop
      perform private.enqueue_push(m, 'dailyQuestion', 'question', 'Bugünün sorusu hazır ✨',
        'Cevabını paylaş; ikiniz de cevaplayınca cevaplar açılsın.', '/questions');
    end loop;
  end loop;
end;
$$;

create or replace function private.days_until_yearly(d date, today date)
returns int
language plpgsql
immutable
as $$
declare
  target date;
begin
  target := make_date(extract(year from today)::int, extract(month from d)::int,
    least(extract(day from d)::int,
          extract(day from (date_trunc('month', make_date(extract(year from today)::int, extract(month from d)::int, 1))
                             + interval '1 month - 1 day'))::int));
  if target < today then target := (target + interval '1 year')::date; end if;
  return target - today;
end;
$$;

create or replace function private.purge_archived()
returns void
language sql
security definer
set search_path = ''
as $$
  delete from public.couples where status = 'archived' and purge_at <= now();
  delete from private.invites where expires_at <= now();
$$;

-- -----------------------------------------------------------------------------
-- Fonksiyon yetkileri
-- -----------------------------------------------------------------------------

revoke execute on all functions in schema public from public, anon;
grant execute on function
  public.is_member(uuid), public.my_couple_id(), public.has_answered(uuid, text),
  public.create_invite(), public.request_pairing(text), public.respond_pairing(uuid, boolean),
  public.cancel_pairing(uuid), public.unpair(),
  public.edit_message(uuid, text), public.delete_message_for_all(uuid), public.delete_message_for_me(uuid),
  public.react_message(uuid, text), public.set_message_pinned(uuid, boolean), public.mark_messages_seen(uuid[]),
  public.increment_goal(uuid, numeric), public.export_user_data(), public.delete_account(),
  public.claim_device_token(text, text)
to authenticated;
