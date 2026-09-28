import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/visal_logo.dart';

/// Açılış ekranı: sinematik gün batımı, VISAL sembolü ve "Başlayalım →".
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1800),
  )..forward();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Animation<double> _interval(double a, double b) =>
      CurvedAnimation(parent: _c, curve: Interval(a, b, curve: Curves.easeOutCubic));

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnight,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Gökyüzü
            const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.sunsetGradient)),
            // Sinematik görsel (alt %62)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: size.height * 0.64,
              child: FadeTransition(
                opacity: _interval(0, 0.6),
                child: ShaderMask(
                  shaderCallback: (r) => const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Colors.transparent, Colors.black, Colors.black],
                    stops: [0, 0.22, 1],
                  ).createShader(r),
                  blendMode: BlendMode.dstIn,
                  child: Image.asset(
                    AppAssets.splashBackground,
                    fit: BoxFit.cover,
                    alignment: Alignment.topCenter,
                  ),
                ),
              ),
            ),
            // Alt karartma
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0x33000000),
                    Colors.transparent,
                    Colors.transparent,
                    Color(0xCC1A1124),
                    Color(0xFF1A1124),
                  ],
                  stops: [0, 0.2, 0.55, 0.82, 1],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  children: [
                    SizedBox(height: size.height * 0.07),
                    FadeTransition(
                      opacity: _interval(0.15, 0.7),
                      child: SlideTransition(
                        position: Tween(begin: const Offset(0, 0.08), end: Offset.zero)
                            .animate(_interval(0.15, 0.8)),
                        child: const VisalVerticalLogo(markSize: 118),
                      ),
                    ),
                    const Spacer(),
                    FadeTransition(
                      opacity: _interval(0.5, 1),
                      child: Column(
                        children: [
                          Text(
                            'Sadece ikiniz için tasarlandı.',
                            textAlign: TextAlign.center,
                            style: context.text.bodyLarge?.copyWith(
                              color: AppColors.ivory.withValues(alpha: 0.92),
                              letterSpacing: 0.6,
                              fontWeight: FontWeight.w400,
                            ),
                          ),
                          const SizedBox(height: 18),
                          Container(
                            width: 36,
                            height: 1.5,
                            color: AppColors.rose.withValues(alpha: 0.8),
                          ),
                          const SizedBox(height: 34),
                          GradientButton(
                            label: 'Başlayalım',
                            onPressed: () {
                              final seen = ref.read(preferencesProvider).onboardingSeen;
                              context.go(seen ? Routes.login : Routes.onboarding);
                            },
                          ),
                          const SizedBox(height: 26),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
