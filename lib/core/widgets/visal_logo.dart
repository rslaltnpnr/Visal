import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_assets.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

/// Logonun hangi zemin üzerinde durduğu.
enum MarkTone {
  /// Koyu zemin (splash, app icon): açık, parlak gül tonları.
  onDark,

  /// Açık zemin (fildişi header): koyu mürdüm + gül.
  onLight,
}

/// VISAL'ın V sembolü.
///
/// İki yumuşak kol iki insanı/iki hayatı; aralarındaki damla biçimli parça ise
/// sarılmayı ve gizli bir kalbi (sol kolla birlikte kalbin üst kıvrımını)
/// çağrıştırır. Tamamen vektörel çizilir.
class VisalMark extends StatelessWidget {
  const VisalMark({super.key, this.size = 64, this.tone = MarkTone.onDark});

  final double size;
  final MarkTone tone;

  static const double aspect = 0.9; // yükseklik / genişlik

  @override
  Widget build(BuildContext context) {
    final vector = CustomPaint(painter: VisalMarkPainter(tone));
    final asset = tone == MarkTone.onDark ? AppAssets.logoMark : AppAssets.logoMarkLight;
    // Açık zemin sürümü yoksa ana logo dosyası kullanılır.
    final path = AppAssets.has(asset)
        ? asset
        : (AppAssets.has(AppAssets.logoMark) ? AppAssets.logoMark : null);
    return SizedBox(
      width: size,
      height: size * aspect,
      // Marka dosyası eklendiyse onu kullan, yoksa vektörel sembol.
      child: path == null
          ? vector
          : Image.asset(path, fit: BoxFit.contain, errorBuilder: (_, _, _) => vector),
    );
  }
}

class VisalMarkPainter extends CustomPainter {
  VisalMarkPainter(this.tone);

  final MarkTone tone;

  // 100 x 90 birimlik tasarım alanı (referans logo oranları).
  static const _left = (a: Offset(14, 19), b: Offset(47, 74), r: 11.5);
  static const _cradle = (a: Offset(47, 74), b: Offset(66, 50), r: 11.5);
  static const _right = (a: Offset(86, 20), b: Offset(62, 53), r: 10.5);
  static const _lobeTop = (c: Offset(47, 21), r: 19.0);
  static const _lobeTip = (c: Offset(56, 50), r: 9.0);

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width / 100;
    canvas.save();
    canvas.scale(s, s);

    final dark = tone == MarkTone.onDark;
    const rect = Rect.fromLTWH(0, 0, 100, 90);

    Shader linear(List<Color> colors, Offset a, Offset b, [List<double>? stops]) => LinearGradient(
          begin: Alignment(a.dx / 50 - 1, a.dy / 45 - 1),
          end: Alignment(b.dx / 50 - 1, b.dy / 45 - 1),
          colors: colors,
          stops: stops,
        ).createShader(rect);

    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: dark ? 0.3 : 0.16)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.4);

    // 1) Gizli kalp: arkadaki büyük damla.
    final lobe = _tapered(_lobeTop.c, _lobeTop.r, _lobeTip.c, _lobeTip.r);
    canvas.drawPath(
      lobe,
      Paint()
        ..shader = linear(
          dark
              ? const [Color(0xFFD9798F), Color(0xFFF3A6B0), Color(0xFFFFF1F0)]
              : const [Color(0xFFC4587A), Color(0xFFF29DA9), Color(0xFFFCEAE7)],
          const Offset(30, 8),
          const Offset(62, 52),
          const [0, 0.5, 1],
        ),
    );

    // 2) Sol şerit + V'nin dibini oluşturup sağ kolu saran kıvrım.
    final ribbon = Path.combine(
      PathOperation.union,
      _capsule(_left.a, _left.b, _left.r),
      _capsule(_cradle.a, _cradle.b, _cradle.r),
    );
    canvas.drawPath(ribbon.shift(const Offset(0, 1.6)), shadow);
    canvas.drawPath(
      ribbon,
      Paint()
        ..shader = linear(
          dark
              ? const [Color(0xFFCB6C87), Color(0xFF9B3F62), Color(0xFF7A2C4E), Color(0xFFE58E9E)]
              : const [Color(0xFF6E2F55), Color(0xFF3A1530), Color(0xFF2A0F24), Color(0xFFE88F9F)],
          const Offset(8, 12),
          const Offset(72, 82),
          const [0, 0.45, 0.62, 1],
        ),
    );

    // 3) Şeridin kenarındaki ince ışık: kalbin üzerinden inip sağ kolu sarar.
    final edge = Path()
      ..moveTo(28.5, 21)
      ..lineTo(53, 61.5)
      ..cubicTo(56.5, 67.5, 64.5, 67.5, 70.5, 59);
    canvas.drawPath(
      edge,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.6
        ..color = Colors.white.withValues(alpha: dark ? 0.9 : 0.85),
    );

    // 4) Sağ kol: öne gelen, açık gül tonlu kapsül.
    final right = _capsule(_right.a, _right.b, _right.r);
    canvas.drawPath(right.shift(const Offset(-1.2, 1.8)), shadow);
    canvas.drawPath(
      right,
      Paint()
        ..shader = linear(
          dark
              ? const [Color(0xFFA24566), Color(0xFFE38A9C), Color(0xFFFDD9D9)]
              : const [Color(0xFF8A3558), Color(0xFFE48C9C), Color(0xFFFCD3D3)],
          const Offset(58, 60),
          const Offset(92, 14),
        ),
    );

    canvas.restore();
  }

  /// İki noktayı birleştiren yuvarlak uçlu kapsül.
  static Path _capsule(Offset a, Offset b, double r) => _tapered(a, r, b, r);

  /// İki daireyi dış teğetlerle birleştiren yumuşak biçim.
  static Path _tapered(Offset c1, double r1, Offset c2, double r2) {
    final d = c2 - c1;
    final dist = d.distance;
    final angle = math.atan2(d.dy, d.dx);
    final delta = math.acos(((r1 - r2) / dist).clamp(-1.0, 1.0));

    Offset pt(Offset c, double r, double a) => Offset(c.dx + r * math.cos(a), c.dy + r * math.sin(a));

    final p1 = pt(c1, r1, angle + delta);
    final p2 = pt(c2, r2, angle + delta);
    final p3 = pt(c2, r2, angle - delta);
    final p4 = pt(c1, r1, angle - delta);

    return Path()
      ..moveTo(p1.dx, p1.dy)
      ..lineTo(p2.dx, p2.dy)
      ..arcToPoint(p3, radius: Radius.circular(r2), clockwise: false)
      ..lineTo(p4.dx, p4.dy)
      ..arcToPoint(p1, radius: Radius.circular(r1), largeArc: r1 > r2, clockwise: false)
      ..close();
  }

  @override
  bool shouldRepaint(VisalMarkPainter oldDelegate) => oldDelegate.tone != tone;
}

