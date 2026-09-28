import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/common.dart';
import '../../pairing/data/pairing_repository.dart';

class PartnerManagementScreen extends ConsumerStatefulWidget {
  const PartnerManagementScreen({super.key});

  @override
  ConsumerState<PartnerManagementScreen> createState() => _PartnerManagementScreenState();
}

class _PartnerManagementScreenState extends ConsumerState<PartnerManagementScreen> {
  bool _busy = false;

  Future<void> _unpair() async {
    final name = ref.read(partnerNameProvider);
    final ok = await context.confirm(
      title: 'Eşleşme sonlandırılsın mı?',
      message:
          '$name ile ortak alanınız kapatılır. Sohbet, anılar ve planlar ikiniz için de erişilemez olur ve 30 gün sonra kalıcı olarak silinir.',
      confirmLabel: 'Eşleşmeyi bitir',
      destructive: true,
    );
    if (!ok) return;
    setState(() => _busy = true);
    try {
      await ref.read(pairingRepositoryProvider).unpair();
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partner = ref.watch(partnerProfileProvider);
    final couple = ref.watch(coupleProvider).value;
    final partnerName = ref.watch(partnerNameProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Partner Yönetimi')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          VisalCard(
            child: Column(
              children: [
                AppAvatar(url: partner?.photoUrl, name: partner?.name ?? partnerName, size: 84, ring: true),
                const SizedBox(height: 12),
                Text(partner?.name ?? partnerName, style: context.text.titleLarge),
                if (couple?.createdAt != null) ...[
                  const SizedBox(height: 4),
                  Text('${couple!.createdAt!.dMMMMy} tarihinden beri VISAL\'da', style: context.text.bodySmall),
                ],
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'VISAL\'da her kullanıcı aynı anda yalnızca bir partnerle eşleşebilir. Eşleşmeyi bitirirsen yeni bir davet koduyla tekrar eşleşebilirsin.',
            style: context.text.bodySmall,
          ),
          const SizedBox(height: 20),
          OutlinedButton.icon(
            onPressed: _busy ? null : _unpair,
            style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
            icon: _busy
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.link_off_rounded),
            label: const Text('Eşleşmeyi sonlandır'),
          ),
        ],
      ),
    );
  }
}
