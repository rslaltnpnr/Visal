import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:visal/core/demo/demo_mode.dart';
import 'package:visal/core/services/firebase_providers.dart';
import 'package:visal/core/services/preferences_service.dart';
import 'package:visal/core/theme/app_theme.dart';
import 'package:visal/features/calendar/presentation/plans_screen.dart';
import 'package:visal/features/capsules/presentation/capsules_screen.dart';
import 'package:visal/features/chat/presentation/chat_screen.dart';
import 'package:visal/features/home/presentation/home_screen.dart';
import 'package:visal/features/memories/presentation/memories_screen.dart';
import 'package:visal/features/profile/presentation/profile_screen.dart';
import 'package:visal/features/questions/presentation/questions_screen.dart';

/// Demo modunun sahte veritabanıyla ana ekranların hatasız açıldığını doğrular.
void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    final tmp = Directory.systemTemp.createTempSync('visal_test').path;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      const MethodChannel('plugins.flutter.io/path_provider'),
      (_) async => tmp,
    );
    await initializeDateFormatting('tr_TR');
  });

  final screens = <String, Widget>{
    'Biz': const HomeScreen(),
    'Sohbet': const ChatScreen(),
    'Anılar': const MemoriesScreen(),
    'Planlar': const PlansScreen(),
    'Sorular': const QuestionsScreen(),
    'Kapsüller': const CapsulesScreen(),
    'Profil': const ProfileScreen(),
  };

  for (final entry in screens.entries) {
    testWidgets('demo: ${entry.key} ekranı açılır', (tester) async {
      tester.view.physicalSize = const Size(1179, 2556);
      tester.view.devicePixelRatio = 3;
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final overrides = await tester.runAsync(demoOverrides);
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs), ...overrides!],
      );
      addTearDown(container.dispose);
      await tester.runAsync(
        () =>
            container.read(firebaseAuthProvider).signInWithEmailAndPassword(email: kDemoEmail, password: kDemoPassword),
      );
      {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(theme: AppTheme.light(), home: entry.value),
          ),
        );
        for (var i = 0; i < 10; i++) {
          await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 50)));
          await tester.pump(const Duration(milliseconds: 200));
        }
      }
      // Test ortamında ağ yok: örnek fotoğrafların 400 dönmesi beklenen durum.
      final error = tester.takeException();
      expect(error == null || error is HttpException, isTrue, reason: '$error');
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 15)); // görsel önbelleği temizlik zamanlayıcısı
    });
  }
}
