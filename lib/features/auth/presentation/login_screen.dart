import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../data/auth_repository.dart';
import 'widgets/auth_widgets.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _form = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      await ref.read(authRepositoryProvider).signInWithEmail(_email.text, _password.text);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Tekrar hoş geldin',
      subtitle: 'İkinize ait dünyaya giriş yapın.',
      showBack: context.canPop(),
      children: [
        AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                  validator: Validators.email,
                  decoration: const InputDecoration(labelText: 'E-posta'),
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _password,
                  validator: (v) => (v?.isEmpty ?? true) ? 'Şifre gerekli' : null,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () => context.push(Routes.forgot),
            child: const Text('Şifremi unuttum'),
          ),
        ),
        const SizedBox(height: 12),
        PrimaryButton(label: 'Giriş Yap', onPressed: _submit, loading: _loading),
        const OrDivider(),
        const SocialAuthButtons(),
        const SizedBox(height: 28),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hesabın yok mu?', style: context.text.bodyMedium),
            TextButton(
              onPressed: () => context.pushReplacement(Routes.register),
              child: const Text('Hesap oluştur'),
            ),
          ],
        ),
      ],
    );
  }
}
