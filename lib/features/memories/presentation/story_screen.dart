import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/media_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pickers.dart';
import '../data/memories_repository.dart';
import '../domain/memory.dart';

/// Bizim Hikâyemiz: İlk mesaj, ilk buluşma, nişan, evlilik… zaman çizelgesi.
class StoryScreen extends ConsumerWidget {
  const StoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = ref.watch(storyProvider);
    final couple = ref.watch(coupleProvider).value;
    return Scaffold(
      appBar: AppBar(title: const Text('Bizim Hikâyemiz')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context, null),
        backgroundColor: context.isDark ? AppColors.rose : AppColors.midnight,
        foregroundColor: context.isDark ? AppColors.midnight : AppColors.ivory,
        icon: const Icon(Icons.add_rounded),
        label: const Text('An ekle'),
      ),
      body: AsyncView(
        value: story,
        data: (events) {
          if (events.isEmpty) {
            return EmptyState(
              icon: Icons.auto_stories_outlined,
              emoji: '📖',
              title: 'Hikâyenizi yazmaya başlayın',
              message: 'İlk mesajınız, ilk buluşmanız, ilk tatiliniz… Dönüm noktalarınızı ekleyin.',
              action: Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final t in StoryType.values.take(5))
                    ActionChip(
                      label: Text('${t.emoji} ${t.label}'),
                      onPressed: () => _edit(context, null, type: t),
                    ),
                ],
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 120),
            itemCount: events.length + 1,
            itemBuilder: (context, i) {
              if (i == 0) {
                final since = couple?.togetherSince;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Text(
                    since == null
                        ? 'Birlikte yazdığınız hikâye.'
                        : '${since.dMMMMy} tarihinden bu yana ${formatThousands(daysTogether(since))} gün.',
                    style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
                  ),
                );
              }
              final e = events[i - 1];
              final last = i == events.length;
              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.logoGradient),
                            alignment: Alignment.center,
                            child: Text(e.type.emoji, style: const TextStyle(fontSize: 20)),
                          ),
                          if (!last)
                            Expanded(child: Container(width: 1.5, color: AppColors.rose.withValues(alpha: 0.5))),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 22),
                        child: VisalCard(
                          padding: EdgeInsets.zero,
                          onTap: () => _edit(context, e),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (e.photoUrl != null)
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
                                  child: AspectRatio(aspectRatio: 16 / 9, child: NetImage(e.photoUrl)),
                                ),
                              Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(e.date.dMMMMy, style: context.text.labelMedium?.copyWith(color: AppColors.mauve)),
                                    const SizedBox(height: 4),
                                    Text(e.title, style: context.text.titleMedium),
                                    if (e.description.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Text(e.description, style: context.text.bodySmall),
                                    ],
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _edit(BuildContext context, StoryEvent? event, {StoryType? type}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _StoryEditor(event: event, initialType: type),
    );
  }
}

class _StoryEditor extends ConsumerStatefulWidget {
  const _StoryEditor({this.event, this.initialType});

  final StoryEvent? event;
  final StoryType? initialType;

  @override
  ConsumerState<_StoryEditor> createState() => _StoryEditorState();
}

class _StoryEditorState extends ConsumerState<_StoryEditor> {
  final _form = GlobalKey<FormState>();
  late StoryType _type = widget.event?.type ?? widget.initialType ?? StoryType.custom;
  late final _title = TextEditingController(
    text: widget.event?.title ?? (widget.initialType != null ? widget.initialType!.label : ''),
  );
  late final _desc = TextEditingController(text: widget.event?.description ?? '');
  late DateTime _date = widget.event?.date ?? DateTime.now();
  PickedMedia? _photo;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _desc.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(memoriesRepositoryProvider).saveStory(
            StoryEvent(
              id: widget.event?.id ?? '',
              type: _type,
              title: _title.text.trim(),
              date: _date,
              description: _desc.text.trim(),
              createdBy: widget.event?.createdBy ?? ref.read(currentUidProvider)!,
              photoUrl: widget.event?.photoUrl,
              photoPath: widget.event?.photoPath,
            ),
            photo: _photo,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: widget.event == null ? 'Hikâyeye ekle' : 'Anı düzenle',
      trailing: widget.event == null
          ? null
          : IconButton(
              onPressed: () async {
                final ok = await context.confirm(title: 'Silinsin mi?', confirmLabel: 'Sil', destructive: true);
                if (!ok) return;
                await ref.read(memoriesRepositoryProvider).deleteStory(widget.event!.id);
                if (context.mounted) Navigator.pop(context);
              },
              icon: const Icon(Icons.delete_outline_rounded),
            ),
      child: Form(
        key: _form,
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final t in StoryType.values)
                  PillChip(
                    label: '${t.emoji} ${t.label}',
                    selected: t == _type,
                    onTap: () => setState(() {
                      if (_title.text.isEmpty || StoryType.values.any((x) => x.label == _title.text)) {
                        _title.text = t == StoryType.custom ? '' : t.label;
                      }
                      _type = t;
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              validator: (v) => Validators.required(v, 'Başlık'),
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            const SizedBox(height: 12),
            PickerField(
              label: 'Tarih',
              value: _date.dMMMMy,
              onTap: () async {
                final d = await pickDate(context, initial: _date, last: DateTime.now().add(const Duration(days: 3650)));
                if (d != null) setState(() => _date = d);
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Not'),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                final p = await ref.read(mediaServiceProvider).pickImage();
                if (p != null) setState(() => _photo = p);
              },
              icon: const Icon(Icons.photo_outlined),
              label: Text(_photo != null ? 'Fotoğraf seçildi' : 'Fotoğraf ekle'),
            ),
            const SizedBox(height: 16),
            PrimaryButton(label: 'Kaydet', onPressed: _save, loading: _saving),
          ],
        ),
      ),
    );
  }
}
