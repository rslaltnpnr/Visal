import '../../firebase_options.dart';

/// Supabase proje ayarları.
///
/// Anon (publishable) anahtar istemcide bulunmak üzere tasarlanmıştır;
/// verileri veritabanındaki RLS politikaları korur. Değerler
/// `--dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...`
/// ile de verilebilir.
abstract final class Env {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: _defaultUrl);
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: _defaultAnonKey);

  // Supabase projesi oluşturulunca doldurulur.
  static const _defaultUrl = '';
  static const _defaultAnonKey = '';

  static bool get supabaseConfigured => supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  /// Push bildirimleri (FCM) için Firebase yapılandırılmış mı?
  /// Firebase yalnızca bildirim iletimi için kullanılır (ücretsiz Spark planı yeterli).
  static bool get pushConfigured => !DefaultFirebaseOptions.android.apiKey.startsWith('REPLACE');

  /// E-posta doğrulama / şifre sıfırlama bağlantılarının uygulamaya dönüş adresi.
  static const authRedirect = 'visal://auth-callback';
}
