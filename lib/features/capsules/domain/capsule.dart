import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/media_service.dart';
import '../../../core/utils/date_x.dart';

/// couples/{coupleId}/capsules/{capsuleId} — herkese (çifte) açık üst veri.
/// İçerik `content/main` alt belgesindedir ve kurallar gereği açılma
/// tarihinden önce yalnızca oluşturan okuyabilir.
class Capsule {
  const Capsule({
    required this.id,
    required this.createdBy,
    required this.recipientId,
    required this.openAt,
    this.title = '',
    this.createdAt,
    this.hasPhoto = false,
    this.hasVideo = false,
    this.hasAudio = false,
  });

  final String id;
  final String createdBy;
  final String recipientId;
  final DateTime openAt;
  final String title;
  final DateTime? createdAt;
  final bool hasPhoto;
  final bool hasVideo;
  final bool hasAudio;

  bool get isOpen => !DateTime.now().isBefore(openAt);

  Duration get remaining => openAt.difference(DateTime.now());

  factory Capsule.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Capsule(
      id: doc.id,
      createdBy: d['createdBy'] as String? ?? '',
      recipientId: d['recipientId'] as String? ?? '',
      openAt: tsToDate(d['openAt']) ?? DateTime.now(),
      title: d['title'] as String? ?? '',
      createdAt: tsToDate(d['createdAt']),
      hasPhoto: d['hasPhoto'] as bool? ?? false,
      hasVideo: d['hasVideo'] as bool? ?? false,
      hasAudio: d['hasAudio'] as bool? ?? false,
    );
  }
}

class CapsuleMediaRef {
  const CapsuleMediaRef({required this.path, required this.kind});

  final String path;
  final MediaKind kind;

  Map<String, dynamic> toMap() => {'path': path, 'type': kind.name};

  factory CapsuleMediaRef.fromMap(Map<String, dynamic> m) => CapsuleMediaRef(
        path: m['path'] as String? ?? '',
        kind: MediaKind.values.firstWhere((k) => k.name == m['type'], orElse: () => MediaKind.file),
      );
}

class CapsuleContent {
  const CapsuleContent({required this.message, this.media = const []});

  final String message;
  final List<CapsuleMediaRef> media;

  factory CapsuleContent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CapsuleContent(
      message: d['message'] as String? ?? '',
      media: ((d['media'] as List?) ?? const [])
          .map((m) => CapsuleMediaRef.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
    );
  }
}
