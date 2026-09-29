-- VISAL veritabanı güvenlik testleri (yerel PostgreSQL; bkz. run.sh)
\set QUIET on

-- --- yardımcılar ------------------------------------------------------------
create function public.t_expect_fail(q text) returns void language plpgsql as $$
begin
  begin
    execute q;
  exception when others then
    return;
  end;
  raise exception 'BEKLENMEYEN BAŞARI: %', q;
end $$;

create function public.t_expect_rows(q text, n int) returns void language plpgsql as $$
declare c int;
begin
  execute q;
  get diagnostics c = row_count;
  if c <> n then raise exception 'Beklenen % satır, gelen %: %', n, c, q; end if;
end $$;

create function public.t_expect_count(q text, n int) returns void language plpgsql as $$
declare c int;
begin
  execute 'select count(*) from (' || q || ') t' into c;
  if c <> n then raise exception 'Beklenen % satır, görünen %: %', n, c, q; end if;
end $$;
grant execute on function public.t_expect_fail(text), public.t_expect_rows(text, int), public.t_expect_count(text, int)
  to authenticated;

create table public.t_vars (k text primary key, v text);
grant select, insert, update on public.t_vars to authenticated;

-- --- kullanıcılar -------------------------------------------------------------
insert into auth.users (id, email, raw_user_meta_data) values
  ('00000000-0000-0000-0000-00000000000a', 'ayse@test', '{"name":"Ayşe Yılmaz"}'),
  ('00000000-0000-0000-0000-00000000000b', 'resul@test', '{"name":"Resul"}'),
  ('00000000-0000-0000-0000-00000000000c', 'mallory@test', '{"name":"Mallory"}');

do $$ begin
  if (select count(*) from public.profiles) <> 3 then raise exception 'profiles tetikleyicisi çalışmadı'; end if;
  if (select name from public.profiles where email = 'ayse@test') <> 'Ayşe Yılmaz' then raise exception 'ad aktarılmadı'; end if;
end $$;

-- --- eşleşme -----------------------------------------------------------------
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into public.t_vars values ('code', (select public.create_invite() ->> 'code'));
select public.t_expect_count($$select * from public.profiles$$, 1);  -- yalnızca kendi profili
select public.t_expect_fail($$update public.profiles set couple_id = gen_random_uuid()$$);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select public.t_expect_fail($$select public.request_pairing('VISAL-XXXXX')$$);
insert into public.t_vars values ('req', (select public.request_pairing((select v from public.t_vars where k = 'code')) ->> 'requestId'));
select public.t_expect_count($$select * from public.pair_requests$$, 1);

-- Mallory isteği kabul edemez
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
select public.t_expect_fail($$select public.respond_pairing((select v::uuid from public.t_vars where k = 'req'), true)$$);
select public.t_expect_count($$select * from public.pair_requests$$, 0);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into public.t_vars values ('cid', (select public.respond_pairing((select v::uuid from public.t_vars where k = 'req'), true) ->> 'coupleId'));
reset role;

do $$ begin
  if (select count(*) from public.profiles where couple_id is not null) <> 2 then raise exception 'couple_id atanmadı'; end if;
  if (select count(*) from public.couple_members) <> 2 then raise exception 'couple_members oluşmadı'; end if;
  if (select count(*) from public.inbox where user_id = '00000000-0000-0000-0000-00000000000b') <> 1 then
    raise exception 'kabul bildirimi kutuya düşmedi'; end if;
end $$;

-- Aynı kod ikinci kez kullanılamaz; eşleşmiş kullanıcı yeni kod alamaz.
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
select public.t_expect_fail($$select public.request_pairing((select v from public.t_vars where k = 'code'))$$);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
select public.t_expect_fail($$select public.create_invite()$$);

-- --- üçüncü kişi izolasyonu -------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
select public.t_expect_count($$select * from public.couples$$, 0);
select public.t_expect_count($$select * from public.couple_members$$, 0);
select public.t_expect_fail($$insert into public.messages (couple_id, type, text, seen_by)
  values ((select v::uuid from public.t_vars where k = 'cid'), 'text', 'hack', array[auth.uid()])$$);
