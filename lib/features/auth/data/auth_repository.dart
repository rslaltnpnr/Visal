import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/env.dart';
import '../../../core/services/supabase_providers.dart';
import '../../../core/utils/failure.dart';

/// Google Sign-In web istemci kimliği (Supabase Google sağlayıcısı ile aynı).
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=...`
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseProvider).auth),
);

enum RegisterResult { signedIn, confirmEmail }

class AuthRepository {
  AuthRepository(this._auth);

  final GoTrueClient _auth;
  bool _googleInitialized = false;

  Stream<AuthState> authStateChanges() => _auth.onAuthStateChange;
  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithPassword(email: email.trim(), password: password);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Profil satırı veritabanı tetikleyicisiyle otomatik oluşur.
  /// E-posta doğrulaması açıksa oturum hemen açılmaz.
  Future<RegisterResult> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final res = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'name': name.trim()},
        emailRedirectTo: Env.authRedirect,
      );
      return res.session != null ? RegisterResult.signedIn : RegisterResult.confirmEmail;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim(), redirectTo: Env.authRedirect);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Şifre sıfırlama bağlantısıyla gelen oturumda yeni şifreyi kaydeder.
  Future<void> updatePassword(String password) async {
    try {
      await _auth.updateUser(UserAttributes(password: password));
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final google = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await google.initialize(
          serverClientId: _googleServerClientId.isEmpty ? null : _googleServerClientId,
        );
        _googleInitialized = true;
      }
      final account = await google.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken == null) throw const AppFailure('Google kimliği alınamadı.');
      await _auth.signInWithIdToken(provider: OAuthProvider.google, idToken: idToken);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AppFailure('Google girişi iptal edildi.', code: 'cancelled');
      }
      throw AppFailure('Google ile giriş yapılamadı (${e.code.name}).');
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Apple ile giriş: iOS'ta yerel akış. Supabase'de Apple sağlayıcısı ve
  /// Xcode'da "Sign in with Apple" yeteneği açık olmalıdır.
  static bool get appleSignInSupported => !kIsWeb && Platform.isIOS;

  Future<void> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [AppleIDAuthorizationScopes.email, AppleIDAuthorizationScopes.fullName],
        nonce: nonce,
      );
      final idToken = apple.identityToken;
      if (idToken == null) throw const AppFailure('Apple kimliği alınamadı.');
      await _auth.signInWithIdToken(provider: OAuthProvider.apple, idToken: idToken, nonce: rawNonce);
      final fullName = [apple.givenName, apple.familyName].whereType<String>().join(' ').trim();
      if (fullName.isNotEmpty) {
        await _auth.updateUser(UserAttributes(data: {'name': fullName}));
      }
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        throw const AppFailure('Apple girişi iptal edildi.', code: 'cancelled');
      }
      throw const AppFailure('Apple ile giriş yapılamadı.');
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> signOut() async {
    if (_googleInitialized) await GoogleSignIn.instance.signOut();
    await _auth.signOut();
  }

  String _generateNonce([int length = 32]) {
    const charset = '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)]).join();
  }
}
