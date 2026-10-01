import 'dart:async';
import 'dart:io';
import 'dart:ui' show Color;

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../firebase_options.dart';
import '../config/env.dart';
import 'supabase_providers.dart';

const _replyActionId = 'visal_reply';

/// Bildirimdeki Android "Yanıtla" alanından gelen metni, uygulamayı açmadan
/// mevcut oturumla doğrudan sohbet mesajına çevirir.
@pragma('vm:entry-point')
void visalNotificationBackgroundResponse(NotificationResponse response) async {
  if (response.actionId != _replyActionId) return;
  final text = response.input?.trim();
  if (text == null || text.isEmpty) return;
  final sent = await _sendQuickReply(text);
  if (sent && response.id != null) {
    try {
      await FlutterLocalNotificationsPlugin().cancel(id: response.id!);
    } catch (_) {}
  }
}

/// Android'de mesaj push'ları data-only gelir. Böylece sistemin kısıtlı FCM
/// bildirimi yerine VISAL kendi yerel bildirimini oluşturup Yanıtla aksiyonu
/// ekleyebilir. Firebase bu işleyiciyi uygulama kapalıyken ayrı isolate'ta açar.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kIsWeb || !Platform.isAndroid) return;
  WidgetsFlutterBinding.ensureInitialized();
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
    }
    await _showAndroidPush(message);
  } catch (e) {
    debugPrint('Arka plan bildirimi gösterilemedi: $e');
  }
}

Future<bool> _sendQuickReply(String text) async {
  if (!Env.supabaseConfigured) return false;
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Supabase.initialize(
      url: Env.supabaseUrl,
      publishableKey: Env.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(authFlowType: AuthFlowType.pkce),
    );
  } catch (_) {
    // Ayrı isolate'ta normalde ilk kez kurulur; aynı isolate'ta zaten kuruluysa
    // mevcut singleton istemci kullanılabilir.
  }

  try {
    final db = Supabase.instance.client;
    if (db.auth.currentSession == null) return false;
    try {
      await db.auth.refreshSession();
    } catch (_) {
      // Geçerli access token varsa refresh başarısız olsa da aşağıdaki RLS isteği
      // güvenli biçimde sonucu belirler.
    }
    final uid = db.auth.currentUser?.id;
    if (uid == null) return false;
    final profile = await db.from('profiles').select('couple_id').eq('id', uid).maybeSingle();
    final coupleId = profile?['couple_id'] as String?;
    if (coupleId == null || coupleId.isEmpty) return false;
    await db.from('messages').insert({
      'couple_id': coupleId,
      'sender_id': uid,
      'type': 'text',
      'text': text,
      'seen_by': [uid],
    });
    return true;
  } catch (e) {
    debugPrint('Bildirimden yanıt gönderilemedi: $e');
    return false;
  }
}

