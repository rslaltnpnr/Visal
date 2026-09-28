import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/failure.dart';
import '../domain/pair_request.dart';

final pairingRepositoryProvider = Provider<PairingRepository>(
  (ref) => PairingRepository(
    ref.watch(firestoreProvider),
    ref.watch(functionsProvider),
  ),
);

/// Bana gelen, bekleyen eşleşme istekleri.
final incomingPairRequestsProvider = StreamProvider<List<PairRequest>>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(const []);
  return ref.watch(pairingRepositoryProvider).incoming(uid);
});

/// Benim gönderdiğim son istek.
final outgoingPairRequestProvider = StreamProvider<PairRequest?>((ref) {
  final uid = ref.watch(currentUidProvider);
  if (uid == null) return Stream.value(null);
  return ref.watch(pairingRepositoryProvider).outgoing(uid);
});

final pairRequestProvider =
    StreamProvider.family<PairRequest?, String>((ref, id) {
  return ref
      .watch(firestoreProvider)
      .collection('pairRequests')
      .doc(id)
      .snapshots()
      .map((s) => s.exists ? PairRequest.fromDoc(s) : null);
});

/// Eşleşme işlemleri Cloud Functions üzerinden yapılır: istemciler
/// `coupleId` alanını ve `couples` belgesinin üyelerini asla doğrudan yazamaz.
class PairingRepository {
  PairingRepository(this._db, this._functions);

  final FirebaseFirestore _db;
  final FirebaseFunctions _functions;

  static String normalizeCode(String raw) {
    var code = raw.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
    if (!code.startsWith('VISAL-')) {
      code = code.replaceFirst(RegExp(r'^VISAL'), '');
      code = 'VISAL-$code';
    }
    return code;
  }

  static bool isValidCode(String code) =>
      RegExp(r'^VISAL-[A-HJ-NP-Z2-9]{5}$').hasMatch(normalizeCode(code));

  Future<Invite> createInvite() async {
    try {
      final res = await _functions.httpsCallable('createInvite').call<Map<String, dynamic>>();
      final data = Map<String, dynamic>.from(res.data);
      return Invite(
        code: data['code'] as String,
        expiresAt: DateTime.fromMillisecondsSinceEpoch((data['expiresAt'] as num).toInt()),
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<String> requestPairing(String code) async {
    try {
      final res = await _functions
          .httpsCallable('requestPairing')
          .call<Map<String, dynamic>>({'code': normalizeCode(code)});
      return Map<String, dynamic>.from(res.data)['requestId'] as String;
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> respond(String requestId, {required bool accept}) async {
    try {
      await _functions
          .httpsCallable('respondPairing')
          .call<void>({'requestId': requestId, 'accept': accept});
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> cancelRequest(String requestId) async {
    try {
      await _functions.httpsCallable('cancelPairing').call<void>({'requestId': requestId});
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> unpair() async {
    try {
      await _functions.httpsCallable('unpair').call<void>();
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Stream<List<PairRequest>> incoming(String uid) => _db
      .collection('pairRequests')
      .where('toUid', isEqualTo: uid)
      .where('status', isEqualTo: 'pending')
      .snapshots()
      .map((s) => s.docs.map(PairRequest.fromDoc).toList());

  Stream<PairRequest?> outgoing(String uid) => _db
      .collection('pairRequests')
      .where('fromUid', isEqualTo: uid)
      .orderBy('createdAt', descending: true)
      .limit(1)
      .snapshots()
      .map((s) => s.docs.isEmpty ? null : PairRequest.fromDoc(s.docs.first));
}
