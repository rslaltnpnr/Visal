import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/common.dart';
import '../data/capsules_repository.dart';
import '../domain/capsule.dart';

String remainingLabel(Duration d) {
  if (d.isNegative) return 'Açıldı';
  if (d.inDays >= 1) return '${d.inDays} gün sonra açılacak';
  if (d.inHours >= 1) return '${d.inHours} saat sonra açılacak';
  return '${d.inMinutes + 1} dakika sonra açılacak';
}

class CapsulesScreen extends ConsumerStatefulWidget {
  const CapsulesScreen({super.key});

  @override
  ConsumerState<CapsulesScreen> createState() => _CapsulesScreenState();
}

class _CapsulesScreenState extends ConsumerState<CapsulesScreen> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(minutes: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final partner = ref.watch(partnerNameProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Anı Kapsülü')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(Routes.capsuleNew),
        backgroundColor: context.isDark ? AppColors.rose : AppColors.midnight,
        foregroundColor: context.isDark ? AppColors.midnight : AppColors.ivory,
        icon: const Icon(Icons.lock_clock_outlined),
        label: const Text('Kapsül oluştur'),
      ),
      body: AsyncView(
        value: ref.watch(capsulesProvider),
        data: (capsules) {
          if (capsules.isEmpty) {
            return EmptyState(
              icon: Icons.hourglass_bottom_rounded,
              emoji: '⏳',
              title: 'Geleceğe bir mektup bırak',
              message: '$partner için bir mesaj, fotoğraf, video ya da ses kaydı kilitle. Seçtiğin gün gelene kadar açılamaz.',
            );
          }
          final forMe = capsules.where((c) => c.recipientId == uid).toList();
          final fromMe = capsules.where((c) => c.createdBy == uid).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 110),
            children: [
              if (forMe.isNotEmpty) ...[
                SectionHeader(title: 'Sana bırakılanlar'),
                for (final c in forMe) _CapsuleTile(capsule: c, subtitle: '$partner bıraktı'),
                const SizedBox(height: 18),
              ],
              if (fromMe.isNotEmpty) ...[
                SectionHeader(title: '$partner için bıraktıkların'),
                for (final c in fromMe) _CapsuleTile(capsule: c, subtitle: 'Sen bıraktın'),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _CapsuleTile extends StatelessWidget {
  const _CapsuleTile({required this.capsule, required this.subtitle});

  final Capsule capsule;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final open = capsule.isOpen;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VisalCard(
        gradient: open ? AppColors.roseTile : AppColors.chatPlumTile,
        onTap: () => context.push(Routes.capsule(capsule.id)),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white.withValues(alpha: 0.15),
              ),
              child: Icon(open ? Icons.lock_open_rounded : Icons.lock_rounded, color: Colors.white),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    capsule.title.isEmpty ? 'Kapsül' : capsule.title,
                    style: context.text.titleMedium?.copyWith(color: Colors.white),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$subtitle · ${capsule.openAt.dMMMMy}',
                    style: context.text.bodySmall?.copyWith(color: Colors.white70),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    remainingLabel(capsule.remaining),
                    style: context.text.labelMedium?.copyWith(color: open ? AppColors.midnight : AppColors.rose),
                  ),
                ],
              ),
            ),
            Row(
              children: [
                if (capsule.hasPhoto) const Icon(Icons.photo_outlined, color: Colors.white70, size: 16),
                if (capsule.hasVideo) const Icon(Icons.videocam_outlined, color: Colors.white70, size: 16),
                if (capsule.hasAudio) const Icon(Icons.mic_none_rounded, color: Colors.white70, size: 16),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
