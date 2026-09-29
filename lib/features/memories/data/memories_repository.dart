import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/media_service.dart';
import '../../../core/services/supabase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/utils/failure.dart';
import '../domain/memory.dart';

final memoriesRepositoryProvider = Provider<MemoriesRepository>((ref) => MemoriesRepository(
      ref.watch(supabaseProvider),
      ref.watch(tableBusProvider),
      ref.watch(mediaServiceProvider),
      requireCoupleId(ref),
      ref.watch(currentUidProvider)!,
    ));

class MemoriesRepository {
  MemoriesRepository(this._db, this._bus, this._media, this.coupleId, this.uid);

  final SupabaseClient _db;
  final TableBus _bus;
  final MediaService _media;
  final String coupleId;
  final String uid;

  SupabaseQueryBuilder get _memories => _db.from('memories');
  SupabaseQueryBuilder get _story => _db.from('timeline');

  String newId() => const Uuid().v4();
  String folder(String id) => '$coupleId/memories/$id';

  Stream<T> _watch<T>(String table, Future<T> Function() fetch) =>
      watchQuery(_db, _bus, table: table, column: 'couple_id', value: coupleId, fetch: fetch);

  /// Sayfalı canlı liste: [limit] kaydırdıkça artar.
  Stream<List<Memory>> watch(MemoryFilter filter, int limit) => _watch('memories', () async {
        var q = _memories.select().eq('couple_id', coupleId);
        q = switch (filter) {
          MemoryFilter.all => q,
          MemoryFilter.photos => q.eq('has_photo', true),
          MemoryFilter.videos => q.eq('has_video', true),
          MemoryFilter.special => q.eq('is_special', true),
          MemoryFilter.travel => q.eq('is_travel', true),
        };
        final rows = await q.order('date', ascending: false).order('created_at', ascending: false).limit(limit);
        return rows.map(Memory.fromRow).toList();
      });

  Stream<Memory?> watchOne(String id) => _watch('memories', () async {
        final row = await _memories.select().eq('id', id).maybeSingle();
        return row == null ? null : Memory.fromRow(row);
      });

  /// Bugün geçmişte: aynı gün-ay, önceki yıllar.
  Stream<List<Memory>> watchOnThisDay() {
    final now = DateTime.now();
    return _watch('memories', () async {
      final rows = await _memories
          .select()
          .eq('couple_id', coupleId)
          .eq('month_day', monthDayKey(now))
          .lt('date', dbDate(DateTime(now.year)))
          .order('date', ascending: false)
          .limit(10);
      return rows.map(Memory.fromRow).toList();
    });
  }

  Future<int> count() async {
    final res = await _memories.select('id').eq('couple_id', coupleId).count(CountOption.exact);
    return res.count;
  }

  /// Yeni dosyaları yükler ve satırı yazar.
  Future<void> save({
    required String id,
    required Memory memory,
    required List<PickedMedia> newMedia,
    required bool isNew,
    List<UploadedMedia> removed = const [],
    void Function(double progress)? onProgress,
  }) async {
    final uploaded = <UploadedMedia>[];
    try {
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
      final data = full.toRow();
      if (isNew) {
        await _memories.insert({...data, 'id': id, 'couple_id': coupleId, 'created_by': uid});
      } else {
        await _memories.update({...data, 'updated_at': dbTs(DateTime.now())}).eq('id', id);
      }
    } catch (e) {
      // Yazılamayan kaydın yüklenmiş dosyaları yetim kalmasın.
      if (uploaded.isNotEmpty) {
        await _media.deletePaths(_withThumbs(uploaded)).catchError((_) {});
      }
      throw AppFailure.from(e);
    }
    _bus.bump('memories');
    if (removed.isNotEmpty) {
      await _media.deletePaths(_withThumbs(removed)).catchError((_) {});
    }
  }

  Iterable<String> _withThumbs(Iterable<UploadedMedia> list) =>
      list.where((m) => m.path.isNotEmpty).expand((m) => [m.path, if (m.thumbUrl != null) _thumbPath(m.path)]);

  String _thumbPath(String path) {
    final dot = path.lastIndexOf('.');
    return '${dot < 0 ? path : path.substring(0, dot)}_thumb.jpg';
  }

  /// Satırı ve anıya ait tüm dosyaları siler.
  Future<void> delete(String id) async {
    try {
      await _memories.delete().eq('id', id);
    } catch (e) {
      throw AppFailure.from(e);
    }
    _bus.bump('memories');
    await _media.deleteFolder(folder(id)).catchError((_) {});
  }

  // ---------- Bizim Hikâyemiz ----------

  Stream<List<StoryEvent>> watchStory() => _watch('timeline', () async {
        final rows = await _story.select().eq('couple_id', coupleId).order('date');
        return rows.map(StoryEvent.fromRow).toList();
      });

  Future<void> saveStory(StoryEvent event, {PickedMedia? photo}) async {
    final isNew = event.id.isEmpty;
    final id = isNew ? newId() : event.id;
    try {
      var data = event.toRow();
      String? oldPath;
      if (photo != null) {
        oldPath = event.photoPath;
        final up = await _media.upload(photo, folder: '$coupleId/timeline/$id');
        data = {...data, 'photo_url': up.url, 'photo_path': up.path};
      }
      if (isNew) {
        await _story.insert({...data, 'id': id, 'couple_id': coupleId, 'created_by': uid});
      } else {
        await _story.update({...data, 'updated_at': dbTs(DateTime.now())}).eq('id', id);
      }
      if (oldPath != null && oldPath.isNotEmpty) {
        await _media.deletePaths([oldPath, _thumbPath(oldPath)]).catchError((_) {});
      }
    } catch (e) {
      throw AppFailure.from(e);
    }
    _bus.bump('timeline');
  }

  Future<void> deleteStory(String id) async {
    try {
      await _story.delete().eq('id', id);
    } catch (e) {
      throw AppFailure.from(e);
    }
    _bus.bump('timeline');
    await _media.deleteFolder('$coupleId/timeline/$id').catchError((_) {});
  }
}

final memoryCountProvider = FutureProvider.autoDispose<int>((ref) {
  ref.watch(coupleIdProvider);
  final bus = ref.watch(tableBusProvider);
  final sub = bus.changes.where((t) => t == 'memories').listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
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
