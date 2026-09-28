import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../profile/data/profile_repository.dart';

/// Bildirim kutusu (zil ikonu).
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  bool _marked = false;

  static IconData _icon(String type) => switch (type) {
        'message' => Icons.chat_bubble_outline_rounded,
        'love' => Icons.favorite_rounded,
        'memory' => Icons.photo_outlined,
        'capsule' => Icons.hourglass_bottom_rounded,
        'event' => Icons.event_outlined,
        'question' => Icons.help_outline_rounded,
        'pairing' => Icons.link_rounded,
        _ => Icons.notifications_none_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final inbox = ref.watch(inboxProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Bildirimler')),
      body: AsyncView(
        value: inbox,
        data: (items) {
          if (!_marked && items.isNotEmpty) {
            _marked = true;
            Future.delayed(const Duration(seconds: 1), () => markInboxRead(ref, items));
          }
          if (items.isEmpty) {
            return const EmptyState(
              icon: Icons.notifications_none_rounded,
              title: 'Henüz bildirim yok',
              message: 'Yeni anılar, açılan kapsüller ve yaklaşan özel günler burada görünür.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: items.length,
            separatorBuilder: (_, _) => const Divider(indent: 76),
            itemBuilder: (context, i) {
              final item = items[i];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
                leading: SoftIcon(_icon(item.type), size: 44),
                title: Text(
                  item.title,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: item.read ? FontWeight.w500 : FontWeight.w700,
                  ),
                ),
                subtitle: Text(item.body, maxLines: 2, overflow: TextOverflow.ellipsis),
                trailing: item.createdAt == null
                    ? null
                    : Text(relativeLabel(item.createdAt!), style: context.text.labelSmall),
                onTap: item.route == null ? null : () => context.push(item.route!),
              );
            },
          );
        },
      ),
    );
  }
}
