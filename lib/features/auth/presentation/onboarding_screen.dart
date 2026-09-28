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

class _Page {
  const _Page(this.title, this.text, this.image, this.icon, {this.alignment = Alignment.center});

  final String title;
  final String text;
  final String image;
  final IconData icon;
  final Alignment alignment;
}

const _pages = [
  _Page(
    'Sadece ikiniz.',
    'Başka kullanıcılar, takipçiler veya keşfet yok. VISAL yalnızca size ait.',
    AppAssets.heroDefault,
    Icons.favorite_rounded,
  ),
  _Page(
    'Anılarınız bir arada.',
    'Fotoğraflarınızı, özel günlerinizi ve birlikte yaşadığınız anları saklayın.',
    AppAssets.togetherCard,
    Icons.photo_library_outlined,
  ),
  _Page(
    'Daha yakın.',
    'Sohbet edin, günlük soruları cevaplayın ve ilişkinizin küçük anlarını paylaşın.',
    AppAssets.fabric,
    Icons.chat_bubble_outline_rounded,
  ),
  _Page(
    'Mahremiyet önce gelir.',
    'VISAL iki kişinin özel alanı olarak tasarlandı.',
    AppAssets.splashBackground,
    Icons.lock_outline_rounded,
    alignment: Alignment.topCenter,
  ),
];

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final _controller = PageController();
  double _page = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() => _page = _controller.page ?? 0));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _finish(String route) async {
    await ref.read(preferencesProvider).setOnboardingSeen();
    if (mounted) context.go(route);
  }

  @override
  Widget build(BuildContext context) {
    final index = _page.round();
    final last = index == _pages.length - 1;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: AppColors.midnight,
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Parallax arka planlar
            for (var i = 0; i < _pages.length; i++)
              Opacity(
                opacity: (1 - (_page - i).abs()).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 1.08 - 0.08 * (1 - (_page - i).abs()).clamp(0.0, 1.0),
                  child: Image.asset(
                    _pages[i].image,
                    fit: BoxFit.cover,
                    alignment: _pages[i].alignment,
                  ),
                ),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x661A1124), Color(0x221A1124), Color(0xE61A1124), AppColors.midnight],
                  stops: [0, 0.35, 0.68, 1],
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 12, 12, 0),
                    child: Row(
                      children: [
                        const VisalMark(size: 34),
                        const SizedBox(width: 10),
                        const VisalWordmark(fontSize: 18, color: AppColors.ivory),
                        const Spacer(),
                        AnimatedOpacity(
                          opacity: last ? 0 : 1,
                          duration: const Duration(milliseconds: 200),
                          child: TextButton(
                            onPressed: last ? null : () => _finish(Routes.register),
                            child: Text(
                              'Atla',
                              style: TextStyle(color: AppColors.ivory.withValues(alpha: 0.8)),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: PageView.builder(
                      controller: _controller,
                      itemCount: _pages.length,
                      itemBuilder: (context, i) => _OnboardingPage(page: _pages[i]),
                    ),
                  ),
                  _Dots(count: _pages.length, page: _page),
                  const SizedBox(height: 28),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 28),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 280),
                      child: last
                          ? Column(
                              key: const ValueKey('last'),
                              children: [
                                GradientButton(
                                  label: 'Hesap Oluştur',
                                  onPressed: () => _finish(Routes.register),
                                ),
                                const SizedBox(height: 10),
                                TextButton(
                                  onPressed: () => _finish(Routes.login),
                                  child: const Text(
                                    'Zaten hesabım var',
                                    style: TextStyle(color: AppColors.ivory, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              key: const ValueKey('next'),
                              children: [
                                GradientButton(
                                  label: 'Devam',
                                  onPressed: () => _controller.nextPage(
                                    duration: const Duration(milliseconds: 480),
                                    curve: Curves.easeOutCubic,
                                  ),
                                ),
                                const SizedBox(height: 58),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.page});

  final _Page page;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.12),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
            ),
            child: Icon(page.icon, color: AppColors.rose, size: 22),
          ),
          const SizedBox(height: 22),
          Text(
            page.title,
            style: context.text.displaySmall?.copyWith(color: AppColors.ivory),
          ),
          const SizedBox(height: 14),
          Text(
            page.text,
            style: context.text.bodyLarge?.copyWith(
              color: AppColors.ivory.withValues(alpha: 0.82),
              height: 1.6,
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.page});

  final int count;
  final double page;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final t = (1 - (page - i).abs()).clamp(0.0, 1.0);
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 8 + 18 * t,
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
            color: Color.lerp(Colors.white.withValues(alpha: 0.3), AppColors.rose, t),
          ),
        );
      }),
    );
  }
}
