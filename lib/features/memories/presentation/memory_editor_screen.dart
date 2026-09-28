import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/services/media_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pickers.dart';
import '../data/memories_repository.dart';
import '../domain/memory.dart';

class MemoryEditorScreen extends ConsumerStatefulWidget {
  const MemoryEditorScreen({super.key, this.memoryId});

  final String? memoryId;

  @override
  ConsumerState<MemoryEditorScreen> createState() => _MemoryEditorScreenState();
}

class _MemoryEditorScreenState extends ConsumerState<MemoryEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _location = TextEditingController();
  final _music = TextEditingController();
  DateTime _date = DateTime.now();
  String? _emoji;
  bool _special = false;
  bool _travel = false;
  List<UploadedMedia> _existing = [];
  final List<UploadedMedia> _removed = [];
  final List<PickedMedia> _new = [];
  bool _saving = false;
  double _progress = 0;
  bool _loaded = false;
  String? _createdBy;

  bool get _isNew => widget.memoryId == null;

  @override
  void dispose() {
    for (final c in [_title, _description, _location, _music]) {
      c.dispose();
    }
    super.dispose();
  }

  void _fill(Memory m) {
    if (_loaded) return;
    _loaded = true;
    _title.text = m.title;
    _description.text = m.description;
    _location.text = m.location ?? '';
    _music.text = m.musicUrl ?? '';
    _date = m.date;
    _emoji = m.emoji;
    _special = m.isSpecial;
    _travel = m.isTravel;
    _existing = [...m.media];
    _createdBy = m.createdBy;
  }

  Future<void> _addMedia() async {
    try {
      final picked = await ref.read(mediaServiceProvider).pickMultiMedia(limit: 10);
      setState(() => _new.addAll(picked));
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final music = _music.text.trim();
    if (music.isNotEmpty && !(Uri.tryParse(music)?.hasScheme ?? false)) {
      context.showSnack('Şarkı bağlantısı geçerli bir URL olmalı');
      return;
    }
    setState(() {
      _saving = true;
      _progress = 0;
    });
    final repo = ref.read(memoriesRepositoryProvider);
    final id = widget.memoryId ?? repo.newId();
    try {
      await repo.save(
        id: id,
        isNew: _isNew,
        memory: Memory(
          id: id,
          createdBy: _createdBy ?? ref.read(currentUidProvider)!,
          title: _title.text.trim(),
          description: _description.text.trim(),
          date: _date,
          media: _existing,
          location: _location.text.trim().isEmpty ? null : _location.text.trim(),
          emoji: _emoji,
          musicUrl: music.isEmpty ? null : music,
          isSpecial: _special,
          isTravel: _travel,
        ),
        newMedia: _new,
        removed: _removed,
        onProgress: (p) => setState(() => _progress = p),
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
    if (!_isNew) {
      final m = ref.watch(memoryProvider(widget.memoryId!)).value;
      if (m == null) return const Scaffold(body: LoadingView());
      _fill(m);
    }

    return Scaffold(
      appBar: AppBar(title: Text(_isNew ? 'Yeni Anı' : 'Anıyı Düzenle')),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            SizedBox(
              height: 112,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _AddTile(onTap: _saving ? null : _addMedia),
                  for (final m in _existing)
                    _Thumb(
                      isVideo: m.kind == MediaKind.video,
                      onRemove: () => setState(() {
                        _existing.remove(m);
                        _removed.add(m);
                      }),
                      child: NetImage(m.kind == MediaKind.video ? m.thumbUrl : (m.thumbUrl ?? m.url)),
                    ),
                  for (final m in _new)
                    _Thumb(
                      isVideo: m.kind == MediaKind.video,
                      onRemove: () => setState(() => _new.remove(m)),
                      child: m.kind == MediaKind.image
                          ? Image.file(File(m.path), fit: BoxFit.cover, cacheWidth: 300)
                          : const ColoredBox(
                              color: AppColors.midnight,
                              child: Center(child: Icon(Icons.videocam_rounded, color: AppColors.rose)),
                            ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              maxLength: 80,
              validator: (v) => Validators.required(v, 'Başlık'),
              decoration: const InputDecoration(labelText: 'Başlık', counterText: ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _description,
              textCapitalization: TextCapitalization.sentences,
              minLines: 3,
              maxLines: 8,
              maxLength: 2000,
              decoration: const InputDecoration(labelText: 'Açıklama', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            PickerField(
              label: 'Tarih',
              value: formatDateOrNull(_date),
              onTap: () async {
                final d = await pickDate(context, initial: _date, last: DateTime.now().add(const Duration(days: 1)));
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Konum', prefixIcon: Icon(Icons.place_outlined, size: 20)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _music,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'Şarkı bağlantısı (Spotify, YouTube…)',
                prefixIcon: Icon(Icons.music_note_rounded, size: 20),
              ),
            ),
            const SizedBox(height: 20),
            Text('Emoji', style: context.text.titleSmall),
            const SizedBox(height: 10),
            EmojiChoice(value: _emoji, onChanged: (e) => setState(() => _emoji = e)),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _special,
              onChanged: (v) => setState(() => _special = v),
              title: const Text('Özel gün'),
              subtitle: const Text('“Özel Günler” filtresinde görünür'),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _travel,
              onChanged: (v) => setState(() => _travel = v),
              title: const Text('Seyahat'),
            ),
            const SizedBox(height: 16),
            if (_saving && _new.isNotEmpty) ...[
              LinearProgressIndicator(value: _progress, minHeight: 4, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 8),
              Text('Yükleniyor… %${(_progress * 100).round()}', style: context.text.bodySmall),
              const SizedBox(height: 12),
            ],
            PrimaryButton(label: _isNew ? 'Anıyı Kaydet' : 'Değişiklikleri Kaydet', onPressed: _save, loading: _saving),
          ],
        ),
      ),
    );
  }
}

class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: 104,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: context.palette.softAccent,
              border: Border.all(color: AppColors.mauve.withValues(alpha: 0.4)),
            ),
            child: const Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.add_photo_alternate_outlined, color: AppColors.mauve),
                SizedBox(height: 6),
                Text('Fotoğraf / Video', textAlign: TextAlign.center, style: TextStyle(fontSize: 11)),
              ],
            ),
          ),
        ),
      );
}

class _Thumb extends StatelessWidget {
  const _Thumb({required this.child, required this.onRemove, this.isVideo = false});

  final Widget child;
  final VoidCallback onRemove;
  final bool isVideo;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(right: 10),
        child: SizedBox(
          width: 104,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(borderRadius: BorderRadius.circular(20), child: child),
              if (isVideo) const Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white)),
              Positioned(
                right: 4,
                top: 4,
                child: GestureDetector(
                  onTap: onRemove,
                  child: Container(
                    padding: const EdgeInsets.all(3),
                    decoration: const BoxDecoration(color: Colors.black54, shape: BoxShape.circle),
                    child: const Icon(Icons.close_rounded, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
}
