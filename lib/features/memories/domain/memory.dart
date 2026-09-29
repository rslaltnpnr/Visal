import '../../../core/services/media_service.dart';
import '../../../core/services/supabase_providers.dart';
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

  Map<String, dynamic> toRow() => {
        'title': title,
        'description': description,
        'date': dbDate(date),
        'media': media.map((m) => m.toMap()).toList(),
        'location': location,
        'emoji': emoji,
        'music_url': musicUrl,
        'is_special': isSpecial,
        'is_travel': isTravel,
        'has_photo': hasPhoto,
        'has_video': hasVideo,
      };

  factory Memory.fromRow(Map<String, dynamic> d) {
    return Memory(
      id: d['id'] as String,
      createdBy: d['created_by'] as String? ?? '',
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      date: tsToDate(d['date']) ?? DateTime.now(),
      media: ((d['media'] as List?) ?? const [])
          .map((m) => UploadedMedia.fromMap(Map<String, dynamic>.from(m as Map)))
          .toList(),
      location: d['location'] as String?,
      emoji: d['emoji'] as String?,
      musicUrl: d['music_url'] as String?,
      isSpecial: d['is_special'] as bool? ?? false,
      isTravel: d['is_travel'] as bool? ?? false,
      createdAt: tsToDate(d['created_at']),
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

  Map<String, dynamic> toRow() => {
        'type': type.name,
        'title': title,
        'date': dbDate(date),
        'description': description,
        'photo_url': photoUrl,
        'photo_path': photoPath,
      };

  factory StoryEvent.fromRow(Map<String, dynamic> d) {
    return StoryEvent(
      id: d['id'] as String,
      type: StoryType.values.firstWhere((t) => t.name == d['type'], orElse: () => StoryType.custom),
      title: d['title'] as String? ?? '',
      date: tsToDate(d['date']) ?? DateTime.now(),
      createdBy: d['created_by'] as String? ?? '',
      description: d['description'] as String? ?? '',
      photoUrl: d['photo_url'] as String?,
      photoPath: d['photo_path'] as String?,
    );
  }
}
