import '../../../core/utils/date_x.dart';

enum PairRequestStatus { pending, accepted, rejected, cancelled, expired }

/// pair_requests tablosu — yalnızca sunucu fonksiyonları yazar.
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

  factory PairRequest.fromRow(Map<String, dynamic> d) => PairRequest(
        id: d['id'] as String,
        fromUid: d['from_uid'] as String? ?? '',
        fromName: d['from_name'] as String? ?? '',
        fromPhoto: d['from_photo'] as String?,
        toUid: d['to_uid'] as String? ?? '',
        toName: d['to_name'] as String? ?? '',
        status: PairRequestStatus.values.firstWhere(
          (s) => s.name == d['status'],
          orElse: () => PairRequestStatus.pending,
        ),
        createdAt: tsToDate(d['created_at']),
      );
}

class Invite {
  const Invite({required this.code, required this.expiresAt});

  final String code;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}
