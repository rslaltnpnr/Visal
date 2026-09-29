// Ekran önizlemeleri (tasarım karşılaştırması için):
//   flutter test tool/render_screens_test.dart --update-goldens
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:visal/core/session/session_providers.dart';
import 'package:visal/core/theme/app_colors.dart';
import 'package:visal/core/theme/app_theme.dart';
import 'package:visal/features/auth/domain/app_user.dart';
import 'package:visal/features/auth/presentation/welcome_screen.dart';
import 'package:visal/features/calendar/data/plans_repository.dart';
import 'package:visal/features/calendar/domain/plan_models.dart';
import 'package:visal/features/home/presentation/home_screen.dart';
import 'package:visal/features/memories/data/memories_repository.dart';
import 'package:visal/features/pairing/domain/couple.dart';
import 'package:visal/features/profile/data/profile_repository.dart';
import 'package:visal/features/questions/data/questions_repository.dart';
import 'package:visal/features/questions/domain/question.dart';
import 'package:visal/features/questions/domain/question_bank.dart';

Future<void> loadAppFonts() async {
  final loader = FontLoader('PlusJakartaSans');
  for (final w in ['Light', 'Regular', 'Medium', 'SemiBold', 'Bold']) {
    loader.addFont(rootBundle.load('assets/fonts/PlusJakartaSans-$w.ttf'));
  }
  await loader.load();
  final icons = FontLoader('MaterialIcons')..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
  await icons.load();
}

final _now = DateTime.now();

final _overrides = [
  currentUidProvider.overrideWithValue('u1'),
  partnerIdProvider.overrideWithValue('u2'),
  coupleIdProvider.overrideWithValue('c1'),
  currentUserProvider.overrideWith((ref) => Stream.value(const AppUser(uid: 'u1', name: 'Resul', email: 'r@visal.app'))),
  coupleProvider.overrideWith((ref) => Stream.value(Couple(
        id: 'c1',
        members: const ['u1', 'u2'],
        relationshipStartDate: _now.subtract(const Duration(days: 1325)),
      ))),
  partnerProfileProvider.overrideWithValue(const MemberProfile(uid: 'u2', name: 'Ayşe')),
  unreadInboxProvider.overrideWithValue(true),
  memoryCountProvider.overrideWith((ref) async => 284),
  eventCountProvider.overrideWith((ref) async => 52),
  dailyQuestionIdProvider.overrideWith((ref) async => 'd_x'),
  questionProvider.overrideWith((ref, id) => Stream.value(const CoupleQuestion(
        id: 'd_x',
        text: 'Birlikte tekrar yaşamak istediğin gün hangisi?',
        category: QuestionCategory.romantic,
      ))),
  upcomingProvider.overrideWithValue([
    UpcomingItem(
      title: 'Yıldönümü',
      date: _now.add(const Duration(days: 23)),
      icon: Icons.favorite_rounded,
      color: AppColors.rose,
    ),
    UpcomingItem(
      title: 'Doğum günü',
      date: _now.add(const Duration(days: 59)),
      icon: Icons.card_giftcard_rounded,
      color: AppColors.mauve,
    ),
  ]),
  myMoodProvider.overrideWith((ref) => Stream.value(null)),
  partnerMoodProvider.overrideWith((ref) => Stream.value(Mood(uid: 'u2', day: 'x', emoji: '😊', createdAt: DateTime.now()))),
  onThisDayProvider.overrideWith((ref) => Stream.value(const [])),
];

Widget _app(Widget child, {bool dark = false}) => ProviderScope(
      overrides: _overrides,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: dark ? ThemeMode.dark : ThemeMode.light,
        home: child,
      ),
    );

void main() {
  setUpAll(() async {
    await loadAppFonts();
    await initializeDateFormatting('tr_TR');
  });

  Future<void> shot(WidgetTester tester, Widget w, String name, {double height = 1700}) async {
    tester.view.physicalSize = Size(393 * 2, height * 2);
    tester.view.devicePixelRatio = 2;
    tester.view.padding = const FakeViewPadding(top: 47 * 2, bottom: 34 * 2);
    await tester.pumpWidget(w);
    await tester.runAsync(() async {
      for (final e in find.byType(Image).evaluate()) {
        final img = e.widget as Image;
        await precacheImage(img.image, e);
      }
    });
    await tester.pump(const Duration(seconds: 3));
    await tester.pump(const Duration(seconds: 3));
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('goldens/$name.png'));
  }

  testWidgets('home light', (t) => shot(t, _app(const HomeScreen()), 'home_light'));
  testWidgets('home dark', (t) => shot(t, _app(const HomeScreen(), dark: true), 'home_dark'));
  testWidgets('welcome', (t) => shot(t, _app(const WelcomeScreen()), 'welcome', height: 852));
}
