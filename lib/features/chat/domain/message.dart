import '../../../core/services/media_service.dart';
import '../../../core/utils/date_x.dart';

enum MessageType { text, image, video, voice, file, gif, love }

/// Hızlı sevgi mesajları.
enum LoveKind {
  love('❤️', 'Seni seviyorum'),
  miss('🥺', 'Özledim'),
  home('🏠', 'Eve geliyorum'),
  coffee('☕', 'Kahve?'),
  call('📞', 'Müsait misin?'),
  kiss('😘', 'Öpücük');

  const LoveKind(this.emoji, this.label);

  final String emoji;
  final String label;

  String get text => '$emoji $label';
}

class ReplyRef {
  const ReplyRef({required this.id, required this.senderId, required this.preview, required this.type});

  final String id;
  final String senderId;
  final String preview;
  final MessageType type;

  Map<String, dynamic> toMap() => {
        'id': id,
        'senderId': senderId,
        'text': preview,
        'type': type.name,
      };

  factory ReplyRef.fromMap(Map<String, dynamic> m) => ReplyRef(
        id: m['id'] as String? ?? '',
        senderId: m['senderId'] as String? ?? '',
        preview: m['text'] as String? ?? '',
        type: MessageType.values.firstWhere((t) => t.name == m['type'], orElse: () => MessageType.text),
      );
}

/// couples/{coupleId}/messages/{messageId}
class Message {
  const Message({
    required this.id,
    required this.senderId,
    required this.type,
    required this.createdAt,
    this.text,
    this.mediaUrl,
    this.media,
    this.replyTo,
    this.reactions = const {},
    this.editedAt,
    this.seenBy = const [],
    this.deletedFor = const [],
    this.deletedForAll = false,
    this.pinned = false,
    this.loveKind,
    this.pending = false,
  });

  final String id;
  final String senderId;
  final MessageType type;
  final String? text;
  final String? mediaUrl;
  final UploadedMedia? media;
  final ReplyRef? replyTo;

  /// uid -> emoji
  final Map<String, String> reactions;
  final DateTime createdAt;
  final DateTime? editedAt;
  final List<String> seenBy;
  final List<String> deletedFor;
  final bool deletedForAll;
  final bool pinned;
  final LoveKind? loveKind;

  /// Sunucuya henüz yazılmadı (çevrimdışı / gönderiliyor).
  final bool pending;

  bool isMine(String uid) => senderId == uid;
  bool seenByUser(String uid) => seenBy.contains(uid);
  bool hiddenFor(String uid) => deletedFor.contains(uid);

  String get preview => switch (type) {
        _ when deletedForAll => 'Bu mesaj silindi',
        MessageType.text || MessageType.love => text ?? '',
        MessageType.image => '📷 Fotoğraf',
        MessageType.video => '🎬 Video',
        MessageType.voice => '🎤 Sesli mesaj',
        MessageType.file => '📎 ${media?.name ?? 'Dosya'}',
        MessageType.gif => 'GIF',
      };

  factory Message.fromRow(Map<String, dynamic> d) {
    final mediaMap = (d['media'] as Map?)?.cast<String, dynamic>();
    final replyMap = (d['reply_to'] as Map?)?.cast<String, dynamic>();
    return Message(
      id: d['id'] as String,
      senderId: d['sender_id'] as String? ?? '',
      type: MessageType.values.firstWhere((t) => t.name == d['type'], orElse: () => MessageType.text),
      text: d['text'] as String?,
      mediaUrl: d['media_url'] as String?,
      media: mediaMap == null ? null : UploadedMedia.fromMap(mediaMap),
      replyTo: replyMap == null ? null : ReplyRef.fromMap(replyMap),
      reactions: ((d['reactions'] as Map?) ?? const {}).map((k, v) => MapEntry('$k', '$v')),
      createdAt: tsToDate(d['created_at']) ?? DateTime.now(),
      editedAt: tsToDate(d['edited_at']),
      seenBy: List<String>.from(d['seen_by'] as List? ?? const []),
      deletedFor: List<String>.from(d['deleted_for'] as List? ?? const []),
      deletedForAll: d['deleted_for_all'] as bool? ?? false,
      pinned: d['pinned'] as bool? ?? false,
      loveKind: LoveKind.values.where((k) => k.name == d['love_kind']).firstOrNull,
    );
  }
}