select public.t_expect_fail($$insert into public.memories (couple_id, title, date)
  values ((select v::uuid from public.t_vars where k = 'cid'), 'x', current_date)$$);

-- --- mesajlar ----------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into public.messages (couple_id, type, text, seen_by)
  values ((select v::uuid from public.t_vars where k = 'cid'), 'text', 'Merhaba', array[auth.uid()]);
insert into public.t_vars values ('msg', (select id::text from public.messages limit 1));
-- gönderen taklidi
select public.t_expect_fail($$insert into public.messages (couple_id, sender_id, type, text, seen_by)
  values ((select v::uuid from public.t_vars where k = 'cid'), '00000000-0000-0000-0000-00000000000b', 'text', 'x',
          array['00000000-0000-0000-0000-00000000000b'::uuid])$$);
-- doğrudan update yetkisi yok
select public.t_expect_fail($$update public.messages set text = 'x'$$);

select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select public.t_expect_count($$select * from public.messages$$, 1);
select public.t_expect_fail($$select public.edit_message((select v::uuid from public.t_vars where k = 'msg'), 'hack')$$);
select public.react_message((select v::uuid from public.t_vars where k = 'msg'), '❤️');
select public.mark_messages_seen(array[(select v::uuid from public.t_vars where k = 'msg')]);
reset role;
do $$ begin
  if (select reactions ->> '00000000-0000-0000-0000-00000000000b' from public.messages) <> '❤️' then raise exception 'tepki yok'; end if;
  if cardinality((select seen_by from public.messages)) <> 2 then raise exception 'okundu yok'; end if;
  if (select count(*) from private.push_queue) <> 0 then raise exception 'kuyruk temizlenmedi'; end if;
end $$;

-- --- sorular: karşılıklı açılan cevaplar ------------------------------------------
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into public.questions (couple_id, id, text, category)
  values ((select v::uuid from public.t_vars where k = 'cid'), 'b_1', 'Soru?', 'fun');
insert into public.answers (couple_id, question_id, text)
  values ((select v::uuid from public.t_vars where k = 'cid'), 'b_1', 'Ayşe cevabı');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select public.t_expect_count($$select * from public.answers$$, 0);
select public.t_expect_fail($$insert into public.answers (couple_id, question_id, user_id, text)
  values ((select v::uuid from public.t_vars where k = 'cid'), 'b_1', '00000000-0000-0000-0000-00000000000a', 'taklit')$$);
insert into public.answers (couple_id, question_id, text)
  values ((select v::uuid from public.t_vars where k = 'cid'), 'b_1', 'Resul cevabı');
select public.t_expect_count($$select * from public.answers$$, 2);
select public.t_expect_count($$select * from public.questions where cardinality(answered_by) = 2$$, 1);

-- --- ruh hali görünürlüğü ------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into public.moods (couple_id, day, emoji) values ((select v::uuid from public.t_vars where k = 'cid'), current_date, '😊');
update public.profiles set settings = jsonb_set(settings, '{privacy,moodVisible}', 'false');
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select public.t_expect_count($$select * from public.moods$$, 0);

-- --- kapsüller -------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
insert into public.capsules (couple_id, recipient_id, open_at, title)
  values ((select v::uuid from public.t_vars where k = 'cid'), '00000000-0000-0000-0000-00000000000b', now() + interval '1 day', 'Sürpriz');
insert into public.t_vars values ('cap', (select id::text from public.capsules limit 1));
insert into public.capsule_contents (capsule_id, message) values ((select v::uuid from public.t_vars where k = 'cap'), 'Gizli mesaj');
select public.t_expect_count($$select * from public.capsule_contents$$, 1);
-- geçmiş tarihli kapsül kilitlenemez
select public.t_expect_fail($$insert into public.capsules (couple_id, recipient_id, open_at)
  values ((select v::uuid from public.t_vars where k = 'cid'), '00000000-0000-0000-0000-00000000000b', now() - interval '1 day')$$);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select public.t_expect_count($$select * from public.capsules$$, 1);
