import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/services/media_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/date_x.dart';
import '../domain/memory.dart';

final memoriesRepositoryProvider = Provider<MemoriesRepository>((ref) => MemoriesRepository(
      ref.watch(firestoreProvider),
      ref.watch(mediaServiceProvider),
      requireCoupleId(ref),
      ref.watch(currentUidProvider)!,
    ));

class MemoriesRepository {
  MemoriesRepository(this._db, this._media, this.coupleId, this.uid);

  final FirebaseFirestore _db;
  final MediaService _media;
  final String coupleId;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _col => _db.coupleCol(coupleId, 'memories');
  CollectionReference<Map<String, dynamic>> get _story => _db.coupleCol(coupleId, 'timeline');

  String newId() => _col.doc().id;
  String folder(String id) => 'couples/$coupleId/memories/$id';

  Query<Map<String, dynamic>> _query(MemoryFilter filter) {
    Query<Map<String, dynamic>> q = _col;
    q = switch (filter) {
      MemoryFilter.all => q,
      MemoryFilter.photos => q.where('hasPhoto', isEqualTo: true),
      MemoryFilter.videos => q.where('hasVideo', isEqualTo: true),
      MemoryFilter.special => q.where('isSpecial', isEqualTo: true),
      MemoryFilter.travel => q.where('isTravel', isEqualTo: true),
    };
    return q.orderBy('date', descending: true);
  }

  /// Sayfalı canlı liste: [limit] kaydırdıkça artar.
  Stream<List<Memory>> watch(MemoryFilter filter, int limit) =>
      _query(filter).limit(limit).snapshots().map((s) => s.docs.map(Memory.fromDoc).toList());

  Stream<Memory?> watchOne(String id) =>
      _col.doc(id).snapshots().map((s) => s.exists ? Memory.fromDoc(s) : null);

  /// Bugün geçmişte: aynı gün-ay, önceki yıllar.
  Stream<List<Memory>> watchOnThisDay() {
    final now = DateTime.now();
    return _col
        .where('monthDay', isEqualTo: monthDayKey(now))
        .orderBy('date', descending: true)
        .limit(10)
        .snapshots()
        .map((s) => s.docs.map(Memory.fromDoc).where((m) => m.date.year < now.year).toList());
  }

  Future<int> count() async => (await _col.count().get()).count ?? 0;

  /// Yeni dosyaları yükler ve belgeyi yazar.
  Future<void> save({
    required String id,
    required Memory memory,
    required List<PickedMedia> newMedia,
    required bool isNew,
    List<UploadedMedia> removed = const [],
    void Function(double progress)? onProgress,
  }) async {
    final uploaded = <UploadedMedia>[];
    for (var i = 0; i < newMedia.length; i++) {
      uploaded.add(await _media.upload(
        newMedia[i],
        folder: folder(id),
        onProgress: (p) => onProgress?.call((i + p) / newMedia.length),
      ));
    }
    final full = Memory(
      id: id,
      createdBy: memory.createdBy,
      title: memory.title,
      description: memory.description,
      date: memory.date,
      media: [...memory.media, ...uploaded],
      location: memory.location,
      emoji: memory.emoji,
      musicUrl: memory.musicUrl,
      isSpecial: memory.isSpecial,
      isTravel: memory.isTravel,
    );
    final data = full.toMap();
    if (isNew) {
      await _col.doc(id).set({...data, 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _col.doc(id).update({...data, 'updatedAt': FieldValue.serverTimestamp()});
    }
    if (removed.isNotEmpty) {
      await _media.deletePaths(removed.expand((m) => [m.path, if (m.thumbUrl != null) _thumbPath(m.path)]));
    }
  }

  String _thumbPath(String path) {
    final dot = path.lastIndexOf('.');
    return '${dot < 0 ? path : path.substring(0, dot)}_thumb.jpg';
  }

  /// Belgeyi siler; Storage dosyaları Cloud Function tarafından temizlenir.
  Future<void> delete(String id) => _col.doc(id).delete();

  // ---------- Bizim Hikâyemiz ----------

  Stream<List<StoryEvent>> watchStory() =>
      _story.orderBy('date').snapshots().map((s) => s.docs.map(StoryEvent.fromDoc).toList());

  Future<void> saveStory(StoryEvent event, {PickedMedia? photo}) async {
    final doc = event.id.isEmpty ? _story.doc() : _story.doc(event.id);
    var data = event.toMap();
    if (photo != null) {
      final up = await _media.upload(photo, folder: 'couples/$coupleId/timeline/${doc.id}');
      data = {...data, 'photoUrl': up.url, 'photoPath': up.path};
    }
    await doc.set({...data, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  Future<void> deleteStory(String id) => _story.doc(id).delete();
}

final memoryCountProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(coupleIdProvider);
  return ref.watch(memoriesRepositoryProvider).count();
});

final onThisDayProvider = StreamProvider.autoDispose<List<Memory>>(
  (ref) => ref.watch(memoriesRepositoryProvider).watchOnThisDay(),
);

final memoryProvider = StreamProvider.autoDispose.family<Memory?, String>(
  (ref, id) => ref.watch(memoriesRepositoryProvider).watchOne(id),
);

final storyProvider = StreamProvider.autoDispose<List<StoryEvent>>(
  (ref) => ref.watch(memoriesRepositoryProvider).watchStory(),
);
