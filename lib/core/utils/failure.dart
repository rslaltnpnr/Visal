import 'dart:async';
import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

/// Kullanıcıya gösterilebilir hata.
class AppFailure implements Exception {
  const AppFailure(this.message, {this.code});

  final String message;
  final String? code;

  factory AppFailure.from(Object error) {
    if (error is AppFailure) return error;
    if (error is AuthException) {
      return AppFailure(_authMessage(error), code: error.code);
    }
    if (error is PostgrestException) {
      // Sunucu fonksiyonları (RPC) Türkçe, kullanıcıya gösterilebilir mesaj üretir.
      if (error.code == 'P0001' || error.code == '42501' || error.code == '28000') {
        return AppFailure(error.message, code: error.code);
      }
      if (error.code == '23505') return const AppFailure('Bu kayıt zaten mevcut.', code: '23505');
      return AppFailure('İşlem tamamlanamadı. Tekrar deneyin.', code: error.code);
    }
    if (error is StorageException) {
      return AppFailure(
        error.statusCode == '413' ? 'Dosya çok büyük.' : 'Dosya yüklenemedi. Tekrar deneyin.',
        code: error.statusCode,
      );
    }
    if (error is SocketException || error is TimeoutException) {
      return const AppFailure('İnternet bağlantınızı kontrol edin.');
    }
    return const AppFailure('Beklenmeyen bir hata oluştu. Tekrar deneyin.');
  }

  static String _authMessage(AuthException e) {
    final code = e.code ?? '';
    final msg = e.message.toLowerCase();
    if (code == 'invalid_credentials' || msg.contains('invalid login')) return 'E-posta veya şifre hatalı.';
    if (code == 'email_not_confirmed' || msg.contains('not confirmed')) {
      return 'E-posta adresin henüz doğrulanmadı. Gelen kutundaki bağlantıya dokun.';
    }
    if (code == 'user_already_exists' || msg.contains('already registered')) {
      return 'Bu e-posta ile zaten bir hesap var.';
    }
    if (code == 'weak_password' || msg.contains('password should')) return 'Şifre çok zayıf.';
    if (code == 'over_email_send_rate_limit' || code == 'over_request_rate_limit' || e.statusCode == '429') {
      return 'Çok fazla deneme yapıldı. Lütfen biraz sonra tekrar deneyin.';
    }
    if (code == 'same_password') return 'Yeni şifre eskisiyle aynı olamaz.';
    if (code == 'cancelled') return 'İşlem iptal edildi.';
    return 'Giriş yapılamadı. Tekrar deneyin.';
  }

  @override
  String toString() => message;
}
