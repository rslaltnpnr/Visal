import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../auth/presentation/widgets/auth_widgets.dart';
import '../../profile/data/profile_repository.dart';

class AccountScreen extends ConsumerStatefulWidget {
  const AccountScreen({super.key});

  @override
  ConsumerState<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends ConsumerState<AccountScreen> {
  bool _exporting = false;
  bool _deleting = false;

  Future<void> _export() async {
    setState(() => _exporting = true);
    try {
      final file = await ref.read(profileRepositoryProvider).exportData();
      await SharePlus.instance.share(ShareParams(
        files: [XFile(file.path, mimeType: 'application/json')],
        subject: 'VISAL verilerim',
      ));
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => const _DeleteDialog(),
    );
    if (confirmed != true) return;
    setState(() => _deleting = true);
    try {
      await ref.read(profileRepositoryProvider).deleteAccount();
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    final isPasswordUser = ref.watch(firebaseAuthProvider).currentUser?.providerData.any((p) => p.providerId == 'password') ?? false;
    return Scaffold(
      appBar: AppBar(title: const Text('Hesap')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          VisalCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: const SoftIcon(Icons.alternate_email_rounded, size: 36),
                  title: const Text('E-posta'),
                  subtitle: Text(me?.email ?? ''),
                ),
                if (isPasswordUser)
                  ListTile(
                    leading: const SoftIcon(Icons.key_rounded, size: 36),
                    title: const Text('Şifreyi değiştir'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const _ChangePasswordSheet(),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          VisalCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                ListTile(
                  leading: const SoftIcon(Icons.download_rounded, size: 36),
                  title: const Text('Verileri indir'),
                  subtitle: const Text('Profilin, mesajlar, anılar ve planların JSON kopyası'),
                  trailing: _exporting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.chevron_right_rounded),
                  onTap: _exporting ? null : _export,
                ),
                ListTile(
                  leading: const SoftIcon(Icons.delete_forever_outlined, size: 36, color: AppColors.error),
                  title: const Text('Hesabı sil', style: TextStyle(color: AppColors.error)),
                  subtitle: const Text('Hesabın ve ortak alanınız kalıcı olarak silinir'),
                  trailing: _deleting
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : null,
                  onTap: _deleting ? null : _delete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _DeleteDialog extends StatefulWidget {
  const _DeleteDialog();

  @override
  State<_DeleteDialog> createState() => _DeleteDialogState();
}

class _DeleteDialogState extends State<_DeleteDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ok = _c.text.trim().toUpperCase() == 'SİL' || _c.text.trim().toUpperCase() == 'SIL';
    return AlertDialog(
      title: const Text('Hesabın kalıcı olarak silinsin mi?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Bu işlem geri alınamaz. Hesabın, eşleşmen ve ortak alanınızdaki tüm mesaj, anı, plan ve dosyalar silinir.',
            style: context.text.bodyMedium,
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _c,
            onChanged: (_) => setState(() {}),
            decoration: const InputDecoration(hintText: 'Onaylamak için SİL yaz'),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Vazgeç')),
        TextButton(
          onPressed: ok ? () => Navigator.pop(context, true) : null,
          child: const Text('Hesabı sil', style: TextStyle(color: AppColors.error)),
        ),
      ],
    );
  }
}

class _ChangePasswordSheet extends ConsumerStatefulWidget {
  const _ChangePasswordSheet();

  @override
  ConsumerState<_ChangePasswordSheet> createState() => _ChangePasswordSheetState();
}

class _ChangePasswordSheetState extends ConsumerState<_ChangePasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).changePassword(_current.text, _next.text);
      if (mounted) {
        Navigator.pop(context);
        context.showSnack('Şifren güncellendi');
      }
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => SheetScaffold(
        title: 'Şifreyi değiştir',
        child: Form(
          key: _form,
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            children: [
              PasswordField(controller: _current, label: 'Mevcut şifre', textInputAction: TextInputAction.next),
              const SizedBox(height: 12),
              PasswordField(controller: _next, label: 'Yeni şifre', validator: Validators.password),
              const SizedBox(height: 20),
              PrimaryButton(label: 'Güncelle', onPressed: _save, loading: _saving),
            ],
          ),
        ),
      );
}