Future<void> _showAndroidPush(
  RemoteMessage message, {
  FlutterLocalNotificationsPlugin? local,
}) async {
  if (!Platform.isAndroid) return;
  final plugin = local ?? FlutterLocalNotificationsPlugin();
  if (local == null) {
    await plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      ),
      onDidReceiveBackgroundNotificationResponse: visalNotificationBackgroundResponse,
    );
  }

  final type = message.data['type'] as String? ?? '';
  final title = (message.data['title'] as String?) ?? message.notification?.title ?? 'VISAL';
  final body = (message.data['body'] as String?) ?? message.notification?.body ?? 'Yeni bildirim';
  final route = message.data['route'] as String?;
  final channel = switch (type) {
    'message' || 'love' => VisalChannels.messages,
    'event' => VisalChannels.reminders,
    _ => VisalChannels.moments,
  };

  final android = plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
  await android?.createNotificationChannel(channel);

  final actions = type == 'message'
      ? const <AndroidNotificationAction>[
          AndroidNotificationAction(
            _replyActionId,
            'Yanıtla',
            inputs: <AndroidNotificationActionInput>[
              AndroidNotificationActionInput(label: 'Mesaj yaz…'),
            ],
            semanticAction: SemanticAction.reply,
            allowGeneratedReplies: true,
            showsUserInterface: false,
            cancelNotification: false,
          ),
        ]
      : const <AndroidNotificationAction>[];

  final id = (message.messageId ?? '${DateTime.now().microsecondsSinceEpoch}-${message.hashCode}').hashCode & 0x7fffffff;
  await plugin.show(
    id: id,
    title: title,
    body: body,
    payload: route,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        channel.id,
        channel.name,
        channelDescription: channel.description,
        importance: channel.importance,
        priority: Priority.high,
        color: const Color(0xFFB68AA0),
        icon: '@mipmap/ic_launcher',
        category: type == 'message' ? AndroidNotificationCategory.message : null,
        actions: actions,
        styleInformation: BigTextStyleInformation(body),
      ),
    ),
  );
}

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    Env.pushConfigured && Firebase.apps.isNotEmpty ? FirebaseMessaging.instance : null,
    ref.watch(supabaseProvider),
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
  /// Firebase yapılandırılmadıysa null: bildirimler yalnızca uygulama
  /// içi bildirim kutusuna düşer.
  NotificationService(this._fcm, this._db);

  final FirebaseMessaging? _fcm;
  final SupabaseClient _db;
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
      onDidReceiveNotificationResponse: (r) async {
        if (r.actionId == _replyActionId) {
          final text = r.input?.trim();
          if (text != null && text.isNotEmpty) {
            final sent = await _sendQuickReply(text);
            if (sent && r.id != null) await _local.cancel(id: r.id!);
          }
          return;
        }
        final route = r.payload;
        if (route != null && route.isNotEmpty) _tapController.add(route);
      },
      onDidReceiveBackgroundNotificationResponse: visalNotificationBackgroundResponse,
    );

    final launch = await _local.getNotificationAppLaunchDetails();
    final launchRoute = launch?.notificationResponse?.payload;
    if ((launch?.didNotificationLaunchApp ?? false) && launchRoute != null && launchRoute.isNotEmpty) {
      Future<void>.delayed(const Duration(milliseconds: 600), () => _tapController.add(launchRoute));
    }

    final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    for (final c in [
      VisalChannels.messages,
      VisalChannels.moments,
      VisalChannels.reminders,
    ]) {
      await android?.createNotificationChannel(c);
    }

    final messaging = _fcm;
    if (messaging == null) return;

    // iOS: ön planda sistem bildirimini göster (Android'de yerel bildirim).
    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _subs.add(FirebaseMessaging.onMessage.listen(_onForegroundMessage));
    _subs.add(FirebaseMessaging.onMessageOpenedApp.listen(_onOpened));
    final initial = await messaging.getInitialMessage();
    if (initial != null) {
      Future<void>.delayed(const Duration(milliseconds: 600), () => _onOpened(initial));
    }
  }

  /// Android 13+ POST_NOTIFICATIONS ve iOS izin istemi.
  Future<bool> requestPermission() async {
    final messaging = _fcm;
    if (messaging == null) {
      final android = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      return await android?.requestNotificationsPermission() ?? true;
    }
    final settings = await messaging.requestPermission(
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
    final messaging = _fcm;
    if (messaging == null) return;
    if (Platform.isIOS) {
      for (var i = 0; i < 5; i++) {
        if (await messaging.getAPNSToken() != null) break;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    try {
      final token = await messaging.getToken();
      if (token != null) await _saveToken(uid, token);
    } catch (e) {
      debugPrint('FCM token alınamadı: $e');
    }
    _subs.add(messaging.onTokenRefresh.listen((t) {
      if (_uid != null) _saveToken(_uid!, t);
    }));
  }

  /// Aynı cihaz başka hesaba geçtiyse jeton yeni kullanıcıya devredilir.
  /// Yeni Android istemcisi inline-reply capability'sini de kaydeder. Migration
  /// henüz ulaşmadıysa iki parametreli eski RPC'ye geri düşülür.
  Future<void> _saveToken(String uid, String token) async {
    try {
      await _db.rpc<void>('claim_device_token', params: {
        'p_token': token,
        'p_platform': Platform.operatingSystem,
        'p_inline_reply': Platform.isAndroid,
      });
    } catch (_) {
      try {
        await _db.rpc<void>('claim_device_token', params: {
          'p_token': token,
          'p_platform': Platform.operatingSystem,
        });
      } catch (e) {
        debugPrint('Cihaz jetonu kaydedilemedi: $e');
      }
    }
  }

  /// Çıkışta bu cihazın jetonunu siler.
  Future<void> unregister() async {
    final uid = _uid;
    _uid = null;
    final messaging = _fcm;
    if (uid == null || kIsWeb || messaging == null) return;
    try {
      final token = await messaging.getToken();
      if (token != null) {
        await _db.from('device_tokens').delete().eq('token', token);
      }
      await messaging.deleteToken();
    } catch (_) {}
  }

  void _onOpened(RemoteMessage m) {
    final route = m.data['route'] as String?;
    if (route != null && route.isNotEmpty) _tapController.add(route);
  }

  Future<void> _onForegroundMessage(RemoteMessage m) async {
    if (!Platform.isAndroid) return;
    final type = m.data['type'] as String? ?? '';
    if (chatVisible && (type == 'message' || type == 'love')) return;
    await _showAndroidPush(m, local: _local);
  }

  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _tapController.close();
  }
}
