import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/services/media_service.dart';
import '../../../core/session/session_providers.dart';
import '../domain/capsule.dart';

final capsulesRepositoryProvider = Provider<CapsulesRepository>((ref) => CapsulesRepository(
      ref.watch(firestoreProvider),
      ref.watch(mediaServiceProvider),
      requireCoupleId(ref),
      ref.watch(currentUidProvider)!,
    ));

class CapsulesRepository {
  CapsulesRepository(this._db, this._media, this.coupleId, this.uid);

  final FirebaseFirestore _db;
  final MediaService _media;
  final String coupleId;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col => _db.coupleCol(coupleId, 'capsules');

  Stream<List<Capsule>> watchAll() => _col
      .orderBy('openAt')
      .limit(100)
      .snapshots()
      .map((s) => s.docs.map(Capsule.fromDoc).toList());

  Stream<Capsule?> watchOne(String id) =>
      _col.doc(id).snapshots().map((s) => s.exists ? Capsule.fromDoc(s) : null);

  /// Açılış tarihi gelmeden alıcı için kurallar okumayı reddeder.
  Future<CapsuleContent?> fetchContent(String id) async {
    final snap = await _col.doc(id).collection('content').doc('main').get();
    return snap.exists ? CapsuleContent.fromDoc(snap) : null;
  }

  Future<String> mediaUrl(String path) => _media.downloadUrl(path);

  /// "Kapsülü Kilitle": medya özel yola yüklenir, ardından üst veri ve içerik
  /// tek bir toplu yazma ile oluşturulur. Oluşturulduktan sonra değiştirilemez.
  Future<void> lock({
    required String recipientId,
    required DateTime openAt,
    required String title,
    required String message,
    required List<PickedMedia> media,
    void Function(double)? onProgress,
  }) async {
    final doc = _col.doc();
    final refs = <CapsuleMediaRef>[];
    for (var i = 0; i < media.length; i++) {
      final path = await _media.uploadPrivate(
        media[i],
        folder: 'couples/$coupleId/capsules/${doc.id}',
        onProgress: (p) => onProgress?.call((i + p) / media.length),
      );
      refs.add(CapsuleMediaRef(path: path, kind: media[i].kind));
    }
    final batch = _db.batch();
    batch.set(doc, {
      'createdBy': uid,
      'recipientId': recipientId,
      'openAt': Timestamp.fromDate(openAt),
      'title': title.trim(),
      'hasPhoto': refs.any((r) => r.kind == MediaKind.image),
      'hasVideo': refs.any((r) => r.kind == MediaKind.video),
      'hasAudio': refs.any((r) => r.kind == MediaKind.audio),
      'notified': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.set(doc.collection('content').doc('main'), {
      'message': message.trim(),
      'media': refs.map((r) => r.toMap()).toList(),
    });
    await batch.commit();
  }

  Future<void> delete(String id) => _col.doc(id).delete();
}

final capsulesProvider = StreamProvider.autoDispose<List<Capsule>>(
  (ref) => ref.watch(capsulesRepositoryProvider).watchAll(),
);

final capsuleProvider = StreamProvider.autoDispose.family<Capsule?, String>(
  (ref, id) => ref.watch(capsulesRepositoryProvider).watchOne(id),
);
