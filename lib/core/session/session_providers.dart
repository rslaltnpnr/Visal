import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/domain/app_user.dart';
import '../../features/pairing/domain/couple.dart';
import '../services/firebase_providers.dart';

/// Firebase Auth oturumu.
final authStateProvider = StreamProvider<User?>(
  (ref) => ref.watch(authRepositoryProvider).authStateChanges(),
);

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.uid,
);

/// users/{uid} canlı akışı.
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .userDoc(uid)
      .snapshots()
      .map((s) => s.exists ? AppUser.fromDoc(s) : null);
});

final coupleIdProvider = Provider<String?>(
  (ref) => ref.watch(currentUserProvider).value?.coupleId,
);

/// Eşleşmiş çiftin coupleId'si; eşleşme yoksa hata fırlatır.
/// Yalnızca eşleşme sonrası ekranlarda kullanılır.
String requireCoupleId(Ref ref) {
  final id = ref.watch(coupleIdProvider);
  if (id == null) throw StateError('Eşleşme bulunamadı');
  return id;
}

final coupleProvider = StreamProvider<Couple?>((ref) {
  final id = ref.watch(coupleIdProvider);
  if (id == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .coupleDoc(id)
      .snapshots()
      .map((s) => s.exists ? Couple.fromDoc(s) : null);
});

final partnerIdProvider = Provider<String?>((ref) {
  final uid = ref.watch(currentUidProvider);
  final couple = ref.watch(coupleProvider).value;
  if (uid == null || couple == null) return null;
  final p = couple.partnerOf(uid);
  return p.isEmpty ? null : p;
});

final memberProfileProvider =
    StreamProvider.family<MemberProfile?, String>((ref, uid) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value(null);
  return ref
      .watch(firestoreProvider)
      .coupleCol(coupleId, 'profiles')
      .doc(uid)
      .snapshots()
      .map((s) => s.exists ? MemberProfile.fromDoc(s) : null);
});

final partnerProfileProvider = Provider<MemberProfile?>((ref) {
  final pid = ref.watch(partnerIdProvider);
  if (pid == null) return null;
  return ref.watch(memberProfileProvider(pid)).value;
});

/// UI'da "Partnerin" yerine kullanılacak ad.
final partnerNameProvider = Provider<String>((ref) {
  final p = ref.watch(partnerProfileProvider);
  return (p?.firstName.isNotEmpty ?? false) ? p!.firstName : 'Partnerin';
});
