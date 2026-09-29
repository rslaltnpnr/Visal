import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

/// E-postadaki sıfırlama bağlantısıyla açılan oturumda yeni şifre belirleme.
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends ConsumerState<ResetPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      context.showSnack('Yeni şifren kaydedildi.');
      context.go(Routes.launch);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Yeni şifre',
      subtitle: 'Hesabın için yeni bir şifre belirle.',
      children: [
        Form(
          key: _form,
          child: Column(
            children: [
              PasswordField(
                controller: _password,
                label: 'Yeni şifre',
                validator: Validators.password,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _confirm,
                label: 'Yeni şifre (tekrar)',
                autofillHints: const [AutofillHints.newPassword],
                validator: (v) => v != _password.text ? 'Şifreler eşleşmiyor' : null,
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 24),
              PrimaryButton(label: 'Şifreyi Kaydet', onPressed: _submit, loading: _loading),
            ],
          ),
        ),
      ],
    );
  }
}
