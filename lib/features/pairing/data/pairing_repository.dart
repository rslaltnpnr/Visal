import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/failure.dart';
import '../domain/pair_request.dart';

final pairingRepositoryProvider = Provider<PairingRepository>(
  (ref) => PairingRepository(ref.watch(supabaseProvider)),
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

final pairRequestProvider = StreamProvider.family<PairRequest?, String>((ref, id) {
  return ref
      .watch(supabaseProvider)
      .from('pair_requests')
      .stream(primaryKey: ['id'])
      .eq('id', id)
      .map((rows) => rows.isEmpty ? null : PairRequest.fromRow(rows.first));
});

/// Eşleşme işlemleri veritabanı fonksiyonlarıyla (RPC) yapılır: istemciler
/// `couple_id` alanını ve `couples.members` dizisini asla doğrudan yazamaz.
class PairingRepository {
  PairingRepository(this._db);

  final SupabaseClient _db;

  static String normalizeCode(String raw) {
    var code = raw.trim().toUpperCase().replaceAll(RegExp(r'\s'), '');
    if (!code.startsWith('VISAL-')) {
      code = code.replaceFirst(RegExp(r'^VISAL'), '');
      code = 'VISAL-$code';
    }
    return code;
  }

  static bool isValidCode(String code) => RegExp(r'^VISAL-[A-HJ-NP-Z2-9]{5}$').hasMatch(normalizeCode(code));

  Future<T> _rpc<T>(String fn, [Map<String, dynamic>? params]) async {
    try {
      return await _db.rpc<T>(fn, params: params);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<Invite> createInvite() async {
    final data = Map<String, dynamic>.from(await _rpc<Map<String, dynamic>>('create_invite'));
    return Invite(
      code: data['code'] as String,
      expiresAt: DateTime.fromMillisecondsSinceEpoch((data['expiresAt'] as num).toInt()),
    );
  }

  Future<String> requestPairing(String code) async {
    final data = await _rpc<Map<String, dynamic>>('request_pairing', {'p_code': normalizeCode(code)});
    return data['requestId'] as String;
  }

  Future<void> respond(String requestId, {required bool accept}) =>
      _rpc<dynamic>('respond_pairing', {'p_request_id': requestId, 'p_accept': accept});

  Future<void> cancelRequest(String requestId) => _rpc<dynamic>('cancel_pairing', {'p_request_id': requestId});

  Future<void> unpair() => _rpc<dynamic>('unpair');

  Stream<List<PairRequest>> incoming(String uid) => _db
      .from('pair_requests')
      .stream(primaryKey: ['id'])
      .eq('to_uid', uid)
      .map((rows) => rows
          .map(PairRequest.fromRow)
          .where((r) => r.status == PairRequestStatus.pending)
          .toList());

  Stream<PairRequest?> outgoing(String uid) => _db
      .from('pair_requests')
      .stream(primaryKey: ['id'])
      .eq('from_uid', uid)
      .order('created_at')
      .limit(1)
      .map((rows) => rows.isEmpty ? null : PairRequest.fromRow(rows.first));
}
