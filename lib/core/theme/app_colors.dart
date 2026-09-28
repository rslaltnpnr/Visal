import 'package:flutter/material.dart';

/// VISAL marka paleti.
abstract final class AppColors {
  // Marka
  static const Color midnight = Color(0xFF1A1124); // Gece Mavisi / Koyu Mürdüm
  static const Color rose = Color(0xFFE7A7B1); // Soft Gül
  static const Color mauve = Color(0xFFB68AA0); // Sıcak Mürdüm
  static const Color ivory = Color(0xFFF8F4EF); // Fildişi
  static const Color lavenderGrey = Color(0xFF9C8EA3); // Lavanta Grisi
  static const Color plum = Color(0xFF5B274B); // Logo gradient sonu
  static const Color deepPlum = Color(0xFF3A1830);
  static const Color wine = Color(0xFF4A2340);

  // Metin
  static const Color textPrimary = Color(0xFF281725);
  static const Color textSecondary = Color(0xFF766A73);

  // Durum
  static const Color success = Color(0xFF7DAF91);
  static const Color warning = Color(0xFFD6A25A);
  static const Color error = Color(0xFFC85C67);

  // Açık tema yüzeyleri
  static const Color lightSurface = Color(0xFFFFFCF9);
  static const Color lightCard = Color(0xFFFBF7F3);
  static const Color blush = Color(0xFFF6E7E6);
  static const Color divider = Color(0xFFEDE5E2);

  // Koyu tema
  static const Color darkBackground = Color(0xFF110B16);
  static const Color darkCard = Color(0xFF1C1422);
  static const Color darkElevated = Color(0xFF261B2D);
  static const Color darkDivider = Color(0xFF2E2335);
  static const Color darkText = ivory;
  static const Color darkTextSecondary = Color(0xFFB3A6B5);

  // Gradientler
  static const LinearGradient logoGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [rose, mauve, plum],
  );

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [Color(0xFFD9909E), Color(0xFFB07A93), Color(0xFF7C4467)],
  );

  static const LinearGradient deepGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF3B2238), Color(0xFF2A1628), midnight],
  );

  static const LinearGradient sunsetGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF3E2A44),
      Color(0xFF6B4058),
      Color(0xFFB0707A),
      Color(0xFF4A2A40),
      midnight,
    ],
    stops: [0, 0.32, 0.55, 0.8, 1],
  );

  static const LinearGradient chatPlumTile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF4A2742), Color(0xFF2C1529)],
  );

  static const LinearGradient roseTile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFEBB2BA), Color(0xFFD7919D)],
  );

  static const LinearGradient mauveTile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFBE8FA2), Color(0xFF93657D)],
  );

  static const LinearGradient ivoryTile = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF8EDE6), Color(0xFFF1E1DA)],
  );
}
