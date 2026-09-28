import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/preferences_service.dart';
import '../../../core/widgets/common.dart';

class ThemeSettingsScreen extends ConsumerWidget {
  const ThemeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Tema')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          VisalCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: RadioGroup<ThemeMode>(
              groupValue: mode,
              onChanged: (m) => ref.read(themeModeProvider.notifier).set(m ?? ThemeMode.system),
              child: const Column(
                children: [
                  RadioListTile(value: ThemeMode.system, title: Text('Sistem'), subtitle: Text('Cihaz ayarını izle')),
                  RadioListTile(value: ThemeMode.light, title: Text('Açık'), subtitle: Text('Fildişi ve gül tonları')),
                  RadioListTile(value: ThemeMode.dark, title: Text('VISAL Dark'), subtitle: Text('Gece mürdümü')),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
