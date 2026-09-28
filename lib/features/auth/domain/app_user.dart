import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_x.dart';
import '../../settings/domain/user_settings.dart';

/// users/{uid}
class AppUser {
  const AppUser({
    required this.uid,
    required this.name,
    required this.email,
    this.photoUrl,
    this.coupleId,
    this.birthday,
    this.createdAt,
    this.lastSeen,
    this.settings = const UserSettings(),
    this.chatLastReadAt,
  });

  final String uid;
  final String name;
  final String email;
  final String? photoUrl;
  final String? coupleId;
  final DateTime? birthday;
  final DateTime? createdAt;
  final DateTime? lastSeen;
  final UserSettings settings;

  /// Sohbet okunmamış rozeti için son okuma zamanı (yalnızca kullanıcıya açık).
  final DateTime? chatLastReadAt;

  bool get isPaired => coupleId != null && coupleId!.isNotEmpty;

  String get firstName => name.trim().split(' ').first;

  factory AppUser.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return AppUser(
      uid: doc.id,
      name: d['name'] as String? ?? '',
      email: d['email'] as String? ?? '',
      photoUrl: d['photoUrl'] as String?,
      coupleId: d['coupleId'] as String?,
      birthday: tsToDate(d['birthday']),
      createdAt: tsToDate(d['createdAt']),
      lastSeen: tsToDate(d['lastSeen']),
      settings: UserSettings.fromMap(
        (d['settings'] as Map?)?.cast<String, dynamic>(),
      ),
      chatLastReadAt: tsToDate(d['chatLastReadAt']),
    );
  }
}
