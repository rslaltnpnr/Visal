import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/services/media_service.dart';
import '../../../core/utils/date_x.dart';

enum MemoryFilter {
  all('Tümü'),
  photos('Fotoğraflar'),
  videos('Videolar'),
  special('Özel Günler'),
  travel('Seyahat');

  const MemoryFilter(this.label);

  final String label;
}

/// couples/{coupleId}/memories/{memoryId}
class Memory {
  const Memory({
    required this.id,
    required this.createdBy,
    required this.title,
    required this.date,
    this.description = '',
    this.media = const [],
    this.location,
    this.emoji,
    this.musicUrl,
    this.isSpecial = false,
    this.isTravel = false,
    this.createdAt,
  });

  final String id;
  final String createdBy;
  final String title;
  final String description;
  final DateTime date;
  final List<UploadedMedia> media;
  final String? location;
  final String? emoji;
  final String? musicUrl;
  final bool isSpecial;
  final bool isTravel;
  final DateTime? createdAt;

  UploadedMedia? get cover => media.isEmpty ? null : media.first;
  bool get hasPhoto => media.any((m) => m.kind == MediaKind.image);
  bool get hasVideo => media.any((m) => m.kind == MediaKind.video);

  String? get coverUrl {
    final c = cover;
    if (c == null) return null;
    return c.kind == MediaKind.video ? c.thumbUrl : c.url;
  }

  Map<String, dynamic> toMap() => {
        'createdBy': createdBy,
        'title': title,
        'description': description,
        'date': Timestamp.fromDate(date),
        'monthDay': monthDayKey(date),
        'year': date.year,
        'media': media.map((m) => m.toMap()).toList(),
        'location': location,
        'emoji': emoji,
        'musicUrl': musicUrl,
        'isSpecial': isSpecial,
        'isTravel': isTravel,
        'hasPhoto': hasPhoto,
        'hasVideo': hasVideo,
      };

  factory Memory.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Memory(
      id: doc.id,
      createdBy: d['createdBy'] as String? ?? '',
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      date: tsToDate(d['date']) ?? DateTime.now(),
      media: ((d['media'] as List?) ?? const [])
          .map((m) => UploadedMedia.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      location: d['location'] as String?,
      emoji: d['emoji'] as String?,
      musicUrl: d['musicUrl'] as String?,
      isSpecial: d['isSpecial'] as bool? ?? false,
      isTravel: d['isTravel'] as bool? ?? false,
      createdAt: tsToDate(d['createdAt']),
    );
  }
}

enum StoryType {
  firstMessage('İlk mesaj', '💬'),
  firstDate('İlk buluşma', '🌹'),
  engagement('Nişan', '💍'),
  marriage('Evlilik', '💒'),
  firstTrip('İlk tatil', '✈️'),
  custom('Özel an', '✨');

  const StoryType(this.label, this.emoji);

  final String label;
  final String emoji;
}

/// couples/{coupleId}/timeline/{id} — "Bizim Hikâyemiz"
class StoryEvent {
  const StoryEvent({
    required this.id,
    required this.type,
    required this.title,
    required this.date,
    required this.createdBy,
    this.description = '',
    this.photoUrl,
    this.photoPath,
  });

  final String id;
  final StoryType type;
  final String title;
  final DateTime date;
  final String createdBy;
  final String description;
  final String? photoUrl;
  final String? photoPath;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'title': title,
        'date': Timestamp.fromDate(date),
        'createdBy': createdBy,
        'description': description,
        'photoUrl': photoUrl,
        'photoPath': photoPath,
      };

  factory StoryEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return StoryEvent(
      id: doc.id,
      type: StoryType.values.firstWhere((t) => t.name == d['type'], orElse: () => StoryType.custom),
      title: d['title'] as String? ?? '',
      date: tsToDate(d['date']) ?? DateTime.now(),
      createdBy: d['createdBy'] as String? ?? '',
      description: d['description'] as String? ?? '',
      photoUrl: d['photoUrl'] as String?,
      photoPath: d['photoPath'] as String?,
    );
  }
}
