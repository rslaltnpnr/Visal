import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/services/media_service.dart';
import '../../../core/session/session_providers.dart';
import '../domain/message.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(
    ref.watch(firestoreProvider),
    requireCoupleId(ref),
    ref.watch(currentUidProvider)!,
  );
});

class ChatRepository {
  ChatRepository(this._db, this.coupleId, this.uid);

  final FirebaseFirestore _db;
  final String coupleId;
  final String uid;

  static const pageSize = 30;

  CollectionReference<Map<String, dynamic>> get _col => _db.coupleCol(coupleId, 'messages');

  String newId() => _col.doc().id;

  String mediaFolder(String messageId) => 'couples/$coupleId/chat/$messageId';

  // ---------- Okuma ----------

  /// En yeni [pageSize] mesaj (önce önbellek, sonra sunucu).
  Future<List<Message>> fetchLatest() async {
    final q = _col.orderBy('createdAt', descending: true).limit(pageSize);
    QuerySnapshot<Map<String, dynamic>> snap;
    try {
      snap = await q.get();
    } on FirebaseException {
      snap = await q.get(const GetOptions(source: Source.cache));
    }
    return snap.docs.map(Message.fromDoc).toList();
  }

  /// [anchor] ve sonrasındaki tüm mesajlar (canlı). anchor null ise tümü.
  Stream<List<Message>> watchFrom(DateTime? anchor) {
    Query<Map<String, dynamic>> q = _col.orderBy('createdAt', descending: true);
    if (anchor != null) {
      q = q.where('createdAt', isGreaterThanOrEqualTo: Timestamp.fromDate(anchor));
    }
    return q
        .snapshots(includeMetadataChanges: true)
        .map((s) => s.docs.map(Message.fromDoc).toList());
  }

  /// [before] öncesindeki bir sayfa (canlı: tepki/düzenleme güncellenir).
  Stream<List<Message>> watchPage(DateTime before) => _col
      .where('createdAt', isLessThan: Timestamp.fromDate(before))
      .orderBy('createdAt', descending: true)
      .limit(pageSize)
      .snapshots()
      .map((s) => s.docs.map(Message.fromDoc).toList());

  Stream<Message?> watchPinned() => _col
      .where('pinned', isEqualTo: true)
      .orderBy('pinnedAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : Message.fromDoc(s.docs.first));

  /// Sekme rozeti ve ana ekran için son mesajlar.
  Stream<List<Message>> watchRecent({int limit = 30}) => _col
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(Message.fromDoc).toList());

  /// Hızlı sevgi animasyonu için son "love" mesajı.
  Stream<Message?> watchLatestLove() => _col
      .where('type', isEqualTo: MessageType.love.name)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : Message.fromDoc(s.docs.first));

  // ---------- Yazma ----------

  Map<String, dynamic> _base(MessageType type) => {
        'senderId': uid,
        'type': type.name,
        'createdAt': FieldValue.serverTimestamp(),
        'clientTime': Timestamp.now(),
        'seenBy': [uid],
        'deletedFor': <String>[],
        'reactions': <String, String>{},
        'pinned': false,
      };

  Future<void> sendText(String text, {ReplyRef? replyTo}) {
    final doc = _col.doc();
    return doc.set({
      ..._base(MessageType.text),
      'text': text.trim(),
      if (replyTo != null) 'replyTo': replyTo.toMap(),
    });
  }

  Future<void> sendLove(LoveKind kind) => _col.doc().set({
        ..._base(MessageType.love),
        'text': kind.text,
        'loveKind': kind.name,
      });

  Future<void> sendMedia({
    required String messageId,
    required MessageType type,
    required UploadedMedia media,
    String? caption,
    ReplyRef? replyTo,
  }) =>
      _col.doc(messageId).set({
        ..._base(type),
        'mediaUrl': media.url,
        'media': media.toMap(),
        if (caption != null && caption.trim().isNotEmpty) 'text': caption.trim(),
        if (replyTo != null) 'replyTo': replyTo.toMap(),
      });

  Future<void> sendGif(String url, {int? width, int? height, ReplyRef? replyTo}) => _col.doc().set({
        ..._base(MessageType.gif),
        'mediaUrl': url,
        'media': {
          'url': url,
          'path': '',
          'type': MediaKind.image.name,
          'width': ?width,
          'height': ?height,
          'mime': 'image/gif',
        },
        if (replyTo != null) 'replyTo': replyTo.toMap(),
      });

  Future<void> edit(String id, String text) => _col.doc(id).update({
        'text': text.trim(),
        'editedAt': FieldValue.serverTimestamp(),
      });

  Future<void> deleteForMe(String id) => _col.doc(id).update({
        'deletedFor': FieldValue.arrayUnion([uid]),
      });

  /// Herkesten sil: içerik kaldırılır, medya dosyası Cloud Function ile silinir.
  Future<void> deleteForEveryone(String id) => _col.doc(id).update({
        'deletedForAll': true,
        'text': null,
        'mediaUrl': null,
        'media': null,
        'replyTo': null,
        'pinned': false,
      });

  Future<void> react(String id, String? emoji) => _col.doc(id).update({
        'reactions.$uid': emoji ?? FieldValue.delete(),
      });

  Future<void> setPinned(String id, bool pinned) => _col.doc(id).update({
        'pinned': pinned,
        'pinnedAt': pinned ? FieldValue.serverTimestamp() : null,
      });

  Future<void> markSeen(Iterable<String> ids) async {
    final list = ids.toList();
    for (var i = 0; i < list.length; i += 400) {
      final batch = _db.batch();
      for (final id in list.skip(i).take(400)) {
        batch.update(_col.doc(id), {
          'seenBy': FieldValue.arrayUnion([uid]),
        });
      }
      await batch.commit();
    }
  }

  /// Okunmamış rozeti için yalnızca bana ait (users/{uid}) son okuma zamanı.
  Future<void> setLastRead() => _db.userDoc(uid).update({
        'chatLastReadAt': FieldValue.serverTimestamp(),
      });
}
