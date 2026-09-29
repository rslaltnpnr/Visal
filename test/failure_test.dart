import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:visal/core/utils/failure.dart';

void main() {
  String msg(String message, {String? code}) => AppFailure.from(AuthException(message, code: code)).message;

  test('bilinen giriş hataları Türkçe ve yönlendirici', () {
    expect(msg('Invalid login credentials', code: 'invalid_credentials'), 'E-posta veya şifre hatalı.');
    expect(msg('Provider (issuer "https://accounts.google.com") is not enabled'), contains('Providers'));
    expect(msg('Unacceptable audience in id_token: [123.apps.googleusercontent.com]'), contains('Client IDs'));
    expect(msg('Passed nonce and nonce in id_token should either both exist or not.'), contains('nonce'));
  });

  test('tanınmayan hata sunucu mesajıyla gösterilir', () {
    expect(msg('Something odd happened'), 'Giriş yapılamadı: Something odd happened');
    expect(msg('  '), 'Giriş yapılamadı. Tekrar deneyin.');
  });
}
