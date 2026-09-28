import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pickers.dart';
import '../data/profile_repository.dart';
import 'cover_photo_sheet.dart';

/// İlişki başlangıç tarihi ve yıldönümü (gün sayacı buradan hesaplanır).
class RelationshipScreen extends ConsumerStatefulWidget {
  const RelationshipScreen({super.key});

  @override
  ConsumerState<RelationshipScreen> createState() => _RelationshipScreenState();
}

class _RelationshipScreenState extends ConsumerState<RelationshipScreen> {
  late DateTime? _start = ref.read(coupleProvider).value?.relationshipStartDate;
  late DateTime? _anniversary = ref.read(coupleProvider).value?.anniversaryDate;
  bool _saving = false;

  Future<void> _save() async {
    if (_start == null) {
      context.showSnack('Başlangıç tarihini seçin');
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateCouple(
            relationshipStartDate: _start,
            anniversaryDate: _anniversary,
            clearAnniversary: _anniversary == null,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('İlişkimiz')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            'Gün sayacı ve yıldönümü hatırlatmaları bu tarihlere göre hesaplanır. İkiniz de düzenleyebilirsiniz.',
            style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
          ),
          const SizedBox(height: 24),
          PickerField(
            label: 'İlişki başlangıç tarihi',
            icon: Icons.favorite_border_rounded,
            value: formatDateOrNull(_start),
            onTap: () async {
              final d = await pickDate(context, initial: _start ?? DateTime.now(), last: DateTime.now());
              if (d != null) setState(() => _start = d);
            },
          ),
          if (_start != null) ...[
            const SizedBox(height: 8),
            Text(
              '${formatThousands(daysTogether(_start!))} gündür birlikte',
              style: context.text.labelMedium,
            ),
          ],
          const SizedBox(height: 16),
          PickerField(
            label: 'Yıldönümü (farklıysa, ör. evlilik)',
            icon: Icons.celebration_outlined,
            value: formatDateOrNull(_anniversary),
            onClear: () => setState(() => _anniversary = null),
            onTap: () async {
              final d = await pickDate(context, initial: _anniversary ?? _start ?? DateTime.now());
              if (d != null) setState(() => _anniversary = d);
            },
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () => showCoverPhotoSheet(
              context,
              ref,
              hasCover: ref.read(coupleProvider).value?.coverPhoto != null,
            ),
            icon: const Icon(Icons.wallpaper_rounded, size: 18),
            label: const Text('Ana ekran kapak fotoğrafı'),
          ),
          const SizedBox(height: 32),
          PrimaryButton(label: 'Kaydet', onPressed: _save, loading: _saving),
        ],
      ),
    );
  }
}
