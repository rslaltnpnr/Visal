import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_colors.dart';

/// Ölçü sabitleri.
abstract final class AppRadii {
  static const double card = 24;
  static const double cardLarge = 28;
  static const double tile = 20;
  static const double button = 28;
  static const double field = 18;
}

abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double page = 20;
}

const String kFontFamily = 'PlusJakartaSans';

/// Temaya bağlı ek renkler.
@immutable
class VisalPalette extends ThemeExtension<VisalPalette> {
  const VisalPalette({
    required this.card,
    required this.cardBorder,
    required this.textPrimary,
    required this.textSecondary,
    required this.muted,
    required this.bubbleMine,
    required this.bubbleMineText,
    required this.bubbleTheirs,
    required this.bubbleTheirsText,
    required this.chatBackground,
    required this.softAccent,
    required this.shadow,
  });

  final Color card;
  final Color cardBorder;
  final Color textPrimary;
  final Color textSecondary;
  final Color muted;
  final Gradient bubbleMine;
  final Color bubbleMineText;
  final Color bubbleTheirs;
  final Color bubbleTheirsText;
  final Color chatBackground;
  final Color softAccent;
  final Color shadow;

  static const light = VisalPalette(
    card: AppColors.lightCard,
    cardBorder: Color(0x0F281725),
    textPrimary: AppColors.textPrimary,
    textSecondary: AppColors.textSecondary,
    muted: AppColors.lavenderGrey,
    bubbleMine: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFEDB6BF), Color(0xFFE2A0AC)],
    ),
    bubbleMineText: AppColors.textPrimary,
    bubbleTheirs: Colors.white,
    bubbleTheirsText: AppColors.textPrimary,
    chatBackground: AppColors.ivory,
    softAccent: AppColors.blush,
    shadow: Color(0x14281725),
  );

  static const dark = VisalPalette(
    card: AppColors.darkCard,
    cardBorder: Color(0x14F8F4EF),
    textPrimary: AppColors.darkText,
    textSecondary: AppColors.darkTextSecondary,
    muted: AppColors.lavenderGrey,
    bubbleMine: LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFFD993A0), Color(0xFFB27A90)],
    ),
    bubbleMineText: AppColors.midnight,
    bubbleTheirs: Color(0xFF2A1F31),
    bubbleTheirsText: AppColors.darkText,
    chatBackground: AppColors.darkBackground,
    softAccent: Color(0xFF2B1E2F),
    shadow: Color(0x40000000),
  );

  @override
  VisalPalette copyWith() => this;

  @override
  VisalPalette lerp(ThemeExtension<VisalPalette>? other, double t) =>
      t < 0.5 ? this : (other as VisalPalette? ?? this);
}

extension VisalThemeX on BuildContext {
  VisalPalette get palette => Theme.of(this).extension<VisalPalette>()!;
  ThemeData get theme => Theme.of(this);
  TextTheme get text => Theme.of(this).textTheme;
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
}

abstract final class AppTheme {
  static TextTheme _textTheme(Color primary, Color secondary) {
    TextStyle s(double size, FontWeight w, {Color? c, double? h, double? ls}) =>
        TextStyle(
          fontFamily: kFontFamily,
          fontSize: size,
          fontWeight: w,
          color: c ?? primary,
          height: h,
          letterSpacing: ls,
        );
    return TextTheme(
      displayLarge: s(48, FontWeight.w600, h: 1.05, ls: -1),
      displayMedium: s(38, FontWeight.w600, h: 1.1, ls: -0.8),
      displaySmall: s(30, FontWeight.w600, h: 1.15, ls: -0.5),
      headlineLarge: s(28, FontWeight.w600, h: 1.2, ls: -0.4),
      headlineMedium: s(24, FontWeight.w600, h: 1.25, ls: -0.3),
      headlineSmall: s(21, FontWeight.w600, h: 1.3, ls: -0.2),
      titleLarge: s(19, FontWeight.w600, h: 1.3),
      titleMedium: s(16, FontWeight.w600, h: 1.35),
      titleSmall: s(14, FontWeight.w600, h: 1.35),
      bodyLarge: s(16, FontWeight.w400, h: 1.5),
      bodyMedium: s(14.5, FontWeight.w400, h: 1.5),
      bodySmall: s(12.5, FontWeight.w400, c: secondary, h: 1.45),
      labelLarge: s(15, FontWeight.w600, ls: 0.2),
      labelMedium: s(13, FontWeight.w500, c: secondary),
      labelSmall: s(11, FontWeight.w500, c: secondary, ls: 0.3),
    );
  }

