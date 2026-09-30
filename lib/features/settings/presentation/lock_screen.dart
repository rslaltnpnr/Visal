import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/app_lock_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/visal_logo.dart';

class AppLockState {
  const AppLockState({this.enabled = false, this.biometric = false, this.kind = BiometricKind.none});

  final bool enabled;
  final bool biometric;
  final BiometricKind kind;
}

class AppLockController extends AsyncNotifier<AppLockState> {
  AppLockService get _service => ref.read(appLockServiceProvider);

  @override
  Future<AppLockState> build() async {
    final service = ref.watch(appLockServiceProvider);
    return AppLockState(
      enabled: await service.isLockEnabled(),
      biometric: await service.isBiometricEnabled(),
      kind: await service.availableBiometric(),
    );
  }

  Future<bool> isEnabled() => _service.isLockEnabled();

  Future<void> setPin(String pin) async {
    await _service.setPin(pin);
    ref.invalidateSelf();
  }

  Future<void> disable() async {
    await _service.disableLock();
    ref.invalidateSelf();
  }

  Future<bool> setBiometric(bool enabled) async {
    if (enabled && !await _service.authenticateBiometric()) return false;
    await _service.setBiometricEnabled(enabled);
    ref.invalidateSelf();
    return true;
  }
}

final appLockControllerProvider =
    AsyncNotifierProvider<AppLockController, AppLockState>(AppLockController.new);

const kPinLength = 4;

/// Uygulama değiştiricide içerik görünmesin diye örtü.
class PrivacyCurtain extends StatelessWidget {
  const PrivacyCurtain({super.key});

  @override
  Widget build(BuildContext context) => const DecoratedBox(
        decoration: BoxDecoration(gradient: AppColors.deepGradient),
        child: Center(child: VisalMark(size: 96)),
      );
}

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String _pin = '';
  bool _error = false;
  bool _busy = false;
  DateTime? _lockedUntil;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _restoreLockout();
      await _tryBiometric();
    });
  }

  Future<void> _restoreLockout() async {
    final until = await ref.read(appLockServiceProvider).lockoutUntil();
    if (mounted) setState(() => _lockedUntil = until);
  }

  Future<void> _tryBiometric() async {
    final service = ref.read(appLockServiceProvider);
    if (!await service.isBiometricEnabled()) return;
    if (await service.authenticateBiometric()) widget.onUnlocked();
  }

  Future<void> _onDigit(String d) async {
    if (_busy || _pin.length >= kPinLength) return;
    if (_lockedUntil != null && DateTime.now().isBefore(_lockedUntil!)) return;
    HapticFeedback.selectionClick();
    setState(() {
      _pin += d;
      _error = false;
      if (_lockedUntil != null && !DateTime.now().isBefore(_lockedUntil!)) {
        _lockedUntil = null;
      }
    });
    if (_pin.length == kPinLength) {
      setState(() => _busy = true);
      final service = ref.read(appLockServiceProvider);
      final ok = await service.verifyPin(_pin);
      if (!mounted) return;
      if (ok) {
        widget.onUnlocked();
        return;
      }
      HapticFeedback.heavyImpact();
      final until = await service.lockoutUntil();
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = true;
        _pin = '';
        _lockedUntil = until;
      });
    }
  }

  void _onDelete() {
    if (_pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final lockState = ref.watch(appLockControllerProvider).value;
    final waiting = _lockedUntil != null && DateTime.now().isBefore(_lockedUntil!);
    return Material(
      child: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.deepGradient),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: SafeArea(
            child: Column(
              children: [
                const Spacer(flex: 2),
                const VisalMark(size: 72),
                const SizedBox(height: 22),
                Text(
                  'VISAL kilitli',
                  style: context.text.headlineSmall?.copyWith(color: AppColors.ivory),
                ),
                const SizedBox(height: 8),
                Text(
                  waiting
                      ? 'Çok fazla hatalı deneme. Biraz bekleyin.'
                      : _error
                          ? 'PIN hatalı, tekrar deneyin'
                          : 'Devam etmek için PIN\'inizi girin',
                  style: context.text.bodyMedium?.copyWith(
                    color: _error ? AppColors.rose : AppColors.ivory.withValues(alpha: 0.7),
                  ),
                ),
                const SizedBox(height: 30),
                PinDots(length: _pin.length, error: _error),
                const Spacer(),
                PinPad(
                  onDigit: _onDigit,
                  onDelete: _onDelete,
                  biometricKind:
                      (lockState?.biometric ?? false) ? lockState!.kind : BiometricKind.none,
                  onBiometric: _tryBiometric,
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.length, this.error = false, this.dark = true});

  final int length;
  final bool error;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final base = dark ? AppColors.ivory : context.palette.textPrimary;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(kPinLength, (i) {
        final filled = i < length;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          margin: const EdgeInsets.symmetric(horizontal: 10),
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: error
                ? AppColors.error
                : filled
                    ? AppColors.rose
                    : Colors.transparent,
            border: Border.all(color: filled ? AppColors.rose : base.withValues(alpha: 0.5), width: 1.4),
          ),
        );
      }),
    );
  }
}

class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onDelete,
    this.biometricKind = BiometricKind.none,
    this.onBiometric,
    this.dark = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final BiometricKind biometricKind;
  final VoidCallback? onBiometric;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final fg = dark ? AppColors.ivory : context.palette.textPrimary;
    Widget key(String label) => _PadKey(
          onTap: () => onDigit(label),
          dark: dark,
          child: Text(
            label,
            style: TextStyle(fontFamily: kFontFamily, fontSize: 28, fontWeight: FontWeight.w300, color: fg),
          ),
        );
    Widget row(List<Widget> c) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: c),
        );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        children: [
          row([key('1'), key('2'), key('3')]),
          row([key('4'), key('5'), key('6')]),
          row([key('7'), key('8'), key('9')]),
          row([
            biometricKind == BiometricKind.none
                ? const SizedBox(width: 76, height: 76)
                : _PadKey(
                    onTap: onBiometric ?? () {},
                    plain: true,
                    dark: dark,
                    child: Icon(
                      biometricKind == BiometricKind.face ? Icons.face_retouching_natural : Icons.fingerprint,
                      color: fg,
                      size: 30,
                    ),
                  ),
            key('0'),
            _PadKey(
              onTap: onDelete,
              plain: true,
              dark: dark,
              child: Icon(Icons.backspace_outlined, color: fg, size: 24),
            ),
          ]),
        ],
      ),
    );
  }
}

class _PadKey extends StatelessWidget {
  const _PadKey({required this.onTap, required this.child, this.plain = false, this.dark = true});

  final VoidCallback onTap;
  final Widget child;
  final bool plain;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: plain
          ? Colors.transparent
          : (dark ? Colors.white.withValues(alpha: 0.08) : context.palette.card),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(width: 76, height: 76, child: Center(child: child)),
      ),
    );
  }
}
