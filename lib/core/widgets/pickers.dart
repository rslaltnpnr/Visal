import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/date_x.dart';

Future<DateTime?> pickDate(
  BuildContext context, {
  DateTime? initial,
  DateTime? first,
  DateTime? last,
  String? help,
}) {
  final now = DateTime.now();
  return showDatePicker(
    context: context,
    initialDate: initial ?? now,
    firstDate: first ?? DateTime(1950),
    lastDate: last ?? DateTime(now.year + 20),
    helpText: help,
    locale: const Locale('tr', 'TR'),
    builder: (context, child) => Theme(
      data: Theme.of(context).copyWith(
        colorScheme: Theme.of(context).colorScheme.copyWith(
              primary: context.isDark ? AppColors.rose : AppColors.plum,
              onPrimary: context.isDark ? AppColors.midnight : Colors.white,
            ),
      ),
      child: child!,
    ),
  );
}

Future<TimeOfDay?> pickTime(BuildContext context, {TimeOfDay? initial}) => showTimePicker(
      context: context,
      initialTime: initial ?? TimeOfDay.now(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

/// Form içinde tarih/saat gösteren dokunulabilir alan.
class PickerField extends StatelessWidget {
  const PickerField({
    super.key,
    required this.label,
    required this.value,
    required this.onTap,
    this.icon = Icons.calendar_today_outlined,
    this.onClear,
  });

  final String label;
  final String? value;
  final VoidCallback onTap;
  final IconData icon;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppRadii.field),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, size: 20),
          suffixIcon: onClear != null && value != null
              ? IconButton(onPressed: onClear, icon: const Icon(Icons.close_rounded, size: 18))
              : null,
        ),
        child: Text(
          value ?? 'Seç',
          style: context.text.bodyLarge?.copyWith(
            color: value == null ? context.palette.muted : null,
          ),
        ),
      ),
    );
  }
}

String? formatDateOrNull(DateTime? d) => d?.dMMMMy;

/// Anı/etkinlik için hızlı emoji seçimi.
class EmojiChoice extends StatelessWidget {
  const EmojiChoice({super.key, required this.value, required this.onChanged, this.options = kMemoryEmojis});

  final String? value;
  final ValueChanged<String?> onChanged;
  final List<String> options;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in options)
          GestureDetector(
            onTap: () => onChanged(value == e ? null : e),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: value == e ? AppColors.rose.withValues(alpha: 0.35) : context.palette.card,
                border: Border.all(
                  color: value == e ? AppColors.mauve : Theme.of(context).colorScheme.outlineVariant,
                ),
              ),
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          ),
      ],
    );
  }
}

const kMemoryEmojis = ['❤️', '🌹', '✨', '🥂', '🏖️', '🏔️', '🎂', '🎶', '🍷', '☕', '🌙', '📸'];
