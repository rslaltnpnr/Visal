import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/media_service.dart';
import '../../../core/services/supabase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/utils/failure.dart';
import '../../settings/domain/user_settings.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(
      ref.watch(supabaseProvider),
      ref.watch(mediaServiceProvider),
      ref.watch(currentUidProvider),
      ref.watch(coupleIdProvider),
    ));

class ProfileRepository {
  ProfileRepository(this._db, this._media, this.uid, this.coupleId);

  final SupabaseClient _db;
  final MediaService _media;
  final String? uid;
  final String? coupleId;

  Future<void> _guard(Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Partnerin gördüğü kopya (couple_members) tetikleyiciyle eşitlenir.
  Future<void> updateProfile({String? name, DateTime? birthday, bool clearBirthday = false, String? photoUrl}) {
    final data = <String, dynamic>{
      'name': ?name?.trim(),
      if (birthday != null) 'birthday': dbDate(birthday),
      if (clearBirthday) 'birthday': null,
      'photo_url': ?photoUrl,
    };
    if (data.isEmpty) return Future.value();
    return _guard(() async {
      await _db.from('profiles').update(data).eq('id', uid!);
      if (name != null) await _db.auth.updateUser(UserAttributes(data: {'name': name.trim()}));
    });
  }

  Future<void> uploadAvatar(PickedMedia media) async {
    final old = await _db.from('profiles').select('photo_url').eq('id', uid!).maybeSingle();
    final up = await _media.upload(media, folder: '$uid/${const Uuid().v4()}', bucket: MediaService.avatarBucket);
    await updateProfile(photoUrl: up.url);
    // Eski avatar dosyaları temizlenir (yeni klasör hariç).
    if (old?['photo_url'] != null) {
      final folder = up.path.substring(0, up.path.lastIndexOf('/'));
      final items = await _db.storage.from(MediaService.avatarBucket).list(path: uid!).catchError((_) => <FileObject>[]);
      for (final item in items) {
        final path = '$uid/${item.name}';
        if (item.id == null && path != folder) {
          await _media.deleteFolder(path, bucket: MediaService.avatarBucket);
        }
      }
    }
  }

  /// settings jsonb'nin bir bölümünü değiştirir, diğerlerini korur.
  Future<void> _updateSettings(String key, Map<String, dynamic> value) => _guard(() async {
        final row = await _db.from('profiles').select('settings').eq('id', uid!).single();
        final settings = Map<String, dynamic>.from((row['settings'] as Map?) ?? const {});
        settings[key] = value;
        await _db.from('profiles').update({'settings': settings}).eq('id', uid!);
      });

  Future<void> updatePrivacy(PrivacySettings privacy) => _updateSettings('privacy', privacy.toMap());

  Future<void> updateNotifications(NotificationSettings n) => _updateSettings('notifications', n.toMap());

  // ---------- Çift ----------

  Future<void> updateCouple({
    DateTime? relationshipStartDate,
    DateTime? anniversaryDate,
    bool clearAnniversary = false,
  }) {
    final data = {
      if (relationshipStartDate != null) 'relationship_start_date': dbDate(relationshipStartDate),
      if (anniversaryDate != null) 'anniversary_date': dbDate(anniversaryDate),
      if (clearAnniversary) 'anniversary_date': null,
    };
    if (data.isEmpty) return Future.value();
    return _guard(() => _db.from('couples').update(data).eq('id', coupleId!));
  }

  Future<void> setCoverPhoto(PickedMedia media) async {
    final cid = coupleId!;
    final old = await _db.from('couples').select('cover_path').eq('id', cid).maybeSingle();
    final up = await _media.upload(media, folder: '$cid/cover/${const Uuid().v4()}');
    await _guard(() => _db.from('couples').update({'cover_photo': up.url, 'cover_path': up.path}).eq('id', cid));
    await _deleteCoverFile(old?['cover_path'] as String?);
  }

  Future<void> removeCoverPhoto() async {
    final cid = coupleId!;
    final old = await _db.from('couples').select('cover_path').eq('id', cid).maybeSingle();
    await _guard(() => _db.from('couples').update({'cover_photo': null, 'cover_path': null}).eq('id', cid));
    await _deleteCoverFile(old?['cover_path'] as String?);
  }

  Future<void> _deleteCoverFile(String? path) async {
    if (path == null || path.isEmpty) return;
    await _media.deleteFolder(path.substring(0, path.lastIndexOf('/')));
  }

  // ---------- Hesap ----------

  /// KVKK/GDPR: verilerin JSON kopyası (veritabanı fonksiyonu hazırlar).
  Future<File> exportData() async {
    try {
      final data = await _db.rpc<dynamic>('export_user_data');
      final json = const JsonEncoder.withIndent('  ').convert(data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/visal-verilerim-${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(json);
      return file;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Hesabı ve çift alanını kalıcı olarak siler. Dosyalar önce silinir;
  /// hesap silindikten sonra depolama kuralları erişime izin vermez.
  Future<void> deleteAccount() async {
    final cid = coupleId;
    if (cid != null) await _media.deleteFolder(cid);
    await _media.deleteFolder(uid!, bucket: MediaService.avatarBucket);
    await _guard(() => _db.rpc<void>('delete_account'));
    try {
      await _db.auth.signOut(scope: SignOutScope.local);
    } catch (_) {}
  }

  /// Mevcut şifre doğrulanır, ardından yenisi kaydedilir.
  Future<void> changePassword(String current, String next) async {
    final email = _db.auth.currentUser?.email;
    if (email == null) return;
    await _guard(() async {
      try {
        await _db.auth.signInWithPassword(email: email, password: current);
      } on AuthException {
        throw const AppFailure('Mevcut şifren hatalı.');
      }
      await _db.auth.updateUser(UserAttributes(password: next));
    });
  }
}

// ---------- Bildirim kutusu ----------

class InboxItem {
  const InboxItem({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    this.route,
    this.createdAt,
    this.read = false,
  });

  final String id;
  final String type;
  final String title;
  final String body;
  final String? route;
  final DateTime? createdAt;
  final bool read;

  factory InboxItem.fromRow(Map<String, dynamic> d) => InboxItem(
        id: d['id'] as String,
        type: d['type'] as String? ?? '',
        title: d['title'] as String? ?? '',
        body: d['body'] as String? ?? '',
        route: d['route'] as String?,
        createdAt: tsToDate(d['created_at']),
        read: d['read'] as bool? ?? false,
      );
}

/// Bildirim geçmişi: sunucu bildirim gönderirken yazar.
final inboxProvider = StreamProvider.autoDispose<List<InboxItem>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  final db = ref.watch(supabaseProvider);
  return watchQuery(
    db,
    ref.watch(tableBusProvider),
    table: 'inbox',
    column: 'user_id',
    value: uid,
    fetch: () async {
      final rows = await db.from('inbox').select().eq('user_id', uid).order('created_at', ascending: false).limit(50);
      return rows.map(InboxItem.fromRow).toList();
    },
  );
});

final unreadInboxProvider = Provider.autoDispose<bool>(
  (ref) => (ref.watch(inboxProvider).value ?? const []).any((i) => !i.read),
);

Future<void> markInboxRead(WidgetRef ref, List<InboxItem> items) async {
  final unread = items.where((i) => !i.read).map((i) => i.id).toList();
  if (unread.isEmpty) return;
  await ref.read(supabaseProvider).from('inbox').update({'read': true}).inFilter('id', unread);
  ref.read(tableBusProvider).bump('inbox');
}
