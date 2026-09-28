import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Kullanıcıya gösterilebilir hata.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    if (error is FirebaseAuthException) {
      return AppFailure(_authMessage(error.code), code: error.code);
    }
    if (error is FirebaseFunctionsException) {
      return AppFailure(error.message ?? 'Bir hata oluştu.', code: error.code);
    }
    if (error is FirebaseException) {
      return AppFailure(_firebaseMessage(error.code), code: error.code);
    }
    return const AppFailure('Beklenmeyen bir hata oluştu. Tekrar deneyin.');
  }

  static String _authMessage(String code) => switch (code) {
        'invalid-email' => 'E-posta adresi geçersiz.',
        'user-disabled' => 'Bu hesap devre dışı bırakılmış.',
        'user-not-found' ||
        'wrong-password' ||
        'invalid-credential' =>
          'E-posta veya şifre hatalı.',
        'email-already-in-use' => 'Bu e-posta ile zaten bir hesap var.',
        'weak-password' => 'Şifre çok zayıf.',
        'too-many-requests' =>
          'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.',
        'network-request-failed' => 'İnternet bağlantınızı kontrol edin.',
        'requires-recent-login' =>
          'Güvenliğiniz için lütfen tekrar giriş yapın.',
        'account-exists-with-different-credential' =>
          'Bu e-posta başka bir giriş yöntemiyle kayıtlı.',
        'cancelled' => 'İşlem iptal edildi.',
        _ => 'Giriş yapılamadı. Tekrar deneyin.',
      };

  static String _firebaseMessage(String code) => switch (code) {
        'permission-denied' => 'Bu işlem için yetkiniz yok.',
        'unavailable' => 'Sunucuya ulaşılamıyor. Bağlantınızı kontrol edin.',
        'not-found' => 'İçerik bulunamadı.',
        'canceled' => 'İşlem iptal edildi.',
        'unauthorized' => 'Bu dosyaya erişim yetkiniz yok.',
        _ => 'Bir hata oluştu. Tekrar deneyin.',
      };

  @override
  String toString() => message;
}
