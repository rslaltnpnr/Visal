import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../domain/message.dart';

/// ❤️ Seni seviyorum · 🥺 Özledim · 🏠 Eve geliyorum ...
class QuickLoveBar extends StatelessWidget {
  const QuickLoveBar({super.key, required this.onSend});

  final ValueChanged<LoveKind> onSend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: LoveKind.values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final kind = LoveKind.values[i];
          return Material(
            color: context.isDark ? AppColors.darkElevated : Colors.white,
            shape: StadiumBorder(
              side: BorderSide(color: AppColors.rose.withValues(alpha: context.isDark ? 0.25 : 0.5)),
            ),
            child: InkWell(
              customBorder: const StadiumBorder(),
              onTap: () {
                HapticFeedback.lightImpact();
                onSend(kind);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: Center(
                  child: Text(
                    kind.text,
                    style: context.text.labelMedium?.copyWith(color: context.palette.textPrimary),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
