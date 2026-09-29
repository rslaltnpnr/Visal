import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/media_service.dart';
import '../../../core/services/supabase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/failure.dart';
import '../domain/capsule.dart';

final capsulesRepositoryProvider = Provider<CapsulesRepository>((ref) => CapsulesRepository(
      ref.watch(supabaseProvider),
      ref.watch(tableBusProvider),
      ref.watch(mediaServiceProvider),
      requireCoupleId(ref),
      ref.watch(currentUidProvider)!,
    ));

class CapsulesRepository {
  CapsulesRepository(this._db, this._bus, this._media, this.coupleId, this.uid);

  final SupabaseClient _db;
  final TableBus _bus;
  final MediaService _media;
  final String coupleId;
  final String uid;

  SupabaseQueryBuilder get _capsules => _db.from('capsules');

  String _folder(String id) => '$coupleId/capsules/$id';

  Stream<T> _watch<T>(Future<T> Function() fetch) =>
      watchQuery(_db, _bus, table: 'capsules', column: 'couple_id', value: coupleId, fetch: fetch);

  Stream<List<Capsule>> watchAll() => _watch(() async {
        final rows = await _capsules.select().eq('couple_id', coupleId).order('open_at').limit(100);
        return rows.map(Capsule.fromRow).toList();
      });

  Stream<Capsule?> watchOne(String id) => _watch(() async {
        final row = await _capsules.select().eq('id', id).maybeSingle();
        return row == null ? null : Capsule.fromRow(row);
      });

  /// Açılış zamanı gelmeden alıcıya satır dönmez (RLS).
  Future<CapsuleContent?> fetchContent(String id) async {
    try {
      final row = await _db.from('capsule_contents').select().eq('capsule_id', id).maybeSingle();
      return row == null ? null : CapsuleContent.fromRow(row);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// Kısa ömürlü bağlantı; depolama kuralları açılış zamanını yeniden denetler.
  Future<String> mediaUrl(String path) async {
    try {
      return await _media.signedUrl(path);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  /// "Kapsülü Kilitle": medya özel yola yüklenir, ardından üst veri ve içerik
  /// yazılır. Oluşturulduktan sonra değiştirilemez.
  Future<void> lock({
    required String recipientId,
    required DateTime openAt,
    required String title,
    required String message,
    required List<PickedMedia> media,
    void Function(double)? onProgress,
  }) async {
    final id = const Uuid().v4();
    final refs = <CapsuleMediaRef>[];
    var created = false;
    try {
      for (var i = 0; i < media.length; i++) {
        final path = await _media.uploadPrivate(
          media[i],
          folder: _folder(id),
          onProgress: (p) => onProgress?.call((i + p) / media.length),
        );
        refs.add(CapsuleMediaRef(path: path, kind: media[i].kind));
      }
      await _capsules.insert({
        'id': id,
        'couple_id': coupleId,
        'created_by': uid,
        'recipient_id': recipientId,
        'open_at': dbTs(openAt),
        'title': title.trim(),
        'has_photo': refs.any((r) => r.kind == MediaKind.image),
        'has_video': refs.any((r) => r.kind == MediaKind.video),
        'has_audio': refs.any((r) => r.kind == MediaKind.audio),
      });
      created = true;
      await _db.from('capsule_contents').insert({
        'capsule_id': id,
        'message': message.trim(),
        'media': refs.map((r) => r.toMap()).toList(),
      });
    } catch (e) {
      if (refs.isNotEmpty) await _media.deletePaths(refs.map((r) => r.path));
      if (created) {
        try {
          await _capsules.delete().eq('id', id);
        } catch (_) {}
      }
      throw AppFailure.from(e);
    }
    _bus.bump('capsules');
  }

  /// Dosyalar önce silinir: satır gidince depolama kuralı sahibi doğrulayamaz.
  Future<void> delete(String id) async {
    await _media.deleteFolder(_folder(id));
    try {
      await _capsules.delete().eq('id', id);
    } catch (e) {
      throw AppFailure.from(e);
    }
    _bus.bump('capsules');
  }
}

final capsulesProvider = StreamProvider.autoDispose<List<Capsule>>(
  (ref) => ref.watch(capsulesRepositoryProvider).watchAll(),
);

final capsuleProvider = StreamProvider.autoDispose.family<Capsule?, String>(
  (ref, id) => ref.watch(capsulesRepositoryProvider).watchOne(id),
);
