import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock_this_device),
  ),
);

final appLockServiceProvider = Provider<AppLockService>(
  (ref) => AppLockService(ref.watch(secureStorageProvider), LocalAuthentication()),
);

enum BiometricKind { none, fingerprint, face }

/// PIN (tuzlanmış SHA-256, güvenli depoda) + biyometrik kilit.
class AppLockService {
  AppLockService(this._storage, this._localAuth);

  final FlutterSecureStorage _storage;
  final LocalAuthentication _localAuth;

  static const _pinHash = 'visal_pin_hash';
  static const _pinSalt = 'visal_pin_salt';
  static const _biometric = 'visal_biometric_enabled';
  static const _failed = 'visal_pin_failed';

  Future<bool> isLockEnabled() async => (await _storage.read(key: _pinHash)) != null;

  Future<bool> isBiometricEnabled() async =>
      (await _storage.read(key: _biometric)) == 'true';

  Future<void> setPin(String pin) async {
    final salt = base64Url.encode(
      List<int>.generate(16, (_) => Random.secure().nextInt(256)),
    );
    await _storage.write(key: _pinSalt, value: salt);
    await _storage.write(key: _pinHash, value: _hash(pin, salt));
    await _storage.delete(key: _failed);
  }

  Future<bool> verifyPin(String pin) async {
    final salt = await _storage.read(key: _pinSalt);
    final hash = await _storage.read(key: _pinHash);
    if (salt == null || hash == null) return true;
    final ok = _hash(pin, salt) == hash;
    if (ok) {
      await _storage.delete(key: _failed);
    } else {
      final failed = int.tryParse(await _storage.read(key: _failed) ?? '0') ?? 0;
      await _storage.write(key: _failed, value: '${failed + 1}');
    }
    return ok;
  }

  Future<int> failedAttempts() async =>
      int.tryParse(await _storage.read(key: _failed) ?? '0') ?? 0;

  Future<void> disableLock() async {
    await _storage.delete(key: _pinHash);
    await _storage.delete(key: _pinSalt);
    await _storage.delete(key: _biometric);
    await _storage.delete(key: _failed);
  }

  Future<void> setBiometricEnabled(bool enabled) =>
      _storage.write(key: _biometric, value: '$enabled');

  Future<BiometricKind> availableBiometric() async {
    try {
      if (!await _localAuth.isDeviceSupported()) return BiometricKind.none;
      if (!await _localAuth.canCheckBiometrics) return BiometricKind.none;
      final types = await _localAuth.getAvailableBiometrics();
      if (types.contains(BiometricType.face)) return BiometricKind.face;
      if (types.isNotEmpty) return BiometricKind.fingerprint;
      return BiometricKind.none;
    } on PlatformException {
      return BiometricKind.none;
    }
  }

  Future<bool> authenticateBiometric() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'VISAL\'ı açmak için kimliğinizi doğrulayın',
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      );
    } on PlatformException {
      return false;
    } on LocalAuthException {
      return false;
    }
  }

  static String _hash(String pin, String salt) {
    List<int> digest = utf8.encode('$salt:$pin');
    // Anahtar germe: kaba kuvveti yavaşlatmak için çoklu tur.
    for (var i = 0; i < 10000; i++) {
      digest = sha256.convert(digest).bytes;
    }
    return base64Url.encode(digest);
  }
}