/// "VISAL" yazı markası.
class VisalWordmark extends StatelessWidget {
  const VisalWordmark({
    super.key,
    this.fontSize = 34,
    this.color,
    this.gradient,
  });

  final double fontSize;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final text = Text(
      'VISAL',
      textAlign: TextAlign.center,
      style: TextStyle(
        fontFamily: kFontFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w400,
        letterSpacing: fontSize * 0.28,
        height: 1,
        color: gradient == null ? (color ?? AppColors.midnight) : Colors.white,
      ),
    );
    if (gradient == null) return text;
    return ShaderMask(
      shaderCallback: (b) => gradient!.createShader(b),
      blendMode: BlendMode.srcIn,
      child: text,
    );
  }
}

/// Yatay logo: sembol + VISAL + slogan (ana ekran header'ı).
class VisalHorizontalLogo extends StatelessWidget {
  const VisalHorizontalLogo({
    super.key,
    this.height = 44,
    this.onDark = true,
    this.showTagline = true,
  });

  final double height;
  final bool onDark;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final textColor = onDark ? AppColors.ivory : AppColors.midnight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        VisalMark(size: height * 1.2, tone: MarkTone.onLight),
        SizedBox(width: height * 0.18),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            VisalWordmark(fontSize: height * 0.72, color: textColor),
            if (showTagline) ...[
              SizedBox(height: height * 0.12),
              Text(
                'İkinize ait bir dünya.',
                style: TextStyle(
                  fontFamily: kFontFamily,
                  fontSize: height * 0.24,
                  letterSpacing: 0.6,
                  color: textColor.withValues(alpha: 0.85),
                ),
              ),
            ],
          ],
        ),
      ],
    );
  }
}

/// Dikey logo: sembol üstte, VISAL altında (splash).
class VisalVerticalLogo extends StatelessWidget {
  const VisalVerticalLogo({super.key, this.markSize = 120, this.tagline = true});

  final double markSize;
  final bool tagline;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        VisalMark(size: markSize),
        SizedBox(height: markSize * 0.22),
        VisalWordmark(
          fontSize: markSize * 0.5,
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFF6DCE0)],
          ),
        ),
        if (tagline) ...[
          SizedBox(height: markSize * 0.14),
          Text(
            'İkinize ait bir dünya.',
            style: TextStyle(
              fontFamily: kFontFamily,
              fontSize: markSize * 0.15,
              fontWeight: FontWeight.w400,
              letterSpacing: 1.6,
              color: AppColors.ivory.withValues(alpha: 0.88),
            ),
          ),
        ],
      ],
    );
  }
}

/// Uygulama ikonu biçiminde sembol (yuvarlatılmış kare, mürdüm gradient).
class VisalAppIcon extends StatelessWidget {
  const VisalAppIcon({super.key, this.size = 96});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.23),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF9A5577), Color(0xFF5B274B), Color(0xFF2A1224)],
          stops: [0, 0.45, 1],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.plum.withValues(alpha: 0.35),
            blurRadius: size * 0.25,
            offset: Offset(0, size * 0.08),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: VisalMark(size: size * 0.62),
    );
  }
}
