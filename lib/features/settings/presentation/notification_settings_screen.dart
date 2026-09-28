import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/notification_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import '../../profile/data/profile_repository.dart';
import '../domain/user_settings.dart';

class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() => _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState extends ConsumerState<NotificationSettingsScreen>
    with WidgetsBindingObserver {
  PermissionStatus? _status;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _check();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _check();
  }

  Future<void> _check() async {
    final s = await Permission.notification.status;
    if (mounted) setState(() => _status = s);
  }

  @override
  Widget build(BuildContext context) {
    final n = ref.watch(currentUserProvider).value?.settings.notifications ?? const NotificationSettings();
    Future<void> update(NotificationSettings v) async {
      try {
        await ref.read(profileRepositoryProvider).updateNotifications(v);
      } catch (e) {
        if (context.mounted) context.showError(e);
      }
    }

    final denied = _status != null && !_status!.isGranted && !_status!.isProvisional;
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (denied) ...[
            VisalCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bildirimler kapalı', style: context.text.titleSmall),
                  const SizedBox(height: 4),
                  Text(
                    'Partnerinden gelen mesajları kaçırmamak için bildirim iznini aç.',
                    style: context.text.bodySmall,
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton(
                    onPressed: () async {
                      final granted = await ref.read(notificationServiceProvider).requestPermission();
                      if (!granted) await openAppSettings();
                      _check();
                    },
                    child: const Text('İzin ver'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          VisalCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                SwitchListTile(
                  value: n.messages,
                  onChanged: (v) => update(n.copyWith(messages: v)),
                  title: const Text('Yeni mesaj'),
                ),
                SwitchListTile(
                  value: n.love,
                  onChanged: (v) => update(n.copyWith(love: v)),
                  title: const Text('Partner seni düşünüyor'),
                ),
                SwitchListTile(
                  value: n.memories,
                  onChanged: (v) => update(n.copyWith(memories: v)),
                  title: const Text('Yeni anı'),
                ),
                SwitchListTile(
                  value: n.capsules,
                  onChanged: (v) => update(n.copyWith(capsules: v)),
                  title: const Text('Kapsül açıldı'),
                ),
                SwitchListTile(
                  value: n.events,
                  onChanged: (v) => update(n.copyWith(events: v)),
                  title: const Text('Yaklaşan özel gün ve hatırlatmalar'),
                ),
                SwitchListTile(
                  value: n.dailyQuestion,
                  onChanged: (v) => update(n.copyWith(dailyQuestion: v)),
                  title: const Text('Günün sorusu'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
