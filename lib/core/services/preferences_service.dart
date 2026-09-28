import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// main.dart içinde override edilir.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (_) => throw UnimplementedError('SharedPreferences override edilmedi'),
);

final preferencesProvider = Provider<PreferencesService>(
  (ref) => PreferencesService(ref.watch(sharedPreferencesProvider)),
);

class PreferencesService {
  PreferencesService(this._prefs);

  final SharedPreferences _prefs;

  static const _onboardingSeen = 'onboarding_seen';
  static const _themeMode = 'theme_mode';
  static const _celebrated = 'celebrated_couple_';
  static const _lockTimeout = 'lock_timeout_seconds';
  static const _memoriesGrid = 'memories_grid';

  bool get onboardingSeen => _prefs.getBool(_onboardingSeen) ?? false;
  Future<void> setOnboardingSeen() => _prefs.setBool(_onboardingSeen, true);

  ThemeMode get themeMode => ThemeMode.values.firstWhere(
        (m) => m.name == _prefs.getString(_themeMode),
        orElse: () => ThemeMode.system,
      );
  Future<void> setThemeMode(ThemeMode mode) =>
      _prefs.setString(_themeMode, mode.name);

  bool isCelebrated(String coupleId) =>
      _prefs.getBool('$_celebrated$coupleId') ?? false;
  Future<void> setCelebrated(String coupleId) =>
      _prefs.setBool('$_celebrated$coupleId', true);

  /// Arka plandan dönüldüğünde kilidin devreye gireceği süre.
  int get lockTimeoutSeconds => _prefs.getInt(_lockTimeout) ?? 30;
  Future<void> setLockTimeoutSeconds(int s) => _prefs.setInt(_lockTimeout, s);

  bool get memoriesGrid => _prefs.getBool(_memoriesGrid) ?? false;
  Future<void> setMemoriesGrid(bool v) => _prefs.setBool(_memoriesGrid, v);
}

class ThemeModeController extends Notifier<ThemeMode> {
  @override
  ThemeMode build() => ref.watch(preferencesProvider).themeMode;

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref.read(preferencesProvider).setThemeMode(mode);
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeController, ThemeMode>(ThemeModeController.new);
