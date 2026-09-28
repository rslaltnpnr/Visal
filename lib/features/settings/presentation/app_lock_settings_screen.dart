import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_lock_service.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/common.dart';
import 'lock_screen.dart';

class AppLockSettingsScreen extends ConsumerWidget {
  const AppLockSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appLockControllerProvider);
    final prefs = ref.watch(preferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Uygulama Kilidi')),
      body: AsyncView(
        value: state,
        data: (s) {
          final bioLabel = switch (s.kind) {
            BiometricKind.face => 'Face ID',
            BiometricKind.fingerprint => 'Parmak izi',
            BiometricKind.none => 'Biyometrik',
          };
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
            children: [
              VisalCard(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Column(
                  children: [
                    SwitchListTile(
                      value: s.enabled,
                      title: const Text('PIN ile kilitle'),
                      subtitle: const Text('Uygulama açılırken 4 haneli PIN iste'),
                      onChanged: (v) async {
                        if (v) {
                          final pin = await Navigator.of(context).push<String>(
                            MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                          );
                          if (pin != null) await ref.read(appLockControllerProvider.notifier).setPin(pin);
                        } else {
                          await ref.read(appLockControllerProvider.notifier).disable();
                        }
                      },
                    ),
                    if (s.enabled && s.kind != BiometricKind.none)
                      SwitchListTile(
                        value: s.biometric,
                        title: Text('$bioLabel ile aç'),
                        onChanged: (v) async {
                          final ok = await ref.read(appLockControllerProvider.notifier).setBiometric(v);
                          if (!ok && context.mounted) context.showSnack('Doğrulama başarısız');
                        },
                      ),
                    if (s.enabled)
                      ListTile(
                        title: const Text('PIN\'i değiştir'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final pin = await Navigator.of(context).push<String>(
                            MaterialPageRoute(builder: (_) => const PinSetupScreen()),
                          );
                          if (pin != null) await ref.read(appLockControllerProvider.notifier).setPin(pin);
                        },
                      ),
                  ],
                ),
              ),
              if (s.enabled) ...[
                const SizedBox(height: 20),
                Text('Otomatik kilit', style: context.text.titleMedium),
                const SizedBox(height: 10),
                VisalCard(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: StatefulBuilder(
                    builder: (context, setState) => RadioGroup<int>(
                      groupValue: prefs.lockTimeoutSeconds,
                      onChanged: (v) async {
                        await prefs.setLockTimeoutSeconds(v ?? 30);
                        setState(() {});
                      },
                      child: const Column(
                        children: [
                          RadioListTile<int>(value: 0, title: Text('Hemen')),
                          RadioListTile<int>(value: 30, title: Text('30 saniye sonra')),
                          RadioListTile<int>(value: 300, title: Text('5 dakika sonra')),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

/// PIN'i iki kez girerek belirleme.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _first = '';
  String _pin = '';
  bool _confirming = false;
  bool _error = false;

  void _digit(String d) {
    if (_pin.length >= kPinLength) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = false;
    });
    if (_pin.length < kPinLength) return;
    if (!_confirming) {
      setState(() {
        _first = _pin;
        _pin = '';
        _confirming = true;
      });
    } else if (_pin == _first) {
      Navigator.pop(context, _pin);
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _pin = '';
        _first = '';
        _confirming = false;
        _error = true;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(),
            Text(_confirming ? 'PIN\'i tekrar gir' : 'Yeni PIN belirle', style: context.text.headlineSmall),
            const SizedBox(height: 8),
            Text(
              _error ? 'PIN\'ler eşleşmedi, baştan dene' : '4 haneli bir PIN seç',
              style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
            ),
            const SizedBox(height: 28),
            PinDots(length: _pin.length, error: _error, dark: false),
            const Spacer(),
            PinPad(
              dark: false,
              onDigit: _digit,
              onDelete: () {
                if (_pin.isNotEmpty) setState(() => _pin = _pin.substring(0, _pin.length - 1));
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
