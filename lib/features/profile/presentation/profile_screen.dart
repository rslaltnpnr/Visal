import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../settings/presentation/settings_screen.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = ref.watch(currentUserProvider).value;
    final partner = ref.watch(partnerProfileProvider);
    final couple = ref.watch(coupleProvider).value;
    final partnerName = ref.watch(partnerNameProvider);

    return Scaffold(
      body: ListView(
        padding: EdgeInsets.fromLTRB(20, MediaQuery.paddingOf(context).top + 16, 20, 40),
        children: [
          Row(
            children: [
              Expanded(child: Text('Profil', style: context.text.headlineMedium)),
              IconButton(
                onPressed: () => context.push(Routes.profileEdit),
                icon: const Icon(Icons.edit_outlined),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Center(
            child: GestureDetector(
              onTap: () => context.push(Routes.profileEdit),
              child: AppAvatar(url: me?.photoUrl, name: me?.name ?? '', size: 104, ring: true),
            ),
          ),
          const SizedBox(height: 14),
          Center(child: Text(me?.name ?? '', style: context.text.headlineSmall)),
          Center(child: Text(me?.email ?? '', style: context.text.bodySmall)),
          const SizedBox(height: 24),
          VisalCard(
            gradient: AppColors.chatPlumTile,
            onTap: () => context.push(Routes.settingsPartner),
            child: Row(
              children: [
                SizedBox(
                  width: 76,
                  height: 44,
                  child: Stack(
                    children: [
                      AppAvatar(url: me?.photoUrl, name: me?.name ?? '', size: 44),
                      Positioned(
                        left: 30,
                        child: AppAvatar(url: partner?.photoUrl, name: partner?.name ?? partnerName, size: 44),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Partnerin', style: context.text.labelSmall?.copyWith(color: AppColors.rose)),
                      Text(
                        partner?.name ?? partnerName,
                        style: context.text.titleMedium?.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Colors.white70),
              ],
            ),
          ),
          const SizedBox(height: 14),
          VisalCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                _InfoRow(
                  icon: Icons.favorite_border_rounded,
                  label: 'İlişki başlangıcı',
                  value: couple?.relationshipStartDate?.dMMMMy,
                  onTap: () => context.push(Routes.relationship),
                ),
                _InfoRow(
                  icon: Icons.celebration_outlined,
                  label: 'Yıldönümü',
                  value: couple?.effectiveAnniversary?.dMMMM,
                  onTap: () => context.push(Routes.relationship),
                ),
                _InfoRow(
                  icon: Icons.cake_outlined,
                  label: 'Doğum günün',
                  value: me?.birthday?.dMMMMy,
                  onTap: () => context.push(Routes.profileEdit),
                ),
                if (partner?.birthday != null)
                  _InfoRow(
                    icon: Icons.cake_outlined,
                    label: '${partner!.firstName} doğum günü',
                    value: partner.birthday!.dMMMM,
                  ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const SettingsList(),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, this.value, this.onTap});

  final IconData icon;
  final String label;
  final String? value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        leading: SoftIcon(icon, size: 36),
        title: Text(label, style: context.text.bodyMedium),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              value ?? 'Ekle',
              style: context.text.labelMedium?.copyWith(color: value == null ? AppColors.mauve : null),
            ),
            if (onTap != null) const Icon(Icons.chevron_right_rounded, size: 20),
          ],
        ),
      );
}
