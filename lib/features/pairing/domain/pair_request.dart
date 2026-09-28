import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/utils/date_x.dart';

enum PairRequestStatus { pending, accepted, rejected, cancelled, expired }

/// pairRequests/{id} — yalnızca Cloud Functions yazar.
class PairRequest {
  const PairRequest({
    required this.id,
    required this.fromUid,
    required this.fromName,
    required this.toUid,
    required this.toName,
    required this.status,
    this.fromPhoto,
    this.createdAt,
  });

  final String id;
  final String fromUid;
  final String fromName;
  final String? fromPhoto;
  final String toUid;
  final String toName;
  final PairRequestStatus status;
  final DateTime? createdAt;

  factory PairRequest.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PairRequest(
      id: doc.id,
      fromUid: d['fromUid'] as String? ?? '',
      fromName: d['fromName'] as String? ?? '',
      fromPhoto: d['fromPhoto'] as String?,
      toUid: d['toUid'] as String? ?? '',
      toName: d['toName'] as String? ?? '',
      status: PairRequestStatus.values.firstWhere(
        (s) => s.name == d['status'],
        orElse: () => PairRequestStatus.pending,
      ),
      createdAt: tsToDate(d['createdAt']),
    );
  }
}

class Invite {
  const Invite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
