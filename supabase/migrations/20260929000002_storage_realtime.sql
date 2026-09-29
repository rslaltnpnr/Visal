-- =============================================================================
-- Storage (dosyalar) ve Realtime (canlı güncellemeler, presence) yetkileri
-- =============================================================================

-- -----------------------------------------------------------------------------
-- Storage
--   media:   {couple_id}/{chat|memories|timeline|cover|capsules}/{id}/{dosya}
--   avatars: {user_id}/{dosya}
-- -----------------------------------------------------------------------------

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('media', 'media', false, 104857600, array[
    'image/jpeg', 'image/png', 'image/heic', 'image/heif', 'image/webp', 'image/gif',
    'video/mp4', 'video/quicktime', 'video/3gpp', 'video/webm',
    'audio/mp4', 'audio/mpeg', 'audio/aac', 'audio/m4a', 'audio/x-m4a',
    'application/pdf', 'application/zip', 'application/msword', 'text/plain',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/octet-stream'
  ]),
  ('avatars', 'avatars', false, 10485760, array['image/jpeg', 'image/png', 'image/webp', 'image/heic'])
on conflict (id) do nothing;

-- Yol ayrıştırma + yetki kontrolü (geçersiz uuid'de hata yerine false).
create or replace function public.media_access(object_name text, for_write boolean)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  parts text[] := string_to_array(object_name, '/');
  cid uuid;
  section text := parts[2];
  cap public.capsules;
begin
  if array_length(parts, 1) < 3 then return false; end if;
  begin
    cid := parts[1]::uuid;
  exception when others then
    return false;
  end;
  if not public.is_member(cid) then return false; end if;
  if section not in ('chat', 'memories', 'timeline', 'cover', 'capsules') then return false; end if;
  if section <> 'capsules' then return true; end if;
  -- Kapsül: yükleme yalnızca kilitlemeden önce; okuma oluşturana veya açılınca.
  begin
    select * into cap from public.capsules where id = parts[3]::uuid;
  exception when others then
    return false;
  end;
  if for_write then return cap is null; end if;
  return cap is not null and (cap.created_by = auth.uid() or now() >= cap.open_at);
end;
$$;

create or replace function public.avatar_access(object_name text)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select split_part(object_name, '/', 1) = auth.uid()::text
    or exists (
      select 1 from public.profiles me, public.profiles other
      where me.id = auth.uid()
        and other.id::text = split_part(object_name, '/', 1)
        and me.couple_id is not null and me.couple_id = other.couple_id
    );
$$;

-- Kapsül dosyaları: oluşturan, kapsül açılmadan önce silebilir; satırı hiç
-- oluşmamış (yarım kalmış kilitleme) dosyalar da üyelerce temizlenebilir.
create or replace function public.capsule_media_removable(object_name text)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  parts text[] := string_to_array(object_name, '/');
  cap public.capsules;
begin
  if array_length(parts, 1) < 4 or parts[2] <> 'capsules' then return false; end if;
  begin
    if not public.is_member(parts[1]::uuid) then return false; end if;
    select * into cap from public.capsules where id = parts[3]::uuid;
  exception when others then
    return false;
  end;
  return cap is null or (cap.created_by = auth.uid() and now() < cap.open_at);
end;
$$;

grant execute on function public.media_access(text, boolean), public.avatar_access(text),
  public.capsule_media_removable(text) to authenticated;

create policy media_select on storage.objects for select to authenticated
  using (bucket_id = 'media' and (public.media_access(name, false) or public.capsule_media_removable(name)));
create policy media_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'media' and public.media_access(name, true));
create policy media_delete on storage.objects for delete to authenticated
  using (bucket_id = 'media' and (
    (split_part(name, '/', 2) <> 'capsules' and public.media_access(name, true))
    or public.capsule_media_removable(name)
  ));

create policy avatars_select on storage.objects for select to authenticated
  using (bucket_id = 'avatars' and public.avatar_access(name));
create policy avatars_insert on storage.objects for insert to authenticated
  with check (bucket_id = 'avatars' and split_part(name, '/', 1) = auth.uid()::text);
create policy avatars_delete on storage.objects for delete to authenticated
  using (bucket_id = 'avatars' and split_part(name, '/', 1) = auth.uid()::text);

-- -----------------------------------------------------------------------------
-- Realtime: tablo değişiklikleri (RLS'e tabi) ve özel çift kanalı (presence)
-- -----------------------------------------------------------------------------

alter publication supabase_realtime add table
  public.profiles, public.couples, public.couple_members, public.pair_requests, public.inbox,
  public.messages, public.memories, public.timeline, public.events, public.tasks, public.goals,
  public.moods, public.questions, public.answers, public.capsules;

-- Eski satırın tamamı güncelleme olaylarında gelsin (stream filtreleri için).
alter table public.messages replica identity full;

-- "couple:{couple_id}" özel kanalı: yalnızca o çiftin üyeleri katılabilir.
create policy couple_channel_read on realtime.messages for select to authenticated
  using (realtime.topic() = 'couple:' || public.my_couple_id()::text);
create policy couple_channel_write on realtime.messages for insert to authenticated
  with check (realtime.topic() = 'couple:' || public.my_couple_id()::text);
