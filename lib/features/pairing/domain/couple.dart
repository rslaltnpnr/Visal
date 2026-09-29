import '../../../core/utils/date_x.dart';

/// couples tablosu
class Couple {
  const Couple({
    required this.id,
    required this.members,
    this.relationshipStartDate,
    this.anniversaryDate,
    this.theme,
    this.coverPhoto,
    this.createdAt,
  });

  final String id;
  final List<String> members;
  final DateTime? relationshipStartDate;
  final DateTime? anniversaryDate;
  final String? theme;
  final String? coverPhoto;
  final DateTime? createdAt;

  String partnerOf(String uid) => members.firstWhere((m) => m != uid, orElse: () => '');

  /// Gün sayacı: ilişki başlangıcı yoksa eşleşme tarihi.
  DateTime? get togetherSince => relationshipStartDate ?? createdAt;

  /// Yıldönümü yoksa ilişki başlangıcı kullanılır.
  DateTime? get effectiveAnniversary => anniversaryDate ?? relationshipStartDate;

  factory Couple.fromRow(Map<String, dynamic> d) => Couple(
        id: d['id'] as String,
        members: List<String>.from(d['members'] as List? ?? const []),
        relationshipStartDate: tsToDate(d['relationship_start_date']),
        anniversaryDate: tsToDate(d['anniversary_date']),
        theme: d['theme'] as String?,
        coverPhoto: d['cover_photo'] as String?,
        createdAt: tsToDate(d['created_at']),
      );
}

/// couple_members tablosu — partnerin görebildiği profil kopyası.
class MemberProfile {
  const MemberProfile({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.birthday,
    this.moodVisible = true,
    this.lastSeen,
  });

  final String uid;
  final String name;
  final String? photoUrl;
  final DateTime? birthday;
  final bool moodVisible;
  final DateTime? lastSeen;

  String get firstName => name.trim().split(' ').first;

  factory MemberProfile.fromRow(Map<String, dynamic> d) => MemberProfile(
        uid: d['user_id'] as String,
        name: d['name'] as String? ?? '',
        photoUrl: d['photo_url'] as String?,
        birthday: tsToDate(d['birthday']),
        moodVisible: d['mood_visible'] as bool? ?? true,
        lastSeen: tsToDate(d['last_seen']),
      );
}
