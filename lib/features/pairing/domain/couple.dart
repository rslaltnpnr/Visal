import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_x.dart';

/// couples/{coupleId}
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

  String partnerOf(String uid) =>
      members.firstWhere((m) => m != uid, orElse: () => '');

  /// Gün sayacı: ilişki başlangıcı yoksa eşleşme tarihi.
  DateTime? get togetherSince => relationshipStartDate ?? createdAt;

  /// Yıldönümü yoksa ilişki başlangıcı kullanılır.
  DateTime? get effectiveAnniversary => anniversaryDate ?? relationshipStartDate;

  factory Couple.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return Couple(
      id: doc.id,
      members: List<String>.from(d['members'] as List? ?? const []),
      relationshipStartDate: tsToDate(d['relationshipStartDate']),
      anniversaryDate: tsToDate(d['anniversaryDate']),
      theme: d['theme'] as String?,
      coverPhoto: d['coverPhoto'] as String?,
      createdAt: tsToDate(d['createdAt']),
    );
  }
}

/// couples/{coupleId}/profiles/{uid} — partnerin görebildiği profil kopyası.
/// users/{uid} yalnızca sahibine açık olduğundan partner bilgisi buradan okunur.
class MemberProfile {
  const MemberProfile({
    required this.uid,
    required this.name,
    this.photoUrl,
    this.birthday,
    this.moodVisible = true,
  });

  final String uid;
  final String name;
  final String? photoUrl;
  final DateTime? birthday;
  final bool moodVisible;

  String get firstName => name.trim().split(' ').first;

  factory MemberProfile.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return MemberProfile(
      uid: doc.id,
      name: d['name'] as String? ?? '',
      photoUrl: d['photoUrl'] as String?,
      birthday: tsToDate(d['birthday']),
      moodVisible: d['moodVisible'] as bool? ?? true,
    );
  }
}
