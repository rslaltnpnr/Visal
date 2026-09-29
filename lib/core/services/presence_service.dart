import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/settings/domain/user_settings.dart';
import '../session/session_providers.dart';
import 'supabase_providers.dart';

/// Partnerin anlık durumu. `online` ve `typing` çiftin özel Realtime
/// kanalından (presence + broadcast), `lastSeen` veritabanından gelir.
class PresenceState {
  const PresenceState({this.online = false, this.lastSeen, this.typing = false});

  final bool online;
  final DateTime? lastSeen;
  final bool typing;

  PresenceState copyWith({bool? online, DateTime? lastSeen, bool? typing}) => PresenceState(
        online: online ?? this.online,
        lastSeen: lastSeen ?? this.lastSeen,
        typing: typing ?? this.typing,
      );
}

final presenceServiceProvider = Provider<PresenceService>((ref) {
  final service = PresenceService(ref.watch(supabaseProvider));
  ref.onDispose(service.dispose);
  return service;
});

final partnerPresenceProvider = StreamProvider<PresenceState>((ref) {
  final pid = ref.watch(partnerIdProvider);
  final lastSeen = ref.watch(partnerProfileProvider)?.lastSeen;
  if (pid == null) return Stream.value(const PresenceState());
  return ref
      .watch(presenceServiceProvider)
      .watchPartner(pid)
      .map((s) => PresenceState(online: s.online, typing: s.typing, lastSeen: lastSeen));
});

class PresenceService {
  PresenceService(this._db);

  final SupabaseClient _db;
  RealtimeChannel? _channel;
  String? _uid;
  String? _coupleId;
  PrivacySettings _privacy = const PrivacySettings();
  Timer? _typingTimer;
  Timer? _typingExpiry;
  bool _typing = false;
  DateTime? _typingSentAt;
  bool _subscribed = false;

  final _online = <String>{};
  String? _typingUid;
  final _changes = StreamController<void>.broadcast();

  Stream<PresenceState> watchPartner(String pid) async* {
    PresenceState current() => PresenceState(online: _online.contains(pid), typing: _typingUid == pid);
    yield current();
    await for (final _ in _changes.stream) {
      yield current();
    }
  }

  /// Uygulama ön plandayken çağrılır.
  Future<void> goOnline(String uid, String coupleId, PrivacySettings privacy) async {
    _privacy = privacy;
    if (_uid == uid && _coupleId == coupleId && _channel != null) {
      await _track();
      return;
    }
    await _leave();
    _uid = uid;
    _coupleId = coupleId;
    final channel = _db.channel(
      'couple:$coupleId',
      opts: RealtimeChannelConfig(private: true, key: uid, enabled: true),
    );
    _channel = channel;
    channel
        .onPresenceSync((_) => _syncPresence())
        .onBroadcast(
          event: 'typing',
          callback: (payload) {
            final from = payload['uid'] as String?;
            if (from == null || from == _uid) return;
            _typingExpiry?.cancel();
            if (payload['typing'] == true) {
              _typingUid = from;
              // Kapanış sinyali kaybolursa 8 sn sonra kendiliğinden düşer.
              _typingExpiry = Timer(const Duration(seconds: 8), () {
                _typingUid = null;
                _emit();
              });
            } else if (_typingUid == from) {
              _typingUid = null;
            }
            _emit();
          },
        )
        .subscribe((status, _) async {
          _subscribed = status == RealtimeSubscribeStatus.subscribed;
          if (_subscribed) await _track();
        });
    await _touchLastSeen();
  }

  void _syncPresence() {
    final channel = _channel;
    if (channel == null) return;
    _online
      ..clear()
      ..addAll(channel
          .presenceState()
          .where((s) => s.presences.any((p) => p.payload['visible'] == true))
          .map((s) => s.key));
    _emit();
  }

  void _emit() {
    if (!_changes.isClosed) _changes.add(null);
  }

  Future<void> _track() async {
    final channel = _channel;
    if (channel == null || !_subscribed) return;
    try {
      if (_privacy.showOnline) {
        await channel.track({'visible': true});
      } else {
        await channel.untrack();
      }
    } catch (_) {}
  }

  /// Son görülme: gizlilik ayarı kapalıysa veritabanı tetikleyicisi paylaşmaz.
  Future<void> _touchLastSeen() async {
    final uid = _uid;
    if (uid == null) return;
    try {
      await _db.from('profiles').update({'last_seen': dbTs(DateTime.now())}).eq('id', uid);
    } catch (_) {}
  }

  Future<void> goOffline() async {
    _typingTimer?.cancel();
    if (_typing) setTyping(false);
    try {
      await _channel?.untrack();
    } catch (_) {}
    await _touchLastSeen();
  }

  /// Yazarken çağrılır; 4 sn yazılmazsa otomatik kapanır. Açık sinyal
  /// en fazla 3 sn'de bir yenilenir.
  void setTyping(bool typing) {
    final channel = _channel;
    if (channel == null || _uid == null) return;
    _typingTimer?.cancel();
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 4), () => setTyping(false));
    }
    final now = DateTime.now();
    final stale = _typingSentAt == null || now.difference(_typingSentAt!) > const Duration(seconds: 3);
    if (typing == _typing && (!typing || !stale)) return;
    _typing = typing;
    _typingSentAt = now;
    channel
        .sendBroadcastMessage(event: 'typing', payload: {'uid': _uid, 'typing': typing})
        .catchError((_) => ChannelResponse.error);
  }

  Future<void> _leave() async {
    final channel = _channel;
    _channel = null;
    _subscribed = false;
    _online.clear();
    _typingUid = null;
    if (channel != null) {
      try {
        await channel.untrack();
      } catch (_) {}
      await _db.removeChannel(channel);
    }
    _emit();
  }

  Future<void> signOut() async {
    await goOffline();
    await _leave();
    _uid = null;
    _coupleId = null;
  }

  void dispose() {
    _typingTimer?.cancel();
    _typingExpiry?.cancel();
    final channel = _channel;
    if (channel != null) _db.removeChannel(channel);
    _changes.close();
  }
}
