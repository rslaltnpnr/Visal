import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/chat/presentation/chat_controller.dart';
import '../../features/chat/presentation/love_overlay.dart';
import '../services/notification_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';

class _Tab {
  const _Tab(this.label, this.icon, this.activeIcon);

  final String label;
  final IconData icon;
  final IconData activeIcon;
}

const _tabs = [
  _Tab('Biz', Icons.favorite_border_rounded, Icons.favorite_rounded),
  _Tab('Sohbet', Icons.chat_bubble_outline_rounded, Icons.chat_bubble_rounded),
  _Tab('Anılar', Icons.photo_outlined, Icons.photo_rounded),
  _Tab('Planlar', Icons.calendar_today_outlined, Icons.calendar_today_rounded),
  _Tab('Profil', Icons.person_outline_rounded, Icons.person_rounded),
];

/// Alt menü: Biz · Sohbet · Anılar · Planlar · Profil
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = navigationShell.currentIndex;
    ref.read(notificationServiceProvider).chatVisible = index == 1;
    final unread = ref.watch(unreadCountProvider);
    return LoveOverlayListener(
      child: Scaffold(
        body: navigationShell,
        bottomNavigationBar: _VisalNavBar(
          index: index,
          unread: index == 1 ? 0 : unread,
          onTap: (i) {
            HapticFeedback.selectionClick();
            navigationShell.goBranch(i, initialLocation: i == index);
          },
        ),
      ),
    );
  }
}

class _VisalNavBar extends StatelessWidget {
  const _VisalNavBar({required this.index, required this.onTap, required this.unread});

  final int index;
  final ValueChanged<int> onTap;
  final int unread;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final active = dark ? AppColors.rose : AppColors.wine;
    final inactive = dark ? AppColors.lavenderGrey : AppColors.textSecondary;
    return Container(
      decoration: BoxDecoration(
        color: dark ? AppColors.darkCard : AppColors.lightSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: context.palette.shadow,
            blurRadius: 30,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 74,
          child: Row(
            children: [
              for (var i = 0; i < _tabs.length; i++)
                Expanded(
                  child: InkResponse(
                    onTap: () => onTap(i),
                    radius: 36,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                          width: 52,
                          height: 34,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18),
                            color: i == index
                                ? AppColors.rose.withValues(alpha: dark ? 0.16 : 0.28)
                                : Colors.transparent,
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            alignment: Alignment.center,
                            children: [
                              Icon(
                                i == index ? _tabs[i].activeIcon : _tabs[i].icon,
                                color: i == index ? active : inactive,
                                size: 25,
                              ),
                              if (i == 1 && unread > 0)
                                Positioned(
                                  right: 6,
                                  top: -2,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    constraints: const BoxConstraints(minWidth: 18),
                                    decoration: BoxDecoration(
                                      color: AppColors.mauve,
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      unread > 9 ? '9+' : '$unread',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _tabs[i].label,
                          style: TextStyle(
                            fontFamily: kFontFamily,
                            fontSize: 12,
                            fontWeight: i == index ? FontWeight.w600 : FontWeight.w500,
                            color: i == index ? active : inactive,
                          ),
                        ),
                        const SizedBox(height: 3),
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 200),
                          opacity: i == index ? 1 : 0,
                          child: Container(
                            width: 4,
                            height: 4,
                            decoration: BoxDecoration(color: active, shape: BoxShape.circle),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
