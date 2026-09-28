import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/forgot_password_screen.dart';
import '../../features/auth/presentation/launch_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/onboarding_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/auth/presentation/welcome_screen.dart';
import '../../features/calendar/presentation/event_editor_screen.dart';
import '../../features/calendar/presentation/plans_screen.dart';
import '../../features/capsules/presentation/capsule_detail_screen.dart';
import '../../features/capsules/presentation/capsule_editor_screen.dart';
import '../../features/capsules/presentation/capsules_screen.dart';
import '../../features/chat/presentation/chat_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/home/presentation/notifications_screen.dart';
import '../../features/memories/presentation/memories_screen.dart';
import '../../features/memories/presentation/memory_detail_screen.dart';
import '../../features/memories/presentation/memory_editor_screen.dart';
import '../../features/memories/presentation/story_screen.dart';
import '../../features/pairing/presentation/enter_code_screen.dart';
import '../../features/pairing/presentation/invite_screen.dart';
import '../../features/pairing/presentation/pair_request_screen.dart';
import '../../features/pairing/presentation/paired_celebration_screen.dart';
import '../../features/pairing/presentation/pairing_screen.dart';
import '../../features/pairing/presentation/scan_code_screen.dart';
import '../../features/profile/presentation/edit_profile_screen.dart';
import '../../features/profile/presentation/profile_screen.dart';
import '../../features/profile/presentation/relationship_screen.dart';
import '../../features/questions/presentation/question_detail_screen.dart';
import '../../features/questions/presentation/questions_screen.dart';
import '../../features/settings/presentation/account_screen.dart';
import '../../features/settings/presentation/app_lock_settings_screen.dart';
import '../../features/settings/presentation/notification_settings_screen.dart';
import '../../features/settings/presentation/partner_management_screen.dart';
import '../../features/settings/presentation/privacy_settings_screen.dart';
import '../../features/settings/presentation/settings_screen.dart';
import '../../features/settings/presentation/theme_settings_screen.dart';
import '../services/preferences_service.dart';
import '../session/session_providers.dart';
import '../widgets/media_viewer.dart';
import 'app_shell.dart';
import 'routes.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'root');

