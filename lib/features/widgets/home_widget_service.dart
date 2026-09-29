import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:home_widget/home_widget.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/config/env.dart';
import '../../core/session/session_providers.dart';
import '../../core/utils/date_x.dart';
import '../chat/domain/message.dart';
import '../questions/data/questions_repository.dart';
import '../settings/presentation/lock_screen.dart';

/// Android ana ekran widget'ları ile paylaşılan anahtarlar
/// (android/app/src/main/kotlin/app/visal/visal/widget/WidgetData.kt ile aynı).
abstract final class WidgetKeys {
  static const state = 'w_state'; // signed_out | unpaired | ready
  static const since = 'w_since'; // yyyy-MM-dd
  static const partner = 'w_partner';
  static const mood = 'w_mood';
  static const private = 'w_private'; // "1" | "0"
  static const coupleId = 'w_couple_id';
  static const loveStatus = 'w_love_status';
}

abstract final class WidgetNames {
  static const together = 'app.visal.visal.widget.TogetherWidgetProvider';
  static const love = 'app.visal.visal.widget.LoveWidgetProvider';
}

/// Widget'ların gösterdiği anlık durum.
@immutable
class HomeWidgetData {
  const HomeWidgetData({
    required this.state,
    this.since,
    this.partner = '',
    this.mood = '',
    this.private = false,
    this.coupleId,
  });

  final String state;
  final DateTime? since;
  final String partner;
  final String mood;
  final bool private;
  final String? coupleId;

  @override
  bool operator ==(Object other) =>
      other is HomeWidgetData &&
      other.state == state &&
      other.since == since &&
      other.partner == partner &&
      other.mood == mood &&
      other.private == private &&
      other.coupleId == coupleId;

  @override
  int get hashCode => Object.hash(state, since, partner, mood, private, coupleId);
}

final homeWidgetDataProvider = Provider<HomeWidgetData>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return const HomeWidgetData(state: 'signed_out');
  final user = ref.watch(currentUserProvider).value;
  final couple = ref.watch(coupleProvider).value;
  if (user == null || !user.isPaired || couple == null) return const HomeWidgetData(state: 'unpaired');

  // Kilit veya gizli bildirim modu açıksa widget'ta isim/ruh hali gösterilmez.
  final lockEnabled = ref.watch(appLockControllerProvider).value?.enabled ?? false;
  final private = lockEnabled || !user.settings.privacy.notificationPreview;
  final partner = ref.watch(partnerProfileProvider);
  final mood = ref.watch(partnerMoodProvider).value;
  return HomeWidgetData(
    state: 'ready',
    since: couple.togetherSince,
    partner: partner?.firstName ?? '',
    mood: mood?.emoji ?? '',
    private: private,
    coupleId: couple.id,
  );
});

bool get _widgetsSupported => !kIsWeb && Platform.isAndroid;

abstract final class HomeWidgetService {
  static Future<void> init() async {
    if (!_widgetsSupported) return;
    await HomeWidget.registerInteractivityCallback(homeWidgetBackgroundCallback);
  }

  static Future<void> push(HomeWidgetData d) async {
    if (!_widgetsSupported) return;
    try {
      await Future.wait([
        HomeWidget.saveWidgetData<String>(WidgetKeys.state, d.state),
        HomeWidget.saveWidgetData<String>(WidgetKeys.since, d.since == null ? '' : dayKey(d.since!)),
        HomeWidget.saveWidgetData<String>(WidgetKeys.partner, d.partner),
        HomeWidget.saveWidgetData<String>(WidgetKeys.mood, d.mood),
        HomeWidget.saveWidgetData<String>(WidgetKeys.private, d.private ? '1' : '0'),
        HomeWidget.saveWidgetData<String>(WidgetKeys.coupleId, d.coupleId ?? ''),
        if (d.state != 'ready') HomeWidget.saveWidgetData<String>(WidgetKeys.loveStatus, ''),
      ]);
      await _refresh();
    } catch (e) {
      debugPrint('Widget güncellenemedi: $e');
    }
  }

  static Future<void> _refresh() async {
    await HomeWidget.updateWidget(qualifiedAndroidName: WidgetNames.together);
    await HomeWidget.updateWidget(qualifiedAndroidName: WidgetNames.love);
  }
}

/// supabase_flutter'ın oturumu sakladığı SharedPreferences anahtarı.
String get supabaseSessionKey => 'sb-${Uri.parse(Env.supabaseUrl).host.split('.').first}-auth-token';

/// Arka planda (uygulama kapalıyken) ❤️ widget'ına dokunulunca çalışır.
///
/// Uygulamanın saklı oturumu kullanılır; süresi dolmuşsa yenilenip aynı yere
/// yazılır, uygulama öne geldiğinde [resyncSessionFromStorage] ile eşitlenir.
@pragma('vm:entry-point')
Future<void> homeWidgetBackgroundCallback(Uri? uri) async {
  if (uri?.host != 'love') return;
  Future<void> status(String text) async {
    await HomeWidget.saveWidgetData<String>(WidgetKeys.loveStatus, text);
    await HomeWidget.updateWidget(qualifiedAndroidName: WidgetNames.love);
  }

  await status('Gönderiliyor…');
  SupabaseClient? client;
  try {
    final coupleId = await HomeWidget.getWidgetData<String>(WidgetKeys.coupleId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.reload();
    final raw = prefs.getString(supabaseSessionKey);
    if (raw == null || coupleId == null || coupleId.isEmpty || !Env.supabaseConfigured) {
      await status('Önce VISAL\'e giriş yap');
      return;
    }
    client = SupabaseClient(
      Env.supabaseUrl,
      Env.supabaseAnonKey,
      authOptions: const AuthClientOptions(autoRefreshToken: false),
    );
    final session = (await client.auth.recoverSession(raw)).session;
    if (session == null) throw const AuthException('Oturum bulunamadı');
    if (session.refreshToken != (jsonDecode(raw) as Map)['refresh_token']) {
      await prefs.setString(supabaseSessionKey, jsonEncode(session.toJson()));
    }
    final uid = session.user.id;
    await client.from('messages').insert({
      'couple_id': coupleId,
      'sender_id': uid,
      'type': MessageType.love.name,
      'text': LoveKind.love.text,
      'love_kind': LoveKind.love.name,
      'seen_by': [uid],
    });
    final now = DateTime.now();
    await status('Gönderildi · ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}');
  } catch (e) {
    debugPrint('Widget ❤️ gönderilemedi: $e');
    await status(e is SocketException ? 'İnternet yok' : 'Gönderilemedi');
  } finally {
    await client?.dispose();
  }
}

/// Widget arka planda oturumu yenilediyse uygulamanın bellekteki oturumunu
/// saklanan (daha yeni) oturumla değiştirir; aksi halde eski yenileme anahtarı
/// kullanılır ve oturum düşerdi.
Future<void> resyncSessionFromStorage(SharedPreferences prefs, GoTrueClient auth) async {
  if (!_widgetsSupported) return;
  try {
    await prefs.reload();
    final raw = prefs.getString(supabaseSessionKey);
    final current = auth.currentSession;
    if (raw == null || current == null) return;
    final stored = (jsonDecode(raw) as Map)['refresh_token'];
    if (stored is String && stored != current.refreshToken) {
      await auth.recoverSession(raw);
    }
  } catch (e) {
    debugPrint('Oturum eşitlenemedi: $e');
  }
}