  static ThemeData light() {
    const scheme = ColorScheme(
      brightness: Brightness.light,
      primary: AppColors.midnight,
      onPrimary: AppColors.ivory,
      secondary: AppColors.rose,
      onSecondary: AppColors.midnight,
      tertiary: AppColors.mauve,
      onTertiary: Colors.white,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.lightSurface,
      onSurface: AppColors.textPrimary,
      surfaceContainerHighest: AppColors.blush,
      outline: AppColors.lavenderGrey,
      outlineVariant: AppColors.divider,
    );
    return _base(scheme, VisalPalette.light, AppColors.ivory,
        _textTheme(AppColors.textPrimary, AppColors.textSecondary));
  }

  static ThemeData dark() {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: AppColors.rose,
      onPrimary: AppColors.midnight,
      secondary: AppColors.rose,
      onSecondary: AppColors.midnight,
      tertiary: AppColors.mauve,
      onTertiary: AppColors.midnight,
      error: AppColors.error,
      onError: Colors.white,
      surface: AppColors.darkCard,
      onSurface: AppColors.darkText,
      surfaceContainerHighest: AppColors.darkElevated,
      outline: AppColors.lavenderGrey,
      outlineVariant: AppColors.darkDivider,
    );
    return _base(scheme, VisalPalette.dark, AppColors.darkBackground,
        _textTheme(AppColors.darkText, AppColors.darkTextSecondary));
  }

  static ThemeData _base(
    ColorScheme scheme,
    VisalPalette palette,
    Color scaffold,
    TextTheme text,
  ) {
    final isDark = scheme.brightness == Brightness.dark;
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: kFontFamily,
      scaffoldBackgroundColor: scaffold,
      textTheme: text,
      extensions: [palette],
      splashFactory: InkSparkle.splashFactory,
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: scaffold,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        foregroundColor: palette.textPrimary,
        titleTextStyle: text.titleLarge,
        systemOverlayStyle:
            isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant,
        thickness: 1,
        space: 1,
      ),
      cardTheme: CardThemeData(
        color: palette.card,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadii.card),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? AppColors.darkElevated : Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        hintStyle: text.bodyMedium?.copyWith(color: palette.muted),
        labelStyle: text.bodyMedium?.copyWith(color: palette.textSecondary),
        floatingLabelStyle:
            text.bodySmall?.copyWith(color: palette.textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.mauve, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadii.field),
          borderSide: const BorderSide(color: AppColors.error),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: isDark ? AppColors.rose : AppColors.midnight,
          foregroundColor: isDark ? AppColors.midnight : AppColors.ivory,
          minimumSize: const Size(64, 54),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: palette.textPrimary,
          minimumSize: const Size(64, 54),
          side: BorderSide(color: scheme.outlineVariant),
          textStyle: text.labelLarge,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadii.button),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: isDark ? AppColors.rose : AppColors.wine,
          textStyle: text.labelLarge,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: palette.card,
        selectedColor: isDark ? AppColors.rose : AppColors.midnight,
        labelStyle: text.labelMedium,
        secondaryLabelStyle: text.labelMedium?.copyWith(
          color: isDark ? AppColors.midnight : AppColors.ivory,
        ),
        side: BorderSide(color: scheme.outlineVariant),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        showCheckmark: false,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: palette.muted.withValues(alpha: 0.4),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: isDark ? AppColors.darkCard : AppColors.lightSurface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        titleTextStyle: text.titleLarge,
        contentTextStyle: text.bodyMedium,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? AppColors.darkElevated : AppColors.midnight,
        contentTextStyle: text.bodyMedium?.copyWith(color: AppColors.ivory),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? Colors.white : null,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? AppColors.mauve : null,
        ),
        trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.mauve,
        linearTrackColor: Color(0x33B68AA0),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: palette.textSecondary,
        titleTextStyle: text.bodyLarge,
        subtitleTextStyle: text.bodySmall,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      cupertinoOverrideTheme: const CupertinoThemeData(
        primaryColor: AppColors.mauve,
      ),
    );
  }
}
