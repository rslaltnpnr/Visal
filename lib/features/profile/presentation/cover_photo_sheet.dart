import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/media_service.dart';
import '../../../core/widgets/common.dart';
import '../data/profile_repository.dart';

/// Kapak fotoğrafı seçimi (hero'ya uzun basma ve İlişkimiz ekranı).
Future<void> showCoverPhotoSheet(BuildContext context, WidgetRef ref, {required bool hasCover}) async {
  HapticFeedback.mediumImpact();
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Kapak fotoğrafı seç'),
            onTap: () => Navigator.pop(ctx, 'pick'),
          ),
          if (hasCover)
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('Varsayılan görsele dön'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
        ],
      ),
    ),
  );
  if (choice == null) return;
  final repo = ref.read(profileRepositoryProvider);
  try {
    if (choice == 'remove') {
      await repo.removeCoverPhoto();
    } else {
      final media = await ref.read(mediaServiceProvider).pickImage();
      if (media == null) return;
      if (context.mounted) context.showSnack('Kapak fotoğrafı yükleniyor…');
      await repo.setCoverPhoto(media);
    }
  } catch (e) {
    if (context.mounted) context.showError(e);
  }
}

