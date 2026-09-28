import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../auth/data/auth_repository.dart';
import 'lock_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Ayarlar')),
        body: ListView(padding: const EdgeInsets.fromLTRB(20, 8, 20, 40), children: const [SettingsList()]),
      );
}

/// Profil sekmesinde de kullanılan ayar listesi.
class SettingsList extends ConsumerWidget {
  const SettingsList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final lock = ref.watch(appLockControllerProvider).value;
    Widget tile(IconData icon, String title, String route, {String? value}) => ListTile(
          leading: SoftIcon(icon, size: 36),
          title: Text(title, style: context.text.bodyLarge),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (value != null) Text(value, style: context.text.labelMedium),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
          onTap: () => context.push(route),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 10),
          child: Text('Ayarlar', style: context.text.titleLarge),
        ),
        VisalCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              tile(Icons.notifications_none_rounded, 'Bildirimler', Routes.settingsNotifications),
              tile(Icons.shield_outlined, 'Gizlilik', Routes.settingsPrivacy),
              tile(
                Icons.dark_mode_outlined,
                'Tema',
                Routes.settingsTheme,
                value: switch (themeMode) {
                  ThemeMode.system => 'Sistem',
                  ThemeMode.light => 'Açık',
                  ThemeMode.dark => 'Koyu',
                },
              ),
              tile(Icons.fingerprint_rounded, 'Uygulama kilidi', Routes.settingsLock,
                  value: (lock?.enabled ?? false) ? 'Açık' : 'Kapalı'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        VisalCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              tile(Icons.people_outline_rounded, 'Partner yönetimi', Routes.settingsPartner),
              tile(Icons.person_outline_rounded, 'Hesap', Routes.settingsAccount),
            ],
          ),
        ),
        const SizedBox(height: 14),
        VisalCard(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: ListTile(
            leading: const SoftIcon(Icons.logout_rounded, size: 36, color: AppColors.error),
            title: Text('Çıkış yap', style: context.text.bodyLarge?.copyWith(color: AppColors.error)),
            onTap: () async {
              final ok = await context.confirm(title: 'Çıkış yapılsın mı?', confirmLabel: 'Çıkış yap');
              if (!ok) return;
              await ref.read(presenceServiceProvider).signOut();
              await ref.read(notificationServiceProvider).unregister();
              await ref.read(authRepositoryProvider).signOut();
            },
          ),
        ),
        const SizedBox(height: 24),
        Center(
          child: Text(
            'VISAL · İkinize ait bir dünya.',
            style: context.text.labelSmall,
          ),
        ),
      ],
    );
  }
}
