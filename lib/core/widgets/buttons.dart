import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Soft rose → mauve gradient CTA (ör. "Başlayalım →").
class GradientButton extends StatelessWidget {
  const GradientButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon = Icons.arrow_forward_rounded,
    this.loading = false,
    this.height = 58,
    this.gradient = AppColors.ctaGradient,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final double height;
  final Gradient gradient;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !loading;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 200),
      opacity: enabled || loading ? 1 : 0.5,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: gradient,
          borderRadius: BorderRadius.circular(AppRadii.button + 4),
          border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          boxShadow: [
            BoxShadow(color: AppColors.plum.withValues(alpha: 0.25), blurRadius: 24, offset: const Offset(0, 10)),
          ],
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadii.button + 4),
            onTap: enabled
                ? () {
                    HapticFeedback.lightImpact();
                    onPressed!();
                  }
                : null,
            child: SizedBox(
              height: height,
              child: Center(
                child: loading
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            label,
                            style: const TextStyle(
                              fontFamily: kFontFamily,
                              color: Colors.white,
                              fontSize: 17,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.4,
                            ),
                          ),
                          if (icon != null) ...[const SizedBox(width: 14), Icon(icon, color: Colors.white, size: 20)],
                        ],
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Koyu mürdüm, hap biçimli ana buton ("Cevabını Paylaş →").
class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.icon,
    this.loading = false,
    this.expand = true,
    this.compact = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  final bool loading;
  final bool expand;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final child = loading
        ? SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: context.isDark ? AppColors.midnight : AppColors.ivory,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: compact
                    ? FittedBox(fit: BoxFit.scaleDown, child: Text(label, maxLines: 1))
                    : Text(label, overflow: TextOverflow.ellipsis),
              ),
              if (icon != null) ...[SizedBox(width: compact ? 8 : 10), Icon(icon, size: 18)],
            ],
          );
    final button = FilledButton(
      onPressed: loading ? null : onPressed,
      style: compact
          ? FilledButton.styleFrom(minimumSize: const Size(0, 44), padding: const EdgeInsets.symmetric(horizontal: 18))
          : null,
      child: child,
    );
    return expand ? SizedBox(width: double.infinity, child: button) : button;
  }
}

/// Yumuşak arka planlı yuvarlak ikon ("İlişki Özetimiz" kalbi gibi).
class SoftIcon extends StatelessWidget {
  const SoftIcon(this.icon, {super.key, this.size = 40, this.color, this.background, this.emoji});

  final IconData? icon;
  final double size;
  final Color? color;
  final Color? background;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: background ?? (context.isDark ? AppColors.rose.withValues(alpha: 0.12) : const Color(0xFFF7E4E6)),
      ),
      alignment: Alignment.center,
      child: emoji != null
          ? Text(emoji!, style: TextStyle(fontSize: size * 0.45))
          : Icon(icon, size: size * 0.5, color: color ?? (context.isDark ? AppColors.rose : AppColors.wine)),
    );
  }
}

/// Header'larda kullanılan cam efektli yuvarlak ikon butonu.
class GlassIconButton extends StatelessWidget {
  const GlassIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.badge = false,
    this.dark = false,
  });

  final IconData icon;
  final VoidCallback onPressed;
  final bool badge;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.midnight : Colors.white;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Material(
          color: (dark ? Colors.white : Colors.black).withValues(alpha: 0.12),
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(width: 42, height: 42, child: Icon(icon, color: fg, size: 22)),
          ),
        ),
        if (badge)
          Positioned(
            right: 8,
            top: 7,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: AppColors.rose,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 1.4),
              ),
            ),
          ),
      ],
    );
  }
}
