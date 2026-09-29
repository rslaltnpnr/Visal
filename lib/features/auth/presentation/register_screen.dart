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

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _loading = false;

  @override
  void dispose() {
    for (final c in [_name, _email, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _loading = true);
    try {
      final result = await ref.read(authRepositoryProvider).register(
            name: _name.text,
            email: _email.text,
            password: _password.text,
          );
      if (result == RegisterResult.confirmEmail && mounted) {
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('E-postanı doğrula'),
            content: Text(
              '${_email.text.trim()} adresine bir doğrulama bağlantısı gönderdik. '
              'Bağlantıya dokunduktan sonra giriş yapabilirsin.',
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Tamam'))],
          ),
        );
        if (mounted) context.go(Routes.login);
      }
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Hesap oluştur',
      subtitle: 'Birkaç adımda ikinize ait alanı kurun.',
      showBack: context.canPop(),
      children: [
        AutofillGroup(
          child: Form(
            key: _form,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.givenName],
                  validator: Validators.name,
                  decoration: const InputDecoration(labelText: 'Adın'),
                ),
                const SizedBox(height: 14),
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
                  validator: Validators.password,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 14),
                PasswordField(
                  controller: _confirm,
                  label: 'Şifre (tekrar)',
                  autofillHints: const [AutofillHints.newPassword],
                  validator: (v) => v != _password.text ? 'Şifreler eşleşmiyor' : null,
                  onSubmitted: (_) => _submit(),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Hesap oluşturarak Kullanım Koşulları ve Gizlilik Politikası\'nı kabul etmiş olursunuz. '
          'Verileriniz yalnızca siz ve partneriniz tarafından görülebilir.',
          style: context.text.bodySmall,
        ),
        const SizedBox(height: 24),
        PrimaryButton(label: 'Hesap Oluştur', onPressed: _submit, loading: _loading),
        const OrDivider(),
        const SocialAuthButtons(),
        const SizedBox(height: 24),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Zaten hesabın var mı?', style: context.text.bodyMedium),
            TextButton(
              onPressed: () => context.pushReplacement(Routes.login),
              child: const Text('Giriş yap'),
            ),
          ],
        ),
      ],
    );
  }
}
