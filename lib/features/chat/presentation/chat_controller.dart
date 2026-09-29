import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/media_service.dart';
import '../../../core/services/supabase_providers.dart';
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

/// En yeni mesajlar canlı dinlenir; kullanıcı eskiye kaydırdıkça pencere
/// [ChatRepository.pageSize] kadar büyür.
class ChatController extends Notifier<ChatState> {
  late ChatRepository _repo;
  StreamSubscription<List<Message>>? _sub;
  int _limit = ChatRepository.pageSize;

  @override
  ChatState build() {
    _repo = ref.watch(chatRepositoryProvider);
    ref.onDispose(() => _sub?.cancel());
    _listen();
    return const ChatState();
  }

  void _listen() {
    _sub?.cancel();
    final limit = _limit;
    _sub = _repo.watchLatest(limit).listen(
      (list) {
        final uid = _repo.uid;
        final visible = list.where((m) => !m.hiddenFor(uid)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
        state = state.copyWith(
          messages: visible,
          initialized: true,
          loadingMore: false,
          hasMore: list.length >= limit,
        );
      },
      onError: (Object e) => state = state.copyWith(error: AppFailure.from(e), initialized: true, loadingMore: false),
    );
  }

  Future<void> loadMore() async {
    if (state.loadingMore || !state.hasMore) return;
    state = state.copyWith(loadingMore: true);
    _limit += ChatRepository.pageSize;
    _listen();
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
  (ref) => ref.watch(chatRepositoryProvider).watchPinned(ref.watch(tableBusProvider)),
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
  return ref.watch(chatRepositoryProvider).watchLatest(20);
});
