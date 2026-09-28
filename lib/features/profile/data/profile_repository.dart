import 'dart:convert';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/services/media_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/failure.dart';
import '../../settings/domain/user_settings.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository(
      ref.watch(firestoreProvider),
      ref.watch(firebaseAuthProvider),
      ref.watch(functionsProvider),
      ref.watch(mediaServiceProvider),
      ref.watch(currentUidProvider),
      ref.watch(coupleIdProvider),
    ));

class ProfileRepository {
  ProfileRepository(this._db, this._auth, this._functions, this._media, this.uid, this.coupleId);

  final FirebaseFirestore _db;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final MediaService _media;
  final String? uid;
  final String? coupleId;

  DocumentReference<Map<String, dynamic>> get _user => _db.userDoc(uid!);

  DocumentReference<Map<String, dynamic>>? get _profile =>
      coupleId == null ? null : _db.coupleCol(coupleId!, 'profiles').doc(uid);

  /// users/{uid} ve partnerin gördüğü profil kopyasını birlikte günceller.
  Future<void> updateProfile({String? name, DateTime? birthday, bool clearBirthday = false, String? photoUrl}) async {
    final data = <String, dynamic>{
      'name': ?name?.trim(),
      if (birthday != null) 'birthday': Timestamp.fromDate(birthday),
      if (clearBirthday) 'birthday': null,
      'photoUrl': ?photoUrl,
    };
    if (data.isEmpty) return;
    final batch = _db.batch()..update(_user, data);
    final profile = _profile;
    if (profile != null) batch.set(profile, data, SetOptions(merge: true));
    await batch.commit();
    if (name != null) await _auth.currentUser?.updateDisplayName(name.trim());
  }

  Future<void> uploadAvatar(PickedMedia media) async {
    final up = await _media.upload(media, folder: 'users/$uid/avatar');
    await updateProfile(photoUrl: up.url);
  }

  Future<void> updatePrivacy(PrivacySettings privacy) async {
    final batch = _db.batch()..update(_user, {'settings.privacy': privacy.toMap()});
    final profile = _profile;
    if (profile != null) {
      batch.set(profile, {'moodVisible': privacy.moodVisible}, SetOptions(merge: true));
    }
    await batch.commit();
  }

  Future<void> updateNotifications(NotificationSettings n) =>
      _user.update({'settings.notifications': n.toMap()});

  // ---------- Çift ----------

  Future<void> updateCouple({
    DateTime? relationshipStartDate,
    DateTime? anniversaryDate,
    bool clearAnniversary = false,
  }) {
    return _db.coupleDoc(coupleId!).update({
      if (relationshipStartDate != null) 'relationshipStartDate': Timestamp.fromDate(relationshipStartDate),
      if (anniversaryDate != null) 'anniversaryDate': Timestamp.fromDate(anniversaryDate),
      if (clearAnniversary) 'anniversaryDate': null,
    });
  }

  Future<void> setCoverPhoto(PickedMedia media) async {
    final up = await _media.upload(media, folder: 'couples/$coupleId/cover');
    await _db.coupleDoc(coupleId!).update({'coverPhoto': up.url, 'coverPath': up.path});
  }

  Future<void> removeCoverPhoto() =>
      _db.coupleDoc(coupleId!).update({'coverPhoto': null, 'coverPath': null});

  // ---------- Hesap ----------

  /// KVKK/GDPR: verilerin JSON kopyası (Cloud Function hazırlar).
  Future<File> exportData() async {
    try {
      final res = await _functions
          .httpsCallable('exportUserData', options: HttpsCallableOptions(timeout: const Duration(minutes: 2)))
          .call<Map<String, dynamic>>();
      final json = const JsonEncoder.withIndent('  ').convert(res.data);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/visal-verilerim-${DateTime.now().millisecondsSinceEpoch}.json');
      await file.writeAsString(json);
      return file;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Hesabı ve çift alanını kalıcı olarak siler (Cloud Function).
  Future<void> deleteAccount() async {
    try {
      await _functions
          .httpsCallable('deleteAccount', options: HttpsCallableOptions(timeout: const Duration(minutes: 3)))
          .call<void>();
      await _auth.signOut();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> changePassword(String current, String next) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null) return;
    try {
      await user.reauthenticateWithCredential(
        EmailAuthProvider.credential(email: user.email!, password: current),
      );
      await user.updatePassword(next);
    } catch (e) {
      throw AppFailure.from(e);
    }
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

  factory InboxItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    final ts = d['createdAt'];
    return InboxItem(
      id: doc.id,
      type: d['type'] as String? ?? '',
      title: d['title'] as String? ?? '',
      body: d['body'] as String? ?? '',
      route: d['route'] as String?,
      createdAt: ts is Timestamp ? ts.toDate() : null,
      read: d['read'] as bool? ?? false,
    );
  }
}

/// users/{uid}/inbox — Cloud Functions bildirim gönderirken yazar.
final inboxProvider = StreamProvider.autoDispose<List<InboxItem>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref
      .watch(firestoreProvider)
      .userDoc(uid)
      .collection('inbox')
      .orderBy('createdAt', descending: true)
      .limit(50)
      .snapshots()
      .map((s) => s.docs.map(InboxItem.fromDoc).toList());
});

final unreadInboxProvider = Provider.autoDispose<bool>(
  (ref) => (ref.watch(inboxProvider).value ?? const []).any((i) => !i.read),
);

Future<void> markInboxRead(WidgetRef ref, List<InboxItem> items) async {
  final uid = ref.read(currentUidProvider);
  if (uid == null) return;
  final db = ref.read(firestoreProvider);
  final unread = items.where((i) => !i.read).toList();
  if (unread.isEmpty) return;
  final batch = db.batch();
  for (final i in unread) {
    batch.update(db.userDoc(uid).collection('inbox').doc(i.id), {'read': true});
  }
  await batch.commit();
}
