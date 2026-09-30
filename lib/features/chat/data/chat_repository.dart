import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/media_service.dart';
import '../../../core/services/supabase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/failure.dart';
import '../domain/message.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(supabaseProvider),
    ref.watch(mediaServiceProvider),
    requireCoupleId(ref),
    ref.watch(currentUidProvider)!,
  );
});

class ChatRepository {
  ChatRepository(this._db, this._media, this.coupleId, this.uid);

  final SupabaseClient _db;
  final MediaService _media;
  final String coupleId;
  final String uid;

  static const pageSize = 40;

  SupabaseQueryBuilder get _table => _db.from('messages');

  String newId() => const Uuid().v4();

  String mediaFolder(String messageId) => '$coupleId/chat/$messageId';

  // ---------- Okuma ----------

  /// En yeni [limit] mesaj, canlı. Eski mesajlara kaydırdıkça limit artar;
  /// sohbetin tamamı asla tek seferde indirilmez.
  Stream<List<Message>> watchLatest(int limit) => _table
      .stream(primaryKey: ['id'])
      .eq('couple_id', coupleId)
      .order('created_at', ascending: false)
      .limit(limit)
      .map((rows) => rows.map(Message.fromRow).toList());

  Stream<Message?> watchPinned(TableBus bus) => watchQuery(
        _db,
        bus,
        table: 'messages',
        column: 'couple_id',
        value: coupleId,
        fetch: () async {
          final row = await _table
              .select()
              .eq('couple_id', coupleId)
              .eq('pinned', true)
              .order('pinned_at', ascending: false)
              .limit(1)
              .maybeSingle();
          return row == null ? null : Message.fromRow(row);
        },
      );

  // ---------- Yazma ----------

  Map<String, dynamic> _base(MessageType type, {String? id}) => {
        'id': ?id,
        'couple_id': coupleId,
        'sender_id': uid,
        'type': type.name,
        'seen_by': [uid],
      };

  Future<void> _insert(Map<String, dynamic> row) async {
    try {
      await _table.insert(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<T> _rpc<T>(String fn, Map<String, dynamic> params) async {
    try {
      return await _db.rpc<T>(fn, params: params);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> sendText(String text, {ReplyRef? replyTo}) => _insert({
        ..._base(MessageType.text),
        'text': text.trim(),
        if (replyTo != null) 'reply_to': replyTo.toMap(),
      });

  Future<void> sendLove(LoveKind kind) => _insert({
        ..._base(MessageType.love),
        'text': kind.text,
        'love_kind': kind.name,
      });

  Future<void> sendMedia({
    required String messageId,
    required MessageType type,
    required UploadedMedia media,
    String? caption,
    ReplyRef? replyTo,
  }) =>
      _insert({
        ..._base(type, id: messageId),
        'media_url': media.url,
        'media': media.toMap(),
        if (caption != null && caption.trim().isNotEmpty) 'text': caption.trim(),
        if (replyTo != null) 'reply_to': replyTo.toMap(),
      });

  Future<void> sendGif(String url, {int? width, int? height, ReplyRef? replyTo}) => _insert({
        ..._base(MessageType.gif),
        'media_url': url,
        'media': {
          'url': url,
          'path': '',
          'type': MediaKind.image.name,
          'width': ?width,
          'height': ?height,
          'mime': 'image/gif',
        },
        if (replyTo != null) 'reply_to': replyTo.toMap(),
      });

  Future<void> edit(String id, String text) => _rpc<void>('edit_message', {'p_id': id, 'p_text': text});

  Future<void> deleteForMe(String id) => _rpc<void>('delete_message_for_me', {'p_id': id});

  /// Herkesten sil: içerik kaldırılır, medya dosyası da silinir.
  Future<void> deleteForEveryone(String id) async {
    final path = await _rpc<String?>('delete_message_for_all', {'p_id': id});
    if (path != null && path.isNotEmpty) {
      final dot = path.lastIndexOf('.');
      final thumb = '${dot < 0 ? path : path.substring(0, dot)}_thumb.jpg';
      await _media.deletePaths([path, thumb]);
    }
  }

  Future<void> react(String id, String? emoji) =>
      _rpc<void>('react_message', {'p_id': id, 'p_emoji': emoji});

  Future<void> setPinned(String id, bool pinned) =>
      _rpc<void>('set_message_pinned', {'p_id': id, 'p_pinned': pinned});

  Future<void> markSeen(Iterable<String> ids) =>
      _rpc<void>('mark_messages_seen', {'p_ids': ids.toList()});

  /// Okunmamış rozeti için yalnızca bana ait son okuma zamanı.
  Future<void> setLastRead() =>
      _db.from('profiles').update({'chat_last_read_at': DateTime.now().toUtc().toIso8601String()}).eq('id', uid);
}
