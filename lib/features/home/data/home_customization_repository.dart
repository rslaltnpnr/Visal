import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/services/media_service.dart';
import '../../../core/services/supabase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/failure.dart';

final homeCustomizationRepositoryProvider = Provider<HomeCustomizationRepository>((ref) {
  return HomeCustomizationRepository(
    ref.watch(supabaseProvider),
    ref.watch(mediaServiceProvider),
    requireCoupleId(ref),
  );
});

/// Ana ekrandaki çifte ortak görseller. Değişiklik `couples` satırında tutulur;
/// dolayısıyla iki partnerde de Realtime ile aynı anda görünür.
class HomeCustomizationRepository {
  HomeCustomizationRepository(this._db, this._media, this.coupleId);

  final SupabaseClient _db;
  final MediaService _media;
  final String coupleId;

  Future<void> setSummaryPhoto(PickedMedia media) async {
    try {
      final old = await _db
          .from('couples')
          .select('summary_path')
          .eq('id', coupleId)
          .maybeSingle();
      final upload = await _media.upload(
        media,
        folder: '$coupleId/home/summary/${const Uuid().v4()}',
      );
      await _db.from('couples').update({
        'summary_photo': upload.url,
        'summary_path': upload.path,
      }).eq('id', coupleId);
      await _deleteOld(old?['summary_path'] as String?);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> removeSummaryPhoto() async {
    try {
      final old = await _db
          .from('couples')
          .select('summary_path')
          .eq('id', coupleId)
          .maybeSingle();
      await _db.from('couples').update({
        'summary_photo': null,
        'summary_path': null,
      }).eq('id', coupleId);
      await _deleteOld(old?['summary_path'] as String?);
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<void> _deleteOld(String? path) async {
    if (path == null || path.isEmpty || !path.contains('/')) return;
    await _media.deleteFolder(path.substring(0, path.lastIndexOf('/')));
  }
}
