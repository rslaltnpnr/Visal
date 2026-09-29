# VISAL — İkinize ait bir dünya.

VISAL, yalnızca iki kişinin kullandığı premium, mahremiyet odaklı bir çift uygulamasıdır.
Dating uygulaması, sosyal medya ya da mesajlaşma klonu değildir: iki insanın sohbet ettiği,
anılarını sakladığı, özel günlerini takip ettiği, birbirine sorular sorduğu, gelecek planları
yaptığı ve anı kapsülleri bıraktığı ortak dijital alandır.

Tek kod tabanı (Flutter) ile Android ve iOS; backend **Supabase** (Postgres + RLS, Auth, Storage, Realtime,
Edge Functions). Push bildirimleri için yalnızca Firebase Cloud Messaging kullanılır (ücretsiz, isteğe bağlı).

---

## Özellikler

| Alan | İçerik |
| --- | --- |
| **Açılış / Onboarding** | Sinematik gün batımı splash'ı, "Başlayalım →", 4 ekranlık onboarding |
| **Kimlik** | E-posta/şifre, şifre sıfırlama, Google ile giriş, Apple ile giriş (iOS) |
| **Eşleştirme** | `VISAL-4X72Q` davet kodu + QR, kod girme / QR tarama, "X sizinle VISAL'da eşleşmek istiyor" kabul/ret, eşleşme animasyonu. Her kullanıcı tek partnerle eşleşir; eşleşme yalnızca veritabanı fonksiyonlarıyla (RPC) yapılır |
| **Biz (ana ekran)** | Kapak fotoğraflı hero, otomatik gün sayacı, İlişki Özetimiz (gün/anı/plan), Hızlı Erişim, Bugünün Sorusu, Yaklaşan, ruh hali, "X yıl önce bugün", Anı Kapsülü ve Hikâyemiz kartları |
| **Sohbet** | Metin, fotoğraf, video, sesli mesaj, dosya, emoji, GIF (GIPHY), yanıtla (kaydırarak da), düzenle, benden/herkesten sil, tepki, sabitle, gönderildi/okundu, yazıyor, çevrimiçi/son görülme, hızlı sevgi mesajları + "❤️ Partnerin seni düşünüyor" animasyonu, sayfalı sonsuz kaydırma, yükleme ilerlemesi |
| **Anılar** | Yıl gruplu zaman çizelgesi ↔ ızgara, filtreler (Tümü/Fotoğraflar/Videolar/Özel Günler/Seyahat), çoklu medya, konum, emoji, şarkı bağlantısı, tam ekran görüntüleyici, Bizim Hikâyemiz zaman çizelgesi |
| **Anı Kapsülü** | Mesaj + fotoğraf + video + ses, açılma tarihi, "Kapsülü Kilitle"; içerik tarihten önce **RLS kurallarıyla** kilitli, tarihinde push bildirim |
| **Sorular** | 10 kategori, 120 soru, çifte özel deterministik günün sorusu; cevaplar ikisi de cevaplayınca açılır (kurallarla zorunlu) |
| **Ruh hali** | Günde bir, 8 emoji; partner görebilir (gizlenebilir), analiz yapılmaz |
| **Planlar** | Ortak takvim (kategori, saat, konum, not, hatırlatma, tekrar, renk), görevler (Ben/Partnerim/İkimiz), ortak hedefler (ilerleme çubuğu) |
| **Profil / Ayarlar** | Profil, partner, ilişki başlangıcı, yıldönümü, doğum günü; bildirimler, gizlilik (çevrimiçi, son görülme, okundu, bildirim içeriği gizli modu, ruh hali), tema (Açık / VISAL Dark / Sistem), PIN + parmak izi / Face ID kilidi, partner yönetimi, verileri indir (JSON), hesabı sil |
| **Bildirimler (FCM)** | Yeni mesaj, partner seni düşünüyor, yeni anı, kapsül açıldı, yaklaşan özel gün, günün sorusu; gizli modda "VISAL — Yeni mesaj" |

## Mimari

```
lib/
  app.dart, main.dart
  core/
    config/     Supabase adresi/anahtarı (Env), yapılandırma eksik ekranı
    theme/      renkler, tema (light + VISAL Dark), varlık yolları
    router/     go_router, 5 sekmeli kabuk (Biz · Sohbet · Anılar · Planlar · Profil)
    services/   Supabase sağlayıcıları + canlı sorgu (watchQuery), medya (sıkıştırma/thumbnail/yükleme),
                FCM, presence (Realtime kanalı), uygulama kilidi, tercihler
    session/    oturum/çift/partner sağlayıcıları
    widgets/    logo (vektörel V), butonlar, kartlar, görüntüleyici, seçiciler
    utils/      tarih, doğrulama, hata çevirisi
  features/
    auth | pairing | home | chat | memories | calendar | questions | capsules | profile | settings
      data/  domain/  presentation/
supabase/
  migrations/     şema, RLS, RPC'ler, tetikleyiciler, depolama + realtime kuralları, pg_cron işleri
  functions/      send-push (Deno Edge Function → FCM HTTP v1)
  tests/          RLS/RPC testleri (yerel PostgreSQL üzerinde)
```

