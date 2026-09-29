# VISAL — İkinize ait bir dünya.

VISAL, yalnızca iki kişinin kullandığı premium, mahremiyet odaklı bir çift uygulamasıdır.
Dating uygulaması, sosyal medya ya da mesajlaşma klonu değildir: iki insanın sohbet ettiği,
anılarını sakladığı, özel günlerini takip ettiği, birbirine sorular sorduğu, gelecek planları
yaptığı ve anı kapsülleri bıraktığı ortak dijital alandır.

Tek kod tabanı (Flutter) ile Android ve iOS; backend Firebase.

---

## Özellikler

| Alan | İçerik |
| --- | --- |
| **Açılış / Onboarding** | Sinematik gün batımı splash'ı, "Başlayalım →", 4 ekranlık onboarding |
| **Kimlik** | E-posta/şifre, şifre sıfırlama, Google ile giriş, Apple ile giriş (iOS) |
| **Eşleştirme** | `VISAL-4X72Q` davet kodu + QR, kod girme / QR tarama, "X sizinle VISAL'da eşleşmek istiyor" kabul/ret, eşleşme animasyonu. Her kullanıcı tek partnerle eşleşir; eşleşme yalnızca Cloud Functions ile yapılır |
| **Biz (ana ekran)** | Kapak fotoğraflı hero, otomatik gün sayacı, İlişki Özetimiz (gün/anı/plan), Hızlı Erişim, Bugünün Sorusu, Yaklaşan, ruh hali, "X yıl önce bugün", Anı Kapsülü ve Hikâyemiz kartları |
| **Sohbet** | Metin, fotoğraf, video, sesli mesaj, dosya, emoji, GIF altyapısı (Tenor), yanıtla (kaydırarak da), düzenle, benden/herkesten sil, tepki, sabitle, gönderildi/okundu, yazıyor, çevrimiçi/son görülme, hızlı sevgi mesajları + "❤️ Partnerin seni düşünüyor" animasyonu, sayfalı sonsuz kaydırma, yükleme ilerlemesi |
| **Anılar** | Yıl gruplu zaman çizelgesi ↔ ızgara, filtreler (Tümü/Fotoğraflar/Videolar/Özel Günler/Seyahat), çoklu medya, konum, emoji, şarkı bağlantısı, tam ekran görüntüleyici, Bizim Hikâyemiz zaman çizelgesi |
| **Anı Kapsülü** | Mesaj + fotoğraf + video + ses, açılma tarihi, "Kapsülü Kilitle"; içerik tarihten önce **sunucu kurallarıyla** kilitli, tarihinde push bildirim |
| **Sorular** | 10 kategori, 120 soru, çifte özel deterministik günün sorusu; cevaplar ikisi de cevaplayınca açılır (kurallarla zorunlu) |
| **Ruh hali** | Günde bir, 8 emoji; partner görebilir (gizlenebilir), analiz yapılmaz |
| **Planlar** | Ortak takvim (kategori, saat, konum, not, hatırlatma, tekrar, renk), görevler (Ben/Partnerim/İkimiz), ortak hedefler (ilerleme çubuğu) |
| **Profil / Ayarlar** | Profil, partner, ilişki başlangıcı, yıldönümü, doğum günü; bildirimler, gizlilik (çevrimiçi, son görülme, okundu, bildirim içeriği gizli modu, ruh hali), tema (Açık / VISAL Dark / Sistem), PIN + parmak izi / Face ID kilidi, partner yönetimi, verileri indir (JSON), hesabı sil |
| **Bildirimler (FCM)** | Yeni mesaj, partner seni düşünüyor, yeni anı, kapsül açıldı, yaklaşan özel gün, günün sorusu; gizli modda "VISAL — Yeni mesaj" |

## Mimari

```
lib/
  app.dart, main.dart, firebase_options.dart
  core/
    theme/      renkler, tema (light + VISAL Dark), varlık yolları
    router/     go_router, 5 sekmeli kabuk (Biz · Sohbet · Anılar · Planlar · Profil)
    services/   Firebase sağlayıcıları, medya (sıkıştırma/thumbnail/yükleme), FCM,
                presence (RTDB), uygulama kilidi, tercihler
    session/    oturum/çift/partner sağlayıcıları
    widgets/    logo (vektörel V), butonlar, kartlar, görüntüleyici, seçiciler
    utils/      tarih, doğrulama, hata çevirisi
  features/
    auth | pairing | home | chat | memories | calendar | questions | capsules | profile | settings
      data/  domain/  presentation/
functions/        Cloud Functions (TypeScript)
firestore.rules   storage.rules   database.rules.json   firestore.indexes.json
rules-test/       Güvenlik kuralı testleri (Firebase Emulator)
```

