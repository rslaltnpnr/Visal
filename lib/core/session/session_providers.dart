import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/auth/domain/app_user.dart';
import '../../features/pairing/domain/couple.dart';
import '../services/supabase_providers.dart';

/// Supabase oturumu. İlk değer mevcut oturumdan gelir.
final authStateProvider = StreamProvider<User?>((ref) async* {
  final auth = ref.watch(supabaseProvider).auth;
  yield auth.currentUser;
  await for (final state in auth.onAuthStateChange) {
    yield state.session?.user;
  }
});

final currentUidProvider = Provider<String?>(
  (ref) => ref.watch(authStateProvider).value?.id,
);

/// profiles satırı (canlı).
final currentUserProvider = StreamProvider<AppUser?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref
      .watch(supabaseProvider)
      .from('profiles')
      .stream(primaryKey: ['id'])
      .eq('id', uid)
      .map((rows) => rows.isEmpty ? null : AppUser.fromRow(rows.first));
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
      .watch(supabaseProvider)
      .from('couples')
      .stream(primaryKey: ['id'])
      .eq('id', id)
      .map((rows) => rows.isEmpty ? null : Couple.fromRow(rows.first));
});

final partnerIdProvider = Provider<String?>((ref) {
  final uid = ref.watch(currentUidProvider);
  final couple = ref.watch(coupleProvider).value;
  if (uid == null || couple == null) return null;
  final p = couple.partnerOf(uid);
  return p.isEmpty ? null : p;
});

/// Çiftin iki üyesinin paylaşılan profil kopyaları.
final coupleMembersProvider = StreamProvider<List<MemberProfile>>((ref) {
  final coupleId = ref.watch(coupleIdProvider);
  if (coupleId == null) return Stream.value(const []);
  return ref
      .watch(supabaseProvider)
      .from('couple_members')
      .stream(primaryKey: ['couple_id', 'user_id'])
      .eq('couple_id', coupleId)
      .map((rows) => rows.map(MemberProfile.fromRow).toList());
});

final memberProfileProvider = Provider.family<MemberProfile?, String>((ref, uid) {
  final members = ref.watch(coupleMembersProvider).value ?? const [];
  return members.where((m) => m.uid == uid).firstOrNull;
});

final partnerProfileProvider = Provider<MemberProfile?>((ref) {
  final pid = ref.watch(partnerIdProvider);
  if (pid == null) return null;
  return ref.watch(memberProfileProvider(pid));
});

/// UI'da "Partnerin" yerine kullanılacak ad.
final partnerNameProvider = Provider<String>((ref) {
  final p = ref.watch(partnerProfileProvider);
  return (p?.firstName.isNotEmpty ?? false) ? p!.firstName : 'Partnerin';
});
