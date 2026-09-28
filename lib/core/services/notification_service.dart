import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'firebase_providers.dart';

/// Arka planda gelen FCM mesajları. Bildirim yükü sistem tarafından
/// gösterildiği için burada ek iş yapılmaz; fonksiyon izole girişi olmalı.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    ref.watch(messagingProvider),
    ref.watch(firestoreProvider),
  );
  ref.onDispose(service.dispose);
  return service;
});

/// Android bildirim kanalları (sunucu `android.notification.channelId` ile eşler).
abstract final class VisalChannels {
  static const messages = AndroidNotificationChannel(
    'visal_messages',
    'Mesajlar',
    description: 'Partnerinden gelen mesajlar',
    importance: Importance.high,
  );
  static const moments = AndroidNotificationChannel(
    'visal_moments',
    'Anılar ve kapsüller',
    description: 'Yeni anılar, açılan kapsüller, günün sorusu',
    importance: Importance.defaultImportance,
  );
  static const reminders = AndroidNotificationChannel(
    'visal_reminders',
    'Hatırlatmalar',
    description: 'Yaklaşan özel günler ve planlar',
    importance: Importance.high,
  );
}

class NotificationService {
  NotificationService(this._messaging, this._db);

  final FirebaseMessaging _messaging;
  final FirebaseFirestore _db;
  final _local = FlutterLocalNotificationsPlugin();
  final _tapController = StreamController<String>.broadcast();
  final List<StreamSubscription<dynamic>> _subs = [];
  bool _initialized = false;
  String? _uid;

  /// Sohbet ekranı açıkken mesaj bildirimleri ön planda gösterilmez.
  bool chatVisible = false;

  /// Bildirime dokunulduğunda açılacak rota (ör. `/chat`).
  Stream<String> get onTapRoute => _tapController.stream;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    await _local.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      ),
      onDidReceiveNotificationResponse: (r) {
        final route = r.payload;
        if (route != null && route.isNotEmpty) _tapController.add(route);
      },
    );

    final android = _local.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    for (final c in [
      VisalChannels.messages,
      VisalChannels.moments,
      VisalChannels.reminders,
    ]) {
      await android?.createNotificationChannel(c);
    }

    // iOS: ön planda sistem bildirimini göster (Android'de yerel bildirim).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _subs.add(FirebaseMessaging.onMessage.listen(_onForegroundMessage));
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_onOpened));
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      // Router hazır olduktan sonra işlenmesi için küçük gecikme.
      Future<void>.delayed(const Duration(milliseconds: 600), () => _onOpened(initial));
    }
  }

  /// Android 13+ POST_NOTIFICATIONS ve iOS izin istemi.
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Kullanıcı giriş yaptığında cihaz jetonunu kaydeder.
  Future<void> registerUser(String uid) async {
    if (kIsWeb) return;
    _uid = uid;
    await requestPermission();
    if (Platform.isIOS) {
      // APNs jetonu hazır olmadan FCM jetonu alınamaz.
      for (var i = 0; i < 5; i++) {
        if (await _messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    try {
      final token = await _messaging.getToken();
      if (token != null) await _saveToken(uid, token);
    } catch (e) {
      debugPrint('FCM token alınamadı: $e');
    }
    _subs.add(_messaging.onTokenRefresh.listen((t) {
      if (_uid != null) _saveToken(_uid!, t);
    }));
  }

  Future<void> _saveToken(String uid, String token) =>
      _db.userDoc(uid).collection('tokens').doc(token).set({
        'token': token,
        'platform': Platform.operatingSystem,
        'updatedAt': FieldValue.serverTimestamp(),
      });

  /// Çıkışta bu cihazın jetonunu siler.
  Future<void> unregister() async {
    final uid = _uid;
    _uid = null;
    if (uid == null || kIsWeb) return;
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _db.userDoc(uid).collection('tokens').doc(token).delete();
      }
      await _messaging.deleteToken();
    } catch (_) {}
  }

  void _onOpened(RemoteMessage m) {
    final route = m.data['route'] as String?;
    if (route != null && route.isNotEmpty) _tapController.add(route);
  }

  Future<void> _onForegroundMessage(RemoteMessage m) async {
    if (!Platform.isAndroid) return; // iOS sistem tarafından gösterilir.
    final type = m.data['type'] as String? ?? '';
    if (chatVisible && (type == 'message' || type == 'love')) return;
    final n = m.notification;
    if (n == null) return;
    final channel = switch (type) {
      'message' || 'love' => VisalChannels.messages,
      'event' => VisalChannels.reminders,
      _ => VisalChannels.moments,
    };
    await _local.show(
      id: m.hashCode & 0x7fffffff,
      title: n.title,
      body: n.body,
      payload: m.data['route'] as String?,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channel.id,
          channel.name,
          channelDescription: channel.description,
          importance: channel.importance,
          priority: Priority.high,
          color: const Color(0xFFB68AA0),
          icon: '@mipmap/ic_launcher',
        ),
      ),
    );
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _tapController.close();
  }
}
