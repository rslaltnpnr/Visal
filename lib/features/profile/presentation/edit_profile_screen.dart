import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/services/media_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pickers.dart';
import '../data/profile_repository.dart';

class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key});

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: ref.read(currentUserProvider).value?.name);
  late DateTime? _birthday = ref.read(currentUserProvider).value?.birthday;
  bool _saving = false;
  bool _uploading = false;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _changePhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Galeriden seç'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Fotoğraf çek'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final media = await ref.read(mediaServiceProvider).pickImage(source: source);
    if (media == null) return;
    setState(() => _uploading = true);
    try {
      await ref.read(profileRepositoryProvider).uploadAvatar(media);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(
            name: _name.text,
            birthday: _birthday,
            clearBirthday: _birthday == null,
          );
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = ref.watch(currentUserProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Profili Düzenle')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          children: [
            Center(
              child: Stack(
                children: [
                  AppAvatar(url: me?.photoUrl, name: me?.name ?? '', size: 112, ring: true),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Material(
                      color: AppColors.midnight,
                      shape: const CircleBorder(),
                      child: InkWell(
                        customBorder: const CircleBorder(),
                        onTap: _uploading ? null : _changePhoto,
                        child: Padding(
                          padding: const EdgeInsets.all(10),
                          child: _uploading
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : const Icon(Icons.photo_camera_outlined, color: Colors.white, size: 18),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              validator: Validators.name,
              decoration: const InputDecoration(labelText: 'Ad'),
            ),
            const SizedBox(height: 12),
            PickerField(
              label: 'Doğum günü',
              icon: Icons.cake_outlined,
              value: formatDateOrNull(_birthday),
              onClear: () => setState(() => _birthday = null),
              onTap: () async {
                final d = await pickDate(
                  context,
                  initial: _birthday ?? DateTime(1995),
                  first: DateTime(1920),
                  last: DateTime.now(),
                );
                if (d != null) setState(() => _birthday = d);
              },
            ),
            const SizedBox(height: 28),
            PrimaryButton(label: 'Kaydet', onPressed: _save, loading: _saving),
          ],
        ),
      ),
    );
  }
}
