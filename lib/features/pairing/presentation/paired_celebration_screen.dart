import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/visal_logo.dart';

/// Eşleşme tamamlandı animasyonu: "Artık burası ikinize ait."
class PairedCelebrationScreen extends ConsumerStatefulWidget {
  const PairedCelebrationScreen({super.key});

  @override
  ConsumerState<PairedCelebrationScreen> createState() => _PairedCelebrationScreenState();
}

class _PairedCelebrationScreenState extends ConsumerState<PairedCelebrationScreen>
    with TickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 2600))
    ..forward();
  late final _glow = AnimationController(vsync: this, duration: const Duration(seconds: 3))
    ..repeat(reverse: true);

  @override
  void initState() {
    super.initState();
    Future<void>.delayed(const Duration(milliseconds: 1150), HapticFeedback.mediumImpact);
  }

  @override
  void dispose() {
    _c.dispose();
    _glow.dispose();
    super.dispose();
  }

  Animation<double> _i(double a, double b, [Curve curve = Curves.easeOutCubic]) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: curve));

  Future<void> _continue() async {
    final coupleId = ref.read(coupleIdProvider);
    if (coupleId != null) await ref.read(preferencesProvider).setCelebrated(coupleId);
    if (mounted) context.go(Routes.home);
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    final partner = ref.watch(partnerProfileProvider);
    final join = _i(0.1, 0.5, Curves.easeInOutCubic);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.sunsetGradient),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                const Spacer(),
                SizedBox(
                  height: 220,
                  child: AnimatedBuilder(
                    animation: Listenable.merge([_c, _glow]),
                    builder: (context, _) {
                      final gap = 90 * (1 - join.value);
                      return Stack(
                        alignment: Alignment.center,
                        children: [
                          // Kalp atışı gibi ışık halkası
                          Opacity(
                            opacity: _i(0.45, 0.7).value,
                            child: Container(
                              width: 200 + 16 * math.sin(_glow.value * math.pi),
                              height: 200 + 16 * math.sin(_glow.value * math.pi),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    AppColors.rose.withValues(alpha: 0.45),
                                    AppColors.rose.withValues(alpha: 0),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          Transform.translate(
                            offset: Offset(-34 - gap, 0),
                            child: AppAvatar(url: me?.photoUrl, name: me?.name ?? '', size: 92, ring: true),
                          ),
                          Transform.translate(
                            offset: Offset(34 + gap, 0),
                            child: AppAvatar(
                              url: partner?.photoUrl,
                              name: partner?.name ?? '',
                              size: 92,
                              ring: true,
                            ),
                          ),
                          Transform.translate(
                            offset: const Offset(0, 62),
                            child: Transform.scale(
                              scale: _i(0.45, 0.7, Curves.elasticOut).value,
                              child: Container(
                                padding: const EdgeInsets.all(10),
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  gradient: AppColors.ctaGradient,
                                ),
                                child: const Icon(Icons.favorite_rounded, color: Colors.white, size: 22),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
                const SizedBox(height: 36),
                FadeTransition(
                  opacity: _i(0.55, 0.85),
                  child: SlideTransition(
                    position: Tween(begin: const Offset(0, 0.2), end: Offset.zero).animate(_i(0.55, 0.9)),
                    child: Column(
                      children: [
                        const VisalMark(size: 44),
                        const SizedBox(height: 18),
                        Text(
                          'Artık burası ikinize ait.',
                          textAlign: TextAlign.center,
                          style: context.text.displaySmall?.copyWith(color: AppColors.ivory),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          '${me?.firstName ?? ''} & ${partner?.firstName ?? ''}',
                          style: context.text.titleMedium?.copyWith(
                            color: AppColors.ivory.withValues(alpha: 0.8),
                            fontWeight: FontWeight.w400,
                            letterSpacing: 1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const Spacer(),
                FadeTransition(
                  opacity: _i(0.8, 1),
                  child: GradientButton(label: 'Keşfetmeye başla', onPressed: _continue),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