- **State:** Riverpod 3 · **Navigasyon:** go_router · **Yerel:** SharedPreferences · **Güvenli yerel:** flutter_secure_storage · **Biyometrik:** local_auth
- **Performans:** Sohbette sabit sınırlı sayfalar (en yeni 30 canlı + eski sayfalar 30'luk), anılarda artan limitli sayfalama, çevrimdışı Firestore önbelleği (200 MB), resimlerde 2048px sıkıştırma + 480px thumbnail, videolarda thumbnail, `cached_network_image`.

## Veri modeli

```
users/{uid}                    uid, name, email, photoUrl, coupleId, birthday, createdAt, lastSeen, settings
  tokens/{fcmToken}            yalnızca sahibi
  inbox/{id}                   yalnızca Functions yazar
couples/{coupleId}             members, status, relationshipStartDate, anniversaryDate, theme, coverPhoto, createdAt
  profiles/{uid}               partnerin görebildiği profil kopyası (users/{uid} yalnızca sahibine açık)
  messages/{id}                senderId, type, text, mediaUrl, media, replyTo, reactions, createdAt, editedAt, seenBy, deletedFor, pinned
  memories/{id}                createdBy, title, description, date, media[], location, emoji, musicUrl, createdAt
  events/{id}                  title, category, date, time, location, note, reminder, repeat, createdBy
  tasks | goals | moods | questions | answers | capsules(+content/main) | timeline | albums
invites/{code}, pairRequests/{id}   yalnızca Functions yazar
RTDB presence/{uid}            online, lastSeen, typing   (yalnızca kendisi ve partneri okur)
```

## Güvenlik

- Kullanıcı yalnızca `users/{kendiUid}` belgesine erişir. `coupleId` istemciden **yazılamaz**.
- `couples/{coupleId}` ve alt koleksiyonlarına yalnızca `members` içindeki iki kişi erişir; coupleId tahmin edilse bile üçüncü kişi erişemez. Arşivlenen (eşleşmesi biten) alanlar herkese kapanır.
- Storage `couples/{coupleId}/...` üyeliği Firestore'dan okur (cross-service rules). Kapsül dosyaları açılma zamanına kadar alıcıya kapalıdır.
- Partnerin soru cevabı, kullanıcı kendi cevabını yazmadan okunamaz. Gizlenen ruh hali partnere kapalıdır.
- Callable fonksiyonlarda App Check zorunludur (Play Integrity / App Attest).
- Android'de yedekleme kapalı; eski depolama izinleri kullanılmaz (Photo Picker + SAF).

Kural testleri:

```bash
cd rules-test && npm install && npm test   # Java 11+ gerekir
```

## Demo modu (Firebase olmadan deneme)

`lib/firebase_options.dart` henüz `flutterfire configure` ile üretilmemişse (veya
`--dart-define=DEMO_MODE=true` verilirse) uygulama **demo modunda** açılır:

- Cihaz içinde sahte Firestore/Auth/Storage ve örnek verilerle dolu bir çift alanı kullanılır.
- Giriş ekranındaki **"Demo olarak gir"** butonu veya herhangi bir e-posta/şifre ile giriş yapılır.
- Demo partner "Ayşe" mesajlara cevap verir, okundu işaretler, bir süre sonra "❤️ seni düşünüyor" gönderir.
- Fotoğraf/video/ses dosyaları cihazda kalır; veriler uygulama kapanınca sıfırlanır.

GitHub Actions `GOOGLE_SERVICES_JSON` ve `FIREBASE_OPTIONS_DART` secret'ları tanımlı değilken demo APK üretir.

## Kurulum

1. **Araçlar:** Flutter 3.47+ (Dart 3.13+), Node 22, Firebase CLI, FlutterFire CLI.
2. **Firebase projesi** oluşturun; Authentication (E-posta, Google, Apple), Firestore, Storage, Realtime Database (europe-west1), Cloud Messaging, Functions ve App Check'i etkinleştirin.
3. **Uygulamayı bağlayın:**
   ```bash
   dart pub global activate flutterfire_cli
   flutterfire configure --project=<proje-id> --platforms=android,ios
   ```
   Bu komut `lib/firebase_options.dart`, `google-services.json` ve `GoogleService-Info.plist` dosyalarını üretir.
4. **Kurallar, indeksler ve fonksiyonlar:**
   ```bash
   firebase use <proje-id>
   cd functions && npm install && cd ..
   firebase deploy --only firestore,storage,database,functions
   ```
5. **Google Sign-In:** Android için SHA-1/SHA-256 parmak izlerini Firebase'e ekleyin; web istemci kimliğini
   `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` ile verin. iOS'ta `Info.plist` içindeki
   `REPLACE_WITH_REVERSED_CLIENT_ID` değerini `GoogleService-Info.plist`'teki `REVERSED_CLIENT_ID` ile değiştirin.
6. **Apple ile giriş:** Apple Developer'da "Sign in with Apple" yeteneğini açın, Firebase'de Apple sağlayıcısını yapılandırın
   (entitlement dosyası hazırdır: `ios/Runner/Runner.entitlements`).
7. **Push (iOS):** APNs anahtarını Firebase Cloud Messaging ayarlarına yükleyin; yayında `aps-environment` değerini `production` yapın.
8. **App Check:** Debug derlemeleri debug sağlayıcı kullanır; konsolda debug token'ı kaydedin. Yerel geliştirmede
   zorunluluğu kapatmak için `functions/.env.local` içine `ENFORCE_APP_CHECK=false` yazın.
9. **GIF (isteğe bağlı):** `--dart-define=TENOR_API_KEY=...`
10. **Çalıştırma:**
    ```bash
    flutter pub get
    flutter run
    ```
11. **Yayın imzası (Android):** `android/key.properties.example` dosyasını `key.properties` olarak kopyalayıp doldurun.

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
flutter test                    # domain birim testleri
cd functions && npm run build   # TypeScript derleme
cd rules-test && npm test       # güvenlik kuralları (emülatör)
```
