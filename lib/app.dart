import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/router/app_router.dart';
import 'core/router/routes.dart';
import 'core/services/notification_service.dart';
import 'core/services/preferences_service.dart';
import 'core/services/presence_service.dart';
import 'core/services/supabase_providers.dart';
import 'core/session/session_providers.dart';
import 'core/theme/app_theme.dart';
import 'features/settings/presentation/lock_screen.dart';
import 'features/widgets/home_widget_service.dart';

class VisalApp extends ConsumerWidget {
  const VisalApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);
    return MaterialApp.router(
      title: 'VISAL',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: themeMode,
      routerConfig: router,
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => SessionEffects(
        child: AppLockGate(child: child ?? const SizedBox.shrink()),
      ),
    );
  }
}

/// Oturuma bağlı yan etkiler: FCM kaydı, presence, bildirim yönlendirmesi,
/// kullanıcı belgesinin garanti edilmesi.
class SessionEffects extends ConsumerStatefulWidget {
  const SessionEffects({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<SessionEffects> createState() => _SessionEffectsState();
}

class _SessionEffectsState extends ConsumerState<SessionEffects>
    with WidgetsBindingObserver {
  StreamSubscription<String>? _tapSub;
  StreamSubscription<AuthState>? _authSub;
  ProviderSubscription<HomeWidgetData>? _widgetSub;
  String? _registeredUid;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final notifications = ref.read(notificationServiceProvider);
    notifications.init();
    HomeWidgetService.init();
    _widgetSub = ref.listenManual(
      homeWidgetDataProvider,
      (_, next) => HomeWidgetService.push(next),
      fireImmediately: true,
    );
    _authSub = ref.read(supabaseProvider).auth.onAuthStateChange.listen((state) {
      if (state.event == AuthChangeEvent.passwordRecovery) {
        ref.read(routerProvider).push(Routes.resetPassword);
      }
    }, onError: (_) {});
    _tapSub = notifications.onTapRoute.listen((route) {
      final router = ref.read(routerProvider);
      if (route.startsWith('/home') ||
          route.startsWith('/chat') ||
          route.startsWith('/memories') ||
          route.startsWith('/plans') ||
          route.startsWith('/profile')) {
        router.go(route);
      } else {
        router.push(route);
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _tapSub?.cancel();
    _authSub?.cancel();
    _widgetSub?.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      resyncSessionFromStorage(ref.read(sharedPreferencesProvider), ref.read(supabaseProvider).auth);
    }
    final user = ref.read(currentUserProvider).value;
    final presence = ref.read(presenceServiceProvider);
    if (user == null || !user.isPaired) return;
    if (state == AppLifecycleState.resumed) {
      presence.goOnline(user.uid, user.coupleId!, user.settings.privacy);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      presence.goOffline();
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(authStateProvider, (prev, next) {
      final uid = next.value?.id;
      final prevUid = prev?.value?.id;
      if (uid != null && uid != _registeredUid) {
        _registeredUid = uid;
        ref.read(notificationServiceProvider).registerUser(uid);
      }
      if (uid == null && prevUid != null) {
        _registeredUid = null;
        ref.read(presenceServiceProvider).signOut();
      }
    });

    ref.listen(currentUserProvider, (prev, next) {
      final user = next.value;
      if (user != null && user.isPaired) {
        ref.read(presenceServiceProvider).goOnline(user.uid, user.coupleId!, user.settings.privacy);
      }
    });

    return widget.child;
  }
}

/// PIN / biyometrik uygulama kilidi. Uygulama açılışında ve arka plandan
/// belirli süre sonra dönüldüğünde içeriği örter.
class AppLockGate extends ConsumerStatefulWidget {
  const AppLockGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends ConsumerState<AppLockGate>
    with WidgetsBindingObserver {
  bool _locked = false;
  bool _obscured = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkInitial();
  }

  Future<void> _checkInitial() async {
    final enabled = await ref.read(appLockControllerProvider.notifier).isEnabled();
    if (enabled && mounted) setState(() => _locked = true);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) async {
    switch (state) {
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        final enabled = await ref.read(appLockControllerProvider.notifier).isEnabled();
        if (enabled && mounted) setState(() => _obscured = true);
      case AppLifecycleState.paused:
        _pausedAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        final enabled = await ref.read(appLockControllerProvider.notifier).isEnabled();
        final timeout = ref.read(preferencesProvider).lockTimeoutSeconds;
        final away = _pausedAt == null
            ? Duration.zero
            : DateTime.now().difference(_pausedAt!);
        _pausedAt = null;
        if (!mounted) return;
        setState(() {
          _obscured = false;
          if (enabled && away.inSeconds >= timeout) _locked = true;
        });
      case AppLifecycleState.detached:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_obscured && !_locked) const Positioned.fill(child: PrivacyCurtain()),
        if (_locked)
          Positioned.fill(
            child: LockScreen(onUnlocked: () => setState(() => _locked = false)),
          ),
      ],
    );
  }
}