/// Oturum/eşleşme durumu değiştikçe yönlendirmeyi yeniden değerlendirir.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen(authStateProvider, (_, _) => notifyListeners());
    ref.listen(currentUserProvider, (_, _) => notifyListeners());
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  Page<void> fade(GoRouterState s, Widget child) => CustomTransitionPage<void>(
        key: s.pageKey,
        child: child,
        transitionDuration: const Duration(milliseconds: 450),
        transitionsBuilder: (_, a, _, c) =>
            FadeTransition(opacity: CurvedAnimation(parent: a, curve: Curves.easeOut), child: c),
      );

  GoRoute detail(String path, Widget Function(GoRouterState s) builder) => GoRoute(
        path: path,
        parentNavigatorKey: rootNavigatorKey,
        builder: (_, s) => builder(s),
      );

  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: Routes.launch,
    refreshListenable: refresh,
    debugLogDiagnostics: false,
    redirect: (context, state) {
      final auth = ref.read(authStateProvider);
      final loc = state.matchedLocation;

      if (auth.isLoading && !auth.hasValue) return Routes.launch;
      final user = auth.value;

      if (user == null) {
        if (Routes.publicRoutes.contains(loc)) return null;
        return Routes.welcome;
      }

      final profile = ref.read(currentUserProvider);
      final appUser = profile.value;
      if (appUser == null) {
        // users/{uid} yükleniyor veya oluşturuluyor.
        return loc == Routes.launch ? null : Routes.launch;
      }

      final isPairingRoute = loc.startsWith(Routes.pairing);
      if (!appUser.isPaired) {
        return isPairingRoute ? null : Routes.pairing;
      }

      final prefs = ref.read(preferencesProvider);
      if (!prefs.isCelebrated(appUser.coupleId!)) {
        return loc == Routes.paired ? null : Routes.paired;
      }

      if (loc == Routes.launch ||
          isPairingRoute ||
          Routes.publicRoutes.contains(loc)) {
        return Routes.home;
      }
      return null;
    },
    routes: [
      GoRoute(path: Routes.launch, builder: (_, _) => const LaunchScreen()),
      GoRoute(
        path: Routes.welcome,
        pageBuilder: (_, s) => fade(s, const WelcomeScreen()),
      ),
      GoRoute(
        path: Routes.onboarding,
        pageBuilder: (_, s) => fade(s, const OnboardingScreen()),
      ),
      GoRoute(path: Routes.login, builder: (_, _) => const LoginScreen()),
      GoRoute(path: Routes.register, builder: (_, _) => const RegisterScreen()),
      GoRoute(path: Routes.forgot, builder: (_, _) => const ForgotPasswordScreen()),

      // Eşleşme
      GoRoute(
        path: Routes.pairing,
        pageBuilder: (_, s) => fade(s, const PairingScreen()),
        routes: [
          GoRoute(path: 'invite', builder: (_, _) => const InviteScreen()),
          GoRoute(
            path: 'enter',
            builder: (_, s) => EnterCodeScreen(initialCode: s.uri.queryParameters['code']),
          ),
          GoRoute(path: 'scan', builder: (_, _) => const ScanCodeScreen()),
          GoRoute(
            path: 'request/:id',
            builder: (_, s) => PairRequestScreen(requestId: s.pathParameters['id']!),
          ),
        ],
      ),
      GoRoute(
        path: Routes.paired,
        pageBuilder: (_, s) => fade(s, const PairedCelebrationScreen()),
      ),

      // Ana sekmeler
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => AppShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.home, builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.chat, builder: (_, _) => const ChatScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.memories, builder: (_, _) => const MemoriesScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(
              path: Routes.plans,
              builder: (_, s) => PlansScreen(initialTab: s.uri.queryParameters['tab']),
            ),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: Routes.profile, builder: (_, _) => const ProfileScreen()),
          ]),
        ],
      ),

      // Detay ekranları (alt menü olmadan)
      detail(Routes.notifications, (_) => const NotificationsScreen()),
      detail(Routes.memoryNew, (_) => const MemoryEditorScreen()),
      detail('/memory/:id', (s) => MemoryDetailScreen(memoryId: s.pathParameters['id']!)),
      detail('/memory/:id/edit', (s) => MemoryEditorScreen(memoryId: s.pathParameters['id'])),
      detail(Routes.story, (_) => const StoryScreen()),
      detail(Routes.capsules, (_) => const CapsulesScreen()),
      detail(Routes.capsuleNew, (_) => const CapsuleEditorScreen()),
      detail('/capsule/:id', (s) => CapsuleDetailScreen(capsuleId: s.pathParameters['id']!)),
      detail(Routes.questions, (_) => const QuestionsScreen()),
      detail('/question/:id', (s) => QuestionDetailScreen(questionId: s.pathParameters['id']!)),
      detail(Routes.eventNew, (s) => EventEditorScreen(initialDate: s.extra as DateTime?)),
      detail('/event/:id', (s) => EventEditorScreen(eventId: s.pathParameters['id'])),
      detail(Routes.settings, (_) => const SettingsScreen()),
      detail(Routes.settingsPrivacy, (_) => const PrivacySettingsScreen()),
      detail(Routes.settingsNotifications, (_) => const NotificationSettingsScreen()),
      detail(Routes.settingsLock, (_) => const AppLockSettingsScreen()),
      detail(Routes.settingsPartner, (_) => const PartnerManagementScreen()),
      detail(Routes.settingsAccount, (_) => const AccountScreen()),
      detail(Routes.settingsTheme, (_) => const ThemeSettingsScreen()),
      detail(Routes.profileEdit, (_) => const EditProfileScreen()),
      detail(Routes.relationship, (_) => const RelationshipScreen()),
      GoRoute(
        path: Routes.mediaViewer,
        parentNavigatorKey: rootNavigatorKey,
        pageBuilder: (_, s) => fade(s, MediaViewerScreen(args: s.extra! as MediaViewerArgs)),
      ),
    ],
  );
});