- **State:** Riverpod 3 · **Navigasyon:** go_router · **Yerel:** SharedPreferences · **Güvenli yerel:** flutter_secure_storage · **Biyometrik:** local_auth
- **Performans:** Sohbette en yeni 40 mesaj canlı, yukarı kaydırdıkça limit artar; anılarda artan limitli sayfalama; resimlerde 2048px sıkıştırma + 480px thumbnail, videolarda thumbnail, `cached_network_image` disk önbelleği.

## Veri modeli (Postgres)

```
profiles              id, name, email, photo_url, couple_id, birthday, last_seen, settings (jsonb) — yalnızca sahibi
couples               members uuid[2], status, relationship_start_date, anniversary_date, cover_photo, archived_at
couple_members        partnerin görebildiği profil kopyası (tetikleyiciyle eşitlenir)
pair_requests         eşleşme istekleri (yalnızca RPC yazar)
messages              sender_id, type, text, media, reply_to, reactions, seen_by, deleted_for, pinned, love_kind
memories | timeline | events | tasks | goals | moods | questions | answers | capsules + capsule_contents
device_tokens, inbox  FCM jetonları ve bildirim geçmişi
private.*             davet kodları, push kuyruğu, yapılandırma (istemciye kapalı şema)
Storage               media/{couple_id}/{chat|memories|timeline|cover|capsules}/{id}/..., avatars/{uid}/...
```

## Güvenlik

