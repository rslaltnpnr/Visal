import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/visal_logo.dart';

/// Oturum yüklenirken gösterilen, native splash ile aynı görünen ekran.
class LaunchScreen extends StatelessWidget {
  const LaunchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.midnight,
      body: DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.deepGradient),
        child: Center(child: _Pulse(child: VisalMark(size: 96))),
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
        opacity: Tween(begin: 0.75, end: 1.0).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
        child: ScaleTransition(
          scale: Tween(begin: 0.97, end: 1.03).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
          child: widget.child,
        ),
      );
}