select public.t_expect_count($$select * from public.capsule_contents$$, 0);
select public.t_expect_fail($$insert into public.capsule_contents (capsule_id, message)
  values ((select v::uuid from public.t_vars where k = 'cap'), 'üzerine yaz')$$);
reset role;
update public.capsules set open_at = now() - interval '1 minute';
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select public.t_expect_count($$select * from public.capsule_contents$$, 1);

-- --- storage -------------------------------------------------------------------------
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
insert into storage.objects (bucket_id, name)
  values ('media', (select v from public.t_vars where k = 'cid') || '/chat/m1/a.jpg');
select public.t_expect_count($$select * from storage.objects$$, 1);
select public.t_expect_fail($$insert into storage.objects (bucket_id, name)
  values ('media', (select v from public.t_vars where k = 'cid') || '/capsules/' || (select v from public.t_vars where k = 'cap') || '/x.jpg')$$);
select public.t_expect_fail($$insert into storage.objects (bucket_id, name) values ('media', 'not-a-uuid/chat/x/a.jpg')$$);
-- yarım kalmış kilitlemenin (satırı olmayan) kapsül dosyası temizlenebilir
insert into storage.objects (bucket_id, name)
  values ('media', (select v from public.t_vars where k = 'cid') || '/capsules/11111111-1111-1111-1111-111111111111/o.jpg');
select public.t_expect_count($$select * from storage.objects where name like '%/capsules/%'$$, 1);
delete from storage.objects where name like '%/capsules/%';
select public.t_expect_count($$select * from storage.objects where name like '%/capsules/%'$$, 0);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
select public.t_expect_count($$select * from storage.objects$$, 0);
select public.t_expect_fail($$insert into storage.objects (bucket_id, name)
  values ('media', (select v from public.t_vars where k = 'cid') || '/chat/x/b.jpg')$$);
select public.t_expect_fail($$insert into storage.objects (bucket_id, name)
  values ('avatars', '00000000-0000-0000-0000-00000000000a/a.jpg')$$);

-- --- realtime özel kanal -----------------------------------------------------------
reset role;
insert into realtime.messages (topic, payload) values ('couple:' || (select v from public.t_vars where k = 'cid'), '{}');
set role authenticated;
select set_config('realtime.topic', 'couple:' || (select v from public.t_vars where k = 'cid'), false);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select public.t_expect_count($$select * from realtime.messages$$, 1);
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000c', false);
select public.t_expect_count($$select * from realtime.messages$$, 0);

-- --- hatırlatma hesabı -----------------------------------------------------------------
reset role;
do $$ begin
  if private.next_reminder('2020-01-01 10:00+00', '10:00', 'yearly', 60, '2020-06-01 00:00+00')
     <> '2021-01-01 09:00+00'::timestamptz then raise exception 'yıllık hatırlatma hatalı'; end if;
  if private.next_reminder('2020-01-01 10:00+00', '10:00', 'none', 60, '2020-06-01 00:00+00') is not null then
    raise exception 'geçmiş tek seferlik hatırlatma null olmalı'; end if;
  if private.days_until_yearly('1990-03-12', '2026-03-10') <> 2 then raise exception 'doğum günü sayacı hatalı'; end if;
end $$;
select private.tick_five_minutes();
select private.daily_morning();

-- --- eşleşmeyi bitirme --------------------------------------------------------------------
set role authenticated;
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000a', false);
select public.unpair();
select set_config('request.jwt.claim.sub', '00000000-0000-0000-0000-00000000000b', false);
select public.t_expect_count($$select * from public.messages$$, 0);
select public.t_expect_count($$select * from public.couples$$, 0);
select public.t_expect_count($$select * from storage.objects$$, 0);

-- --- hesap silme ---------------------------------------------------------------------------
select public.delete_account();
reset role;
do $$ begin
  if exists (select 1 from auth.users where email = 'resul@test') then raise exception 'hesap silinmedi'; end if;
  if exists (select 1 from public.profiles where email = 'resul@test') then raise exception 'profil silinmedi'; end if;
end $$;

\echo 'RLS testleri: OK'
