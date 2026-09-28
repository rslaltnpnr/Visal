import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/domain/user_settings.dart';
import '../session/session_providers.dart';
import 'firebase_providers.dart';

/// presence/{uid}: { online, lastSeen, typing, typingAt }
class PresenceState {
  const PresenceState({this.online = false, this.lastSeen, this.typing = false});

  final bool online;
  final DateTime? lastSeen;
  final bool typing;

  factory PresenceState.fromValue(Object? v) {
    if (v is! Map) return const PresenceState();
    final ls = v['lastSeen'];
    final typingAt = v['typingAt'];
    // 8 sn'den eski "yazıyor" sinyali geçersiz sayılır.
    final typingFresh = typingAt is int &&
        DateTime.now().millisecondsSinceEpoch - typingAt < 8000;
    return PresenceState(
      online: v['online'] == true,
      lastSeen: ls is int ? DateTime.fromMillisecondsSinceEpoch(ls) : null,
      typing: v['typing'] == true && typingFresh,
    );
  }
}

final presenceServiceProvider = Provider<PresenceService>((ref) {
  final service = PresenceService(ref.watch(realtimeDbProvider));
  ref.onDispose(service.dispose);
  return service;
});

final partnerPresenceProvider = StreamProvider<PresenceState>((ref) {
  final pid = ref.watch(partnerIdProvider);
  if (pid == null) return Stream.value(const PresenceState());
  return ref
      .watch(realtimeDbProvider)
      .ref('presence/$pid')
      .onValue
      .map((e) => PresenceState.fromValue(e.snapshot.value));
});

class PresenceService {
  PresenceService(this._db);

  final FirebaseDatabase _db;
  StreamSubscription<DatabaseEvent>? _connSub;
  String? _uid;
  PrivacySettings _privacy = const PrivacySettings();
  Timer? _typingTimer;
  bool _typing = false;

  DatabaseReference get _ref => _db.ref('presence/$_uid');

  /// Uygulama ön plandayken çağrılır.
  void goOnline(String uid, PrivacySettings privacy) {
    if (_uid == uid && _connSub != null) {
      _privacy = privacy;
      _writeOnline();
      return;
    }
    _connSub?.cancel();
    _uid = uid;
    _privacy = privacy;
    _connSub = _db.ref('.info/connected').onValue.listen((event) async {
      if (event.snapshot.value != true) return;
      await _ref.onDisconnect().update({
        'online': false,
        'typing': false,
        'lastSeen': _privacy.showLastSeen ? ServerValue.timestamp : null,
      });
      await _writeOnline();
    });
  }

  Future<void> _writeOnline() async {
    if (_uid == null) return;
    await _ref.update({
      'online': _privacy.showOnline,
      'lastSeen': _privacy.showLastSeen ? ServerValue.timestamp : null,
    });
  }

  Future<void> goOffline() async {
    if (_uid == null) return;
    _typingTimer?.cancel();
    await _ref.update({
      'online': false,
      'typing': false,
      'lastSeen': _privacy.showLastSeen ? ServerValue.timestamp : null,
    });
  }

  /// Yazarken çağrılır; 4 sn yazılmazsa otomatik kapanır.
  void setTyping(bool typing) {
    if (_uid == null) return;
    _typingTimer?.cancel();
    if (typing) {
      _typingTimer = Timer(const Duration(seconds: 4), () => setTyping(false));
    }
    if (typing == _typing && !typing) return;
    _typing = typing;
    _ref.update({
      'typing': typing,
      'typingAt': ServerValue.timestamp,
    });
  }

  Future<void> signOut() async {
    await goOffline();
    await _connSub?.cancel();
    _connSub = null;
    if (_uid != null) await _ref.onDisconnect().cancel();
    _uid = null;
  }

  void dispose() {
    _typingTimer?.cancel();
    _connSub?.cancel();
  }
}