- Her tabloda RLS açık; `anon` rolünün hiçbir tabloya erişimi yok. Kolon düzeyinde yetkiler: örneğin
  `profiles.couple_id`, `couples.members`, mesaj içeriği istemciden doğrudan **değiştirilemez** (RPC'ler kontrol eder).
- Çift verisine yalnızca `members` içindeki iki kişi erişir; couple_id tahmin edilse bile üçüncü kişi erişemez.
  Eşleşmesi biten alan anında kapanır, 30 gün sonra kalıcı silinir.
- Depolama kuralları yolu ayrıştırıp üyeliği veritabanından doğrular. Kapsül içeriği ve dosyaları açılma zamanına
  kadar alıcıya kapalıdır.
- Partnerin soru cevabı, kullanıcı kendi cevabını yazmadan veritabanından hiç dönmez. Gizlenen ruh hali partnere kapalıdır.
- Realtime değişiklikleri ve çiftin özel kanalı (çevrimiçi / yazıyor) aynı RLS kurallarına tabidir.
- Push gizli modu ve kategori tercihleri sunucuda uygulanır. Android'de yedekleme kapalı.

Veritabanı testleri (PostgreSQL 16 gerekir):

```bash
bash supabase/tests/run.sh
```

## Kurulum

1. **Supabase projesi** (ücretsiz plan, kart gerekmez): [supabase.com](https://supabase.com) → New project
   (bölge: Central EU / Frankfurt). Veritabanı şifresini güvenli bir yere kaydedin.
2. **Uygulamaya bağlayın:** Project Settings → API'deki **Project URL** ve **anon / publishable key** değerlerini
   GitHub'da *Settings → Secrets and variables → Actions → Variables* altına `SUPABASE_URL` ve `SUPABASE_ANON_KEY`
   olarak ekleyin (bu iki değer gizli değildir; veriyi RLS korur). Yerelde:
   ```bash
   flutter run --dart-define=SUPABASE_URL=https://<ref>.supabase.co --dart-define=SUPABASE_ANON_KEY=<anahtar>
   ```
3. **Veritabanını kurun:** GitHub *Secrets* altına ekleyin:
   `SUPABASE_ACCESS_TOKEN` (supabase.com/dashboard/account/tokens), `SUPABASE_DB_PASSWORD`, `SUPABASE_PROJECT_REF`.
   Ardından **Actions → Supabase Deploy → Run workflow**.
   *Şifresiz alternatif:* `supabase/setup_all.sql` dosyasının tamamını Supabase → **SQL Editor**'e yapıştırıp
   **Run**'a basın (dosya `bash supabase/build_setup_sql.sh > supabase/setup_all.sql` ile üretilir). Bu durumda
   `SUPABASE_DB_PASSWORD` secret'ı gerekmez; iş akışı yalnızca Edge Function'ı yükler. İş; testleri çalıştırır, göçleri uygular, `send-push`
   fonksiyonunu yükler ve push uç noktasını yapılandırır. Elle kurmak isterseniz:
   ```bash
   supabase link --project-ref <ref>
   supabase db push
   supabase functions deploy send-push --no-verify-jwt
   ```
4. **Auth ayarları:** Authentication → URL Configuration → Redirect URLs'e `visal://auth-callback` ekleyin
   (e-posta doğrulama ve şifre sıfırlama uygulamaya döner). Hızlı test için Authentication → Providers → Email
   altında "Confirm email" kapatılabilir.
5. **Push (isteğe bağlı):** Firebase'de (ücretsiz Spark planı yeterli) paket adı `app.visal.visal` olan bir Android
   uygulaması ekleyin; indirilen `google-services.json` içeriğini `GOOGLE_SERVICES_JSON` secret'ı yapın (APK derlemesi
   gerekli değerleri buradan alır). Proje Ayarları → Hizmet hesapları → **Yeni özel anahtar oluştur** ile inen JSON'u
   `FCM_SERVICE_ACCOUNT` secret'ı yapın ve Supabase Deploy'u yeniden çalıştırın (`SUPABASE_ACCESS_TOKEN` Edge Function
   ve secret yazma yetkisine sahip olmalı). Firebase olmadan bildirimler uygulama içi bildirim kutusunda görünür.
6. **Google ile giriş (isteğe bağlı):** Google Cloud Console → *APIs & Services → Credentials*:
   **Web application** türünde OAuth istemcisi (kimliği + gizli anahtarı Supabase → Authentication → Providers →
   Google'a girilir) ve paket adı `app.visal.visal` ile imza anahtarının SHA-1 parmak izini taşıyan **Android**
   istemcisi oluşturun. Web istemci kimliğini GitHub'da `GOOGLE_SERVER_CLIENT_ID` değişkeni yapın. Değişken yoksa
   Google düğmesi gösterilmez.
7. **Apple ile giriş (iOS):** Apple Developer'da "Sign in with Apple" yeteneğini açın, Supabase'de Apple sağlayıcısını
   yapılandırın (entitlement dosyası hazırdır: `ios/Runner/Runner.entitlements`).
8. **GIF (isteğe bağlı):** [developers.giphy.com](https://developers.giphy.com) → *Create an App* → **API** ile ücretsiz
   anahtar alın ve GitHub'da `GIPHY_API_KEY` secret'ı yapın. Anahtar yoksa GIF seçeneği gizlenir.
9. **Yayın imzası (Android):** Kalıcı yükleme anahtarı GitHub'da `ANDROID_KEYSTORE_BASE64` (keystore'un base64 hâli)
   ve `ANDROID_KEYSTORE_PASSWORD` secret'larıyla verilir (alias: `visal`, değiştirmek için `ANDROID_KEY_ALIAS`
   değişkeni). Yerelde `android/key.properties.example` → `key.properties`. Anahtar yoksa APK geçici anahtarla
   imzalanır ve güncellemeler eski sürümün üzerine kurulamaz.

Her `main` / `ccr-*` push'unda **Android APK Release** iş akışı APK'yı derleyip GitHub Releases'a ekler.

## Marka varlıkları

Tüm yollar `lib/core/theme/app_assets.dart` içindedir.

| Dosya | Kullanım |
| --- | --- |
| `assets/brand/logo_mark.png` | V sembolü (şeffaf PNG, koyu zemin). Yoksa vektörel sembol çizilir |
| `assets/brand/logo_mark_light.png` | V sembolü, açık zemin sürümü (isteğe bağlı) |
| `assets/icon/app_icon.png` | Uygulama ikonu kaynağı (1024×1024) → `dart run flutter_launcher_icons` |
| `assets/icon/splash_mark.png` | Native splash sembolü → `dart run flutter_native_splash:create` |
| `assets/images/splash_bg.jpg` | Açılış ekranı sinematik görseli |
| `assets/images/hero.jpg` | Ana ekran varsayılan kapak (çift kendi kapağını seçebilir) |
| `assets/images/together.jpg`, `fabric.jpg` | Kart görselleri |

Font: Plus Jakarta Sans (OFL, `assets/fonts/`).

Önizleme görüntüleri üretmek için:

```bash
flutter test tool/render_brand_test.dart --update-goldens
flutter test tool/render_screens_test.dart --update-goldens
```

## Testler

```bash
flutter analyze
flutter test                    # domain + satır dönüşümü birim testleri
bash supabase/tests/run.sh      # RLS, RPC, depolama ve realtime kuralları
```
