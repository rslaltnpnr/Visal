import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/failure.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/visal_logo.dart';
import '../../data/auth_repository.dart';

/// Minimal form sayfası iskeleti.
class AuthScaffold extends StatelessWidget {
  const AuthScaffold({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
    this.showBack = true,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(automaticallyImplyLeading: showBack),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: VisalMark(
                size: 52,
                tone: context.isDark ? MarkTone.onDark : MarkTone.onLight,
              ),
            ),
            const SizedBox(height: 26),
            Text(title, style: context.text.headlineLarge),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
            ),
            const SizedBox(height: 32),
            ...children,
          ],
        ),
      ),
    );
  }
}

class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    this.label = 'Şifre',
    this.validator,
    this.textInputAction = TextInputAction.done,
    this.onSubmitted,
    this.autofillHints = const [AutofillHints.password],
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final Iterable<String> autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      validator: widget.validator,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      autofillHints: widget.autofillHints,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          onPressed: () => setState(() => _obscure = !_obscure),
          icon: Icon(
            _obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
            color: context.palette.muted,
          ),
        ),
      ),
    );
  }
}

class OrDivider extends StatelessWidget {
  const OrDivider({super.key});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Row(
          children: [
            const Expanded(child: Divider()),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Text('veya', style: context.text.labelMedium),
            ),
            const Expanded(child: Divider()),
          ],
        ),
      );
}

/// Google ve Apple ile devam et butonları.
class SocialAuthButtons extends ConsumerStatefulWidget {
  const SocialAuthButtons({super.key});

  @override
  ConsumerState<SocialAuthButtons> createState() => _SocialAuthButtonsState();
}

class _SocialAuthButtonsState extends ConsumerState<SocialAuthButtons> {
  String? _busy;

  Future<void> _run(String key, Future<void> Function() action) async {
    setState(() => _busy = key);
    try {
      await action();
    } catch (e) {
      if (mounted && AppFailure.from(e).code != 'cancelled') context.showError(e);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final repo = ref.read(authRepositoryProvider);
    return Column(
      children: [
        _SocialButton(
          label: 'Google ile devam et',
          leading: const _GoogleG(),
          loading: _busy == 'google',
          onPressed: _busy != null ? null : () => _run('google', repo.signInWithGoogle),
        ),
        if (AuthRepository.appleSignInSupported) ...[
          const SizedBox(height: 12),
          _SocialButton(
            label: 'Apple ile devam et',
            leading: Icon(Icons.apple, size: 24, color: context.palette.textPrimary),
            loading: _busy == 'apple',
            onPressed: _busy != null ? null : () => _run('apple', repo.signInWithApple),
          ),
        ],
      ],
    );
  }
}

class _SocialButton extends StatelessWidget {
  const _SocialButton({
    required this.label,
    required this.leading,
    required this.onPressed,
    this.loading = false,
  });

  final String label;
  final Widget leading;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: context.isDark ? AppColors.darkCard : Colors.white,
        ),
        child: loading
            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [leading, const SizedBox(width: 12), Text(label)],
              ),
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) => ShaderMask(
        shaderCallback: (r) => const SweepGradient(
          colors: [
            Color(0xFF4285F4),
            Color(0xFF34A853),
            Color(0xFFFBBC05),
            Color(0xFFEA4335),
            Color(0xFF4285F4),
          ],
        ).createShader(r),
        blendMode: BlendMode.srcIn,
        child: const Text(
          'G',
          style: TextStyle(fontFamily: kFontFamily, fontSize: 20, fontWeight: FontWeight.w700),
        ),
      );
}
