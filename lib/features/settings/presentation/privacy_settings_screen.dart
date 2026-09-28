import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/user_settings.dart';

class PrivacySettingsScreen extends ConsumerWidget {
  const PrivacySettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final privacy = ref.watch(currentUserProvider).value?.settings.privacy ?? const PrivacySettings();
    Future<void> update(PrivacySettings p) async {
      try {
        await ref.read(profileRepositoryProvider).updatePrivacy(p);
      } catch (e) {
        if (context.mounted) context.showError(e);
      }
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Gizlilik')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          VisalCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                SwitchListTile(
                  value: privacy.showOnline,
                  onChanged: (v) => update(privacy.copyWith(showOnline: v)),
                  title: const Text('Çevrimiçi durumu'),
                  subtitle: const Text('Partnerin çevrimiçi olduğunu görebilir'),
                ),
                SwitchListTile(
                  value: privacy.showLastSeen,
                  onChanged: (v) => update(privacy.copyWith(showLastSeen: v)),
                  title: const Text('Son görülme'),
                ),
                SwitchListTile(
                  value: privacy.readReceipts,
                  onChanged: (v) => update(privacy.copyWith(readReceipts: v)),
                  title: const Text('Okundu bilgisi'),
                  subtitle: const Text('Kapatırsan partnerinin okundu bilgisini de göremezsin'),
                ),
                SwitchListTile(
                  value: privacy.moodVisible,
                  onChanged: (v) => update(privacy.copyWith(moodVisible: v)),
                  title: const Text('Ruh hali görünürlüğü'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text('Bildirim içeriği', style: context.text.titleMedium),
          const SizedBox(height: 10),
          VisalCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: RadioGroup<bool>(
              groupValue: privacy.notificationPreview,
              onChanged: (v) => update(privacy.copyWith(notificationPreview: v ?? true)),
              child: const Column(
                children: [
                  RadioListTile<bool>(
                    value: true,
                    title: Text('Normal'),
                    subtitle: Text('“Ayşe: Seni özledim ❤️”'),
                  ),
                  RadioListTile<bool>(
                    value: false,
                    title: Text('Gizli'),
                    subtitle: Text('“VISAL — Yeni mesaj”'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Tüm verileriniz yalnızca siz ve partneriniz tarafından erişilebilir; güvenlik kuralları üçüncü kişilerin erişimini sunucu tarafında engeller.',
            style: context.text.bodySmall,
          ),
        ],
      ),
    );
  }
}
