import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../data/pairing_repository.dart';
import '../domain/pair_request.dart';

/// "Resul sizinle VISAL'da eşleşmek istiyor." — Kabul Et / Reddet
class PairRequestScreen extends ConsumerStatefulWidget {
  const PairRequestScreen({super.key, required this.requestId});

  final String requestId;

  @override
  ConsumerState<PairRequestScreen> createState() => _PairRequestScreenState();
}

class _PairRequestScreenState extends ConsumerState<PairRequestScreen> {
  String? _busy;

  Future<void> _respond(bool accept) async {
    setState(() => _busy = accept ? 'accept' : 'reject');
    try {
      await ref.read(pairingRepositoryProvider).respond(widget.requestId, accept: accept);
      // Kabulde yönlendirme, users/{uid}.coupleId değişince otomatik olur.
      if (!accept && mounted) context.pop();
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final request = ref.watch(pairRequestProvider(widget.requestId));
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.deepGradient),
        child: SafeArea(
          child: request.when(
            loading: () => const LoadingView(),
            error: (e, _) => ErrorView(error: e),
            data: (r) {
              if (r == null || r.status != PairRequestStatus.pending) {
                return EmptyState(
                  icon: Icons.info_outline,
                  title: 'Bu istek artık geçerli değil',
                  action: OutlinedButton(onPressed: () => context.pop(), child: const Text('Geri dön')),
                );
              }
              return Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.close_rounded, color: AppColors.ivory),
                      ),
                    ),
                    const Spacer(),
                    AppAvatar(url: r.fromPhoto, name: r.fromName, size: 108, ring: true),
                    const SizedBox(height: 28),
                    Text(
                      '${r.fromName} sizinle VISAL\'da eşleşmek istiyor.',
                      textAlign: TextAlign.center,
                      style: context.text.headlineMedium?.copyWith(color: AppColors.ivory),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Kabul ettiğinde yalnızca ikinizin erişebileceği özel alan oluşturulur. '
                      'Bir kullanıcı yalnızca bir partnerle eşleşebilir.',
                      textAlign: TextAlign.center,
                      style: context.text.bodyMedium?.copyWith(
                        color: AppColors.ivory.withValues(alpha: 0.7),
                      ),
                    ),
                    const Spacer(),
                    GradientButton(
                      label: 'Kabul Et',
                      icon: Icons.favorite_rounded,
                      loading: _busy == 'accept',
                      onPressed: _busy == null ? () => _respond(true) : null,
                    ),
                    const SizedBox(height: 12),
                    TextButton(
                      onPressed: _busy == null ? () => _respond(false) : null,
                      child: _busy == 'reject'
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(
                              'Reddet',
                              style: TextStyle(color: AppColors.ivory.withValues(alpha: 0.8)),
                            ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
