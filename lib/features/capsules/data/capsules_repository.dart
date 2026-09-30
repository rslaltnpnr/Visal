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

  /// "Kapsülü Kilitle": medya önce private Storage'a yüklenir. Veritabanındaki
  /// kapsül satırı ile gizli içerik tek RPC/transaction içinde oluşturulur;
  /// ikinci insert başarısız olursa ilk insert ve bildirim tetikleyicisi de geri alınır.
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
    try {
      for (var i = 0; i < media.length; i++) {
        final path = await _media.uploadPrivate(
          media[i],
          folder: _folder(id),
          onProgress: (p) => onProgress?.call(media.isEmpty ? 1 : (i + p) / media.length),
        );
        refs.add(CapsuleMediaRef(path: path, kind: media[i].kind));
      }
      await _db.rpc<void>('create_capsule_atomic', params: {
        'p_id': id,
        'p_couple_id': coupleId,
        'p_recipient_id': recipientId,
        'p_open_at': dbTs(openAt),
        'p_title': title.trim(),
        'p_message': message.trim(),
        'p_media': refs.map((r) => r.toMap()).toList(),
        'p_has_photo': refs.any((r) => r.kind == MediaKind.image),
        'p_has_video': refs.any((r) => r.kind == MediaKind.video),
        'p_has_audio': refs.any((r) => r.kind == MediaKind.audio),
      });
    } catch (e) {
      if (refs.isNotEmpty) {
        try {
          await _media.deletePaths(refs.map((r) => r.path));
        } catch (_) {
          // DB işlemi başarısızsa yetim medya sonraki bakım temizliğinde silinir.
        }
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
