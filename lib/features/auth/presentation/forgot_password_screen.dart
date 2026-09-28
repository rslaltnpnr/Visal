import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  bool _loading = false;
  bool _sent = false;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).sendPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Şifreni sıfırla',
      subtitle: 'E-posta adresine bir sıfırlama bağlantısı göndereceğiz.',
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: _sent
              ? VisalCard(
                  key: const ValueKey('sent'),
                  child: Column(
                    children: [
                      const Icon(Icons.mark_email_read_outlined, size: 40, color: AppColors.success),
                      const SizedBox(height: 14),
                      Text('Bağlantı gönderildi', style: context.text.titleMedium),
                      const SizedBox(height: 6),
                      Text(
                        '${_email.text.trim()} adresine gelen bağlantı ile yeni şifreni belirleyebilirsin.',
                        textAlign: TextAlign.center,
                        style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
                      ),
                      const SizedBox(height: 18),
                      PrimaryButton(label: 'Girişe dön', onPressed: () => context.pop()),
                    ],
                  ),
                )
              : Form(
                  key: _form,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: _email,
                        keyboardType: TextInputType.emailAddress,
                        autofillHints: const [AutofillHints.email],
                        validator: Validators.email,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: const InputDecoration(labelText: 'E-posta'),
                      ),
                      const SizedBox(height: 24),
                      PrimaryButton(label: 'Bağlantı Gönder', onPressed: _submit, loading: _loading),
                    ],
                  ),
                ),
        ),
      ],
    );
  }
}
