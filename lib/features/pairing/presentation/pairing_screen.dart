import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/services/notification_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/visal_logo.dart';
import '../../auth/data/auth_repository.dart';
import '../data/pairing_repository.dart';
import '../domain/pair_request.dart';

/// Gelen eşleşme isteklerini dinleyip istek ekranını açan karışım.
mixin IncomingRequestListener<T extends ConsumerStatefulWidget> on ConsumerState<T> {
  String? _shownRequest;

  void listenIncoming() {
    ref.listen(incomingPairRequestsProvider, (_, next) {
      final list = next.value ?? const <PairRequest>[];
      if (list.isEmpty) return;
      final req = list.first;
      if (_shownRequest == req.id) return;
      _shownRequest = req.id;
      context.push('${Routes.pairingRequest}/${req.id}');
    });
  }
}

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen>
    with IncomingRequestListener {
  @override
  void initState() {
    super.initState();
    // Eşleşme isteklerinin bildirimle gelmesi için izin iste.
    ref.read(notificationServiceProvider).requestPermission();
  }

  @override
  Widget build(BuildContext context) {
    listenIncoming();
    final user = ref.watch(currentUserProvider).value;
    final outgoing = ref.watch(outgoingPairRequestProvider).value;
    final waiting = outgoing?.status == PairRequestStatus.pending;

    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: context.isDark
                ? const [Color(0xFF2A1830), AppColors.darkBackground]
                : const [Color(0xFFF6E4E4), AppColors.ivory],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
            children: [
              Row(
                children: [
                  VisalMark(size: 40, tone: context.isDark ? MarkTone.onDark : MarkTone.onLight),
                  const Spacer(),
                  TextButton(
                    onPressed: () => ref.read(authRepositoryProvider).signOut(),
                    child: const Text('Çıkış yap'),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              Text(
                'Merhaba${user != null ? ' ${user.firstName}' : ''},',
                style: context.text.titleMedium?.copyWith(color: context.palette.textSecondary),
              ),
              const SizedBox(height: 8),
              Text('İkinize ait alanı oluştur.', style: context.text.displaySmall),
              const SizedBox(height: 12),
              Text(
                'VISAL\'da her kullanıcı yalnızca bir partnerle eşleşir. '
                'Eşleştiğinizde yalnızca ikinizin erişebildiği özel bir alan oluşur.',
                style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
              ),
              const SizedBox(height: 32),
              if (waiting) ...[
                _WaitingCard(request: outgoing!),
                const SizedBox(height: 16),
              ],
              _OptionCard(
                icon: Icons.qr_code_2_rounded,
                title: 'Davet Kodu Oluştur',
                subtitle: 'Kodunu veya QR\'ını partnerinle paylaş.',
                gradient: AppColors.chatPlumTile,
                dark: true,
                onTap: () => context.push(Routes.pairingInvite),
              ),
              const SizedBox(height: 14),
              _OptionCard(
                icon: Icons.keyboard_alt_outlined,
                title: 'Partnerimin Kodunu Gir',
                subtitle: 'VISAL-XXXXX kodunu yaz ya da QR\'ı tara.',
                gradient: AppColors.roseTile,
                onTap: () => context.push(Routes.pairingEnter),
              ),
              const SizedBox(height: 36),
              Row(
                children: [
                  Icon(Icons.lock_outline_rounded, size: 16, color: context.palette.muted),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Eşleşme kodu 24 saat geçerlidir ve tek kullanımlıktır.',
                      style: context.text.bodySmall,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.dark = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.ivory : AppColors.midnight;
    return VisalCard(
      gradient: gradient,
      onTap: onTap,
      padding: const EdgeInsets.all(22),
      radius: AppRadii.cardLarge,
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: dark ? 0.12 : 0.4),
            ),
            child: Icon(icon, color: fg),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: context.text.titleMedium?.copyWith(color: fg)),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: context.text.bodySmall?.copyWith(color: fg.withValues(alpha: 0.75)),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_rounded, color: fg),
        ],
      ),
    );
  }
}

class _WaitingCard extends ConsumerStatefulWidget {
  const _WaitingCard({required this.request});

  final PairRequest request;

  @override
  ConsumerState<_WaitingCard> createState() => _WaitingCardState();
}

class _WaitingCardState extends ConsumerState<_WaitingCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return VisalCard(
      child: Row(
        children: [
          const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('İstek gönderildi', style: context.text.titleSmall),
                Text(
                  '${widget.request.toName} onayladığında alanınız hazır olacak.',
                  style: context.text.bodySmall,
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: _busy
                ? null
                : () async {
                    setState(() => _busy = true);
                    try {
                      await ref.read(pairingRepositoryProvider).cancelRequest(widget.request.id);
                    } catch (e) {
                      if (context.mounted) context.showError(e);
                    }
                    if (mounted) setState(() => _busy = false);
                  },
            child: const Text('İptal'),
          ),
        ],
      ),
    );
  }
}
