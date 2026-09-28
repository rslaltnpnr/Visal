import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/media_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/failure.dart';
import '../data/chat_repository.dart';
import '../domain/message.dart';

class ChatState {
  const ChatState({
    this.messages = const [],
    this.initialized = false,
    this.loadingMore = false,
    this.hasMore = true,
    this.error,
  });

  /// En yeni başta (reverse ListView için).
  final List<Message> messages;
  final bool initialized;
  final bool loadingMore;
  final bool hasMore;
  final Object? error;

  ChatState copyWith({
    List<Message>? messages,
    bool? initialized,
    bool? loadingMore,
    bool? hasMore,
    Object? error,
  }) =>
      ChatState(
        messages: messages ?? this.messages,
        initialized: initialized ?? this.initialized,
        loadingMore: loadingMore ?? this.loadingMore,
        hasMore: hasMore ?? this.hasMore,
        error: error,
      );
}

/// Sabit sınırlı sayfalar: [anchor] ve sonrası tek canlı sorgu; daha eskiler
/// 30'luk canlı sayfalar. Sınırlar değişmediği için boşluk/tekrar oluşmaz ve
/// sohbetin tamamı asla tek seferde indirilmez.
class ChatController extends Notifier<ChatState> {
  late ChatRepository _repo;
  final _subs = <StreamSubscription<List<Message>>>[];
  final _sources = <int, List<Message>>{};
  DateTime? _oldestBoundary;

  @override
  ChatState build() {
    _repo = ref.watch(chatRepositoryProvider);
    ref.onDispose(() {
      for (final s in _subs) {
        s.cancel();
      }
      _subs.clear();
      _sources.clear();
    });
    Future.microtask(_init);
    return const ChatState();
  }

  Future<void> _init() async {
    try {
      final latest = await _repo.fetchLatest();
      final full = latest.length >= ChatRepository.pageSize;
      final anchor = full ? latest.last.createdAt : null;
      _oldestBoundary = anchor;
      _listen(0, _repo.watchFrom(anchor));
      state = state.copyWith(hasMore: full, initialized: true);
    } catch (e) {
      state = state.copyWith(error: AppFailure.from(e), initialized: true);
    }
  }

  void _listen(int key, Stream<List<Message>> stream) {
    _subs.add(stream.listen(
      (list) {
        _sources[key] = list;
        _emit();
      },
      onError: (Object e) => state = state.copyWith(error: e),
    ));
  }

  void _emit() {
    final uid = _repo.uid;
    final map = <String, Message>{};
    for (final list in _sources.values) {
      for (final m in list) {
        map[m.id] = m;
      }
    }
    final merged = map.values.where((m) => !m.hiddenFor(uid)).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    state = state.copyWith(messages: merged, initialized: true);
  }

  Future<void> loadMore() async {
    final boundary = _oldestBoundary;
    if (state.loadingMore || !state.hasMore || boundary == null) return;
    state = state.copyWith(loadingMore: true);
    final key = _sources.length;
    final completer = Completer<List<Message>>();
    _subs.add(_repo.watchPage(boundary).listen(
      (list) {
        _sources[key] = list;
        if (!completer.isCompleted) completer.complete(list);
        _emit();
      },
      onError: (Object e) {
        if (!completer.isCompleted) completer.completeError(e);
      },
    ));
    try {
      final page = await completer.future;
      if (page.isNotEmpty) _oldestBoundary = page.last.createdAt;
      state = state.copyWith(
        loadingMore: false,
        hasMore: page.length >= ChatRepository.pageSize,
      );
    } catch (e) {
      state = state.copyWith(loadingMore: false, error: e);
    }
  }
}

final chatControllerProvider = NotifierProvider.autoDispose<ChatController, ChatState>(
  ChatController.new,
);

// ---------- Gönderim kuyruğu (medya yüklemeleri) ----------

class OutgoingUpload {
  const OutgoingUpload({
    required this.localId,
    required this.media,
    required this.type,
    this.progress = 0,
    this.error,
  });

  final String localId;
  final PickedMedia media;
  final MessageType type;
  final double progress;
  final String? error;

  OutgoingUpload copyWith({double? progress, String? error}) => OutgoingUpload(
        localId: localId,
        media: media,
        type: type,
        progress: progress ?? this.progress,
        error: error,
      );
}

class ChatOutbox extends Notifier<List<OutgoingUpload>> {
  @override
  List<OutgoingUpload> build() {
    ref.watch(coupleIdProvider);
    return const [];
  }

  Future<void> send(PickedMedia media, MessageType type, {String? caption, ReplyRef? replyTo}) async {
    final repo = ref.read(chatRepositoryProvider);
    final service = ref.read(mediaServiceProvider);
    final messageId = repo.newId();
    final item = OutgoingUpload(localId: const Uuid().v4(), media: media, type: type);
    state = [...state, item];
    try {
      final uploaded = await service.upload(
        media,
        folder: repo.mediaFolder(messageId),
        onProgress: (p) => _update(item.localId, (u) => u.copyWith(progress: p)),
      );
      await repo.sendMedia(
        messageId: messageId,
        type: type,
        media: uploaded,
        caption: caption,
        replyTo: replyTo,
      );
      state = state.where((u) => u.localId != item.localId).toList();
    } catch (e) {
      _update(item.localId, (u) => u.copyWith(error: AppFailure.from(e).message));
    }
  }

  void retry(OutgoingUpload item) {
    dismiss(item);
    send(item.media, item.type);
  }

  void dismiss(OutgoingUpload item) =>
      state = state.where((u) => u.localId != item.localId).toList();

  void _update(String id, OutgoingUpload Function(OutgoingUpload) f) =>
      state = [for (final u in state) u.localId == id ? f(u) : u];
}

final chatOutboxProvider =
    NotifierProvider<ChatOutbox, List<OutgoingUpload>>(ChatOutbox.new);

/// Sabitlenmiş mesaj.
final pinnedMessageProvider = StreamProvider.autoDispose<Message?>(
  (ref) => ref.watch(chatRepositoryProvider).watchPinned(),
);

/// Okunmamış mesaj sayısı (alt menü rozeti).
final unreadCountProvider = Provider<int>((ref) {
  final recent = ref.watch(recentMessagesProvider).value ?? const [];
  final uid = ref.watch(currentUidProvider);
  final lastRead = ref.watch(currentUserProvider).value?.chatLastReadAt;
  return recent
      .where((m) =>
          m.senderId != uid &&
          !m.hiddenFor(uid ?? '') &&
          (lastRead == null || m.createdAt.isAfter(lastRead)))
      .length;
});

final recentMessagesProvider = StreamProvider<List<Message>>((ref) {
  if (ref.watch(coupleIdProvider) == null) return Stream.value(const []);
  return ref.watch(chatRepositoryProvider).watchRecent(limit: 20);
});
