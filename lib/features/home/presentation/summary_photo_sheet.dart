import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/media_service.dart';
import '../../../core/widgets/common.dart';
import '../data/home_customization_repository.dart';

Future<void> showSummaryPhotoSheet(
  BuildContext context,
  WidgetRef ref, {
  required bool hasPhoto,
}) async {
  HapticFeedback.mediumImpact();
  final choice = await showModalBottomSheet<String>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const Icon(Icons.photo_library_outlined),
            title: const Text('Özet kartı fotoğrafını değiştir'),
            subtitle: const Text('İkinizde de aynı fotoğraf görünür'),
            onTap: () => Navigator.pop(ctx, 'pick'),
          ),
          if (hasPhoto)
            ListTile(
              leading: const Icon(Icons.restore_rounded),
              title: const Text('VISAL varsayılan görseline dön'),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
        ],
      ),
    ),
  );
  if (choice == null) return;

  final repo = ref.read(homeCustomizationRepositoryProvider);
  try {
    if (choice == 'remove') {
      await repo.removeSummaryPhoto();
      if (context.mounted) context.showSnack('Varsayılan görsele dönüldü');
      return;
    }
    final media = await ref.read(mediaServiceProvider).pickImage();
    if (media == null) return;
    if (context.mounted) context.showSnack('Fotoğraf yükleniyor…');
    await repo.setSummaryPhoto(media);
    if (context.mounted) context.showSnack('Ana ekran fotoğrafı güncellendi');
  } catch (e) {
    if (context.mounted) context.showError(e);
  }
}
