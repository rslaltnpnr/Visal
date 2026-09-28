import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/utils/failure.dart';
import '../../settings/domain/user_settings.dart';

/// Google Sign-In web/sunucu istemci kimliği (Android'de gerekli).
/// `--dart-define=GOOGLE_SERVER_CLIENT_ID=...` ile verilir; boşsa
/// google-services.json içindeki değer kullanılır.
const _googleServerClientId =
    String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(
    ref.watch(firebaseAuthProvider),
    ref.watch(firestoreProvider),
  ),
);

class AuthRepository {
  AuthRepository(this._auth, this._db);

  final FirebaseAuth _auth;
  final FirebaseFirestore _db;
  bool _googleInitialized = false;

  Stream<User?> authStateChanges() => _auth.authStateChanges();
  User? get currentUser => _auth.currentUser;

  Future<void> signInWithEmail(String email, String password) async {
    try {
      await _auth.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    try {
      final cred = await _auth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await cred.user!.updateDisplayName(name.trim());
      await ensureUserDoc(cred.user!, name: name.trim());
      await cred.user!.sendEmailVerification();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> sendPasswordReset(String email) async {
    try {
      await _auth.setLanguageCode('tr');
      await _auth.sendPasswordResetEmail(email: email.trim());
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      final google = GoogleSignIn.instance;
      if (!_googleInitialized) {
        await google.initialize(
          serverClientId:
              _googleServerClientId.isEmpty ? null : _googleServerClientId,
        );
        _googleInitialized = true;
      }
      final account = await google.authenticate(scopeHint: const ['email']);
      final idToken = account.authentication.idToken;
      if (idToken == null) {
        throw const AppFailure('Google kimliği alınamadı.');
      }
      final cred = await _auth.signInWithCredential(
        GoogleAuthProvider.credential(idToken: idToken),
      );
      await ensureUserDoc(cred.user!, name: account.displayName);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) {
        throw const AppFailure('Google girişi iptal edildi.', code: 'cancelled');
      }
      throw AppFailure('Google ile giriş yapılamadı (${e.code.name}).');
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Apple ile giriş: iOS'ta yerel akış. Firebase konsolunda Apple sağlayıcısı
  /// ve Xcode'da "Sign in with Apple" yeteneği açık olmalıdır.
  static bool get appleSignInSupported => !kIsWeb && Platform.isIOS;

  Future<void> signInWithApple() async {
    try {
      final rawNonce = _generateNonce();
      final nonce = sha256.convert(utf8.encode(rawNonce)).toString();
      final apple = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: nonce,
      );
      final credential = OAuthProvider('apple.com').credential(
        idToken: apple.identityToken,
        rawNonce: rawNonce,
        accessToken: apple.authorizationCode,
      );
      final cred = await _auth.signInWithCredential(credential);
      final fullName = [apple.givenName, apple.familyName]
          .whereType<String>()
          .join(' ')
          .trim();
      if (fullName.isNotEmpty && (cred.user!.displayName ?? '').isEmpty) {
        await cred.user!.updateDisplayName(fullName);
      }
      await ensureUserDoc(cred.user!, name: fullName);
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
    if (_googleInitialized) {
      await GoogleSignIn.instance.signOut();
    }
    await _auth.signOut();
  }

  /// İlk girişte users/{uid} belgesini oluşturur.
  Future<void> ensureUserDoc(User user, {String? name}) async {
    final ref = _db.userDoc(user.uid);
    final snap = await ref.get();
    if (snap.exists) return;
    final displayName = (name?.isNotEmpty ?? false)
        ? name!
        : (user.displayName ?? user.email?.split('@').first ?? 'VISAL');
    await ref.set({
      'uid': user.uid,
      'name': displayName,
      'email': user.email ?? '',
      'photoUrl': user.photoURL,
      'coupleId': null,
      'birthday': null,
      'createdAt': FieldValue.serverTimestamp(),
      'lastSeen': FieldValue.serverTimestamp(),
      'settings': const UserSettings().toMap(),
    });
  }

  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._';
    final random = Random.secure();
    return List.generate(length, (_) => charset[random.nextInt(charset.length)])
        .join();
  }
}
