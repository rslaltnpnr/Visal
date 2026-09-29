import '../../../core/utils/date_x.dart';
import '../../settings/domain/user_settings.dart';

/// profiles tablosu (yalnızca sahibine açık).
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

  factory AppUser.fromRow(Map<String, dynamic> d) => AppUser(
        uid: d['id'] as String,
        name: d['name'] as String? ?? '',
        email: d['email'] as String? ?? '',
        photoUrl: d['photo_url'] as String?,
        coupleId: d['couple_id'] as String?,
        birthday: tsToDate(d['birthday']),
        createdAt: tsToDate(d['created_at']),
        lastSeen: tsToDate(d['last_seen']),
        settings: UserSettings.fromMap((d['settings'] as Map?)?.cast<String, dynamic>()),
        chatLastReadAt: tsToDate(d['chat_last_read_at']),
      );
}
