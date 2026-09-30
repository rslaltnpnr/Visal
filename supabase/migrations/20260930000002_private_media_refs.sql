-- =============================================================================
-- Mevcut uzun ömürlü signed URL kayıtlarını private Storage referansına çevir.
-- Yeni istemci `visal-storage://<bucket>/<path>` değerini görüntüleme anında
-- kısa ömürlü signed URL'ye dönüştürür.
-- =============================================================================

-- Mesaj medyası: path zaten güvenilir biçimde JSON içinde tutuluyor.
update public.messages
set media_url = 'visal-storage://media/' || (media ->> 'path'),
    media = jsonb_set(
      jsonb_set(
        media,
        '{url}',
        to_jsonb('visal-storage://media/' || (media ->> 'path')),
        true
      ),
      '{thumbUrl}',
      case
        when media ? 'thumbUrl' and coalesce(media ->> 'thumbUrl', '') <> '' then
          to_jsonb(
            'visal-storage://media/' ||
            regexp_replace(media ->> 'path', '\.[^./]+$', '_thumb.jpg')
          )
        else 'null'::jsonb
      end,
      true
    )
where media is not null
  and coalesce(media ->> 'path', '') <> ''
  and coalesce(media_url, '') not like 'visal-storage://%';

-- Anıların media JSON dizisini eleman eleman dönüştür. Correlated scalar
-- subquery kullanılır; UPDATE ... FROM LATERAL hedef alias'ını doğrudan
-- referanslayamadığı için burada bu form daha güvenlidir.
update public.memories m
set media = (
  select coalesce(jsonb_agg(
    case
      when coalesce(item ->> 'path', '') = '' then item
      else jsonb_set(
        jsonb_set(
          item,
          '{url}',
          to_jsonb('visal-storage://media/' || (item ->> 'path')),
          true
        ),
        '{thumbUrl}',
        case
          when item ? 'thumbUrl' and coalesce(item ->> 'thumbUrl', '') <> '' then
            to_jsonb(
              'visal-storage://media/' ||
              regexp_replace(item ->> 'path', '\.[^./]+$', '_thumb.jpg')
            )
          else 'null'::jsonb
        end,
        true
      )
    end
    order by ord
  ), '[]'::jsonb)
  from jsonb_array_elements(coalesce(m.media, '[]'::jsonb)) with ordinality as x(item, ord)
)
where m.media is not null
  and jsonb_typeof(m.media) = 'array';

-- Hikâye ve çift kapaklarında path ayrı kolonda bulunuyor.
update public.timeline
set photo_url = 'visal-storage://media/' || photo_path
where coalesce(photo_path, '') <> ''
  and coalesce(photo_url, '') not like 'visal-storage://%';

update public.couples
set cover_photo = 'visal-storage://media/' || cover_path
where coalesce(cover_path, '') <> ''
  and coalesce(cover_photo, '') not like 'visal-storage://%';

-- Eski avatar kayıtlarında path kolonu yok. Supabase signed URL yapısından path
-- güvenli biçimde çıkarılabiliyorsa referansa dönüştür; diğer harici URL'lere dokunma.
update public.profiles
set photo_url = 'visal-storage://avatars/' ||
  split_part(split_part(photo_url, '/object/sign/avatars/', 2), '?', 1)
where photo_url like '%/object/sign/avatars/%'
  and photo_url not like 'visal-storage://%';

-- Partner profil kopyası profiles trigger'ı ile güncellense de geçmiş satırlar için
-- migration sonunda açıkça eşitle.
update public.couple_members cm
set photo_url = p.photo_url
from public.profiles p
where p.id = cm.user_id
  and cm.photo_url is distinct from p.photo_url;
