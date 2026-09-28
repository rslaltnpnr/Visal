import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pickers.dart';
import '../data/plans_repository.dart';
import '../domain/plan_models.dart';

const _palette = [
  Color(0xFFE7A7B1),
  Color(0xFFB68AA0),
  Color(0xFF5B274B),
  Color(0xFF9C8EA3),
  Color(0xFF7DAF91),
  Color(0xFFD6A25A),
  Color(0xFFC85C67),
];

class EventEditorScreen extends ConsumerStatefulWidget {
  const EventEditorScreen({super.key, this.eventId, this.initialDate});

  final String? eventId;
  final DateTime? initialDate;

  @override
  ConsumerState<EventEditorScreen> createState() => _EventEditorScreenState();
}

class _EventEditorScreenState extends ConsumerState<EventEditorScreen> {
  final _form = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _location = TextEditingController();
  final _note = TextEditingController();
  EventCategory _category = EventCategory.date;
  late DateTime _date = dateOnly(widget.initialDate ?? DateTime.now());
  TimeOfDay? _time;
  int? _reminder = 60;
  RepeatRule _repeat = RepeatRule.none;
  int? _color;
  bool _saving = false;
  bool _loaded = false;
  String? _createdBy;

  bool get _isNew => widget.eventId == null;

  @override
  void dispose() {
    _title.dispose();
    _location.dispose();
    _note.dispose();
    super.dispose();
  }

  void _fill(PlanEvent e) {
    if (_loaded) return;
    _loaded = true;
    _title.text = e.title;
    _location.text = e.location ?? '';
    _note.text = e.note ?? '';
    _category = e.category;
    _date = dateOnly(e.date);
    if (e.time != null) {
      final p = e.time!.split(':');
      _time = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
    }
    _reminder = e.reminder;
    _repeat = e.repeat;
    _color = e.color;
    _createdBy = e.createdBy;
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(plansRepositoryProvider).saveEvent(PlanEvent(
            id: widget.eventId ?? '',
            title: _title.text.trim(),
            category: _category,
            date: _date,
            time: _time == null
                ? null
                : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
            location: _location.text.trim().isEmpty ? null : _location.text.trim(),
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
            reminder: _reminder,
            repeat: _repeat,
            color: _color,
            createdBy: _createdBy ?? ref.read(currentUidProvider)!,
          ));
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final ok = await context.confirm(title: 'Etkinlik silinsin mi?', confirmLabel: 'Sil', destructive: true);
    if (!ok) return;
    await ref.read(plansRepositoryProvider).deleteEvent(widget.eventId!);
    if (mounted) context.pop();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isNew) {
      final e = ref.watch(eventProvider(widget.eventId!)).value;
      if (e == null) return const Scaffold(body: LoadingView());
      _fill(e);
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(_isNew ? 'Yeni Plan' : 'Planı Düzenle'),
        actions: [
          if (!_isNew) IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            TextFormField(
              controller: _title,
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => Validators.required(v, 'Başlık'),
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            const SizedBox(height: 18),
            Text('Kategori', style: context.text.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in EventCategory.values)
                  PillChip(
                    label: '${c.emoji} ${c.label}',
                    selected: c == _category,
                    onTap: () => setState(() {
                      _category = c;
                      if (c == EventCategory.birthday || c == EventCategory.anniversary) {
                        _repeat = RepeatRule.yearly;
                      }
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: PickerField(
                    label: 'Tarih',
                    value: _date.dMMMMy,
                    onTap: () async {
                      final d = await pickDate(context, initial: _date);
                      if (d != null) setState(() => _date = d);
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: PickerField(
                    label: 'Saat',
                    icon: Icons.schedule_rounded,
                    value: _time?.format(context) ?? 'Tüm gün',
                    onClear: _time == null ? null : () => setState(() => _time = null),
                    onTap: () async {
                      final t = await pickTime(context, initial: _time);
                      if (t != null) setState(() => _time = t);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _location,
              decoration: const InputDecoration(labelText: 'Konum', prefixIcon: Icon(Icons.place_outlined, size: 20)),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              minLines: 2,
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Not', alignLabelWithHint: true),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<int?>(
              initialValue: _reminder,
              decoration: const InputDecoration(labelText: 'Hatırlatma', prefixIcon: Icon(Icons.notifications_none_rounded, size: 20)),
              items: [
                for (final e in kReminderOptions.entries) DropdownMenuItem(value: e.key, child: Text(e.value)),
              ],
              onChanged: (v) => setState(() => _reminder = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<RepeatRule>(
              initialValue: _repeat,
              decoration: const InputDecoration(labelText: 'Tekrar', prefixIcon: Icon(Icons.repeat_rounded, size: 20)),
              items: [
                for (final r in RepeatRule.values) DropdownMenuItem(value: r, child: Text(r.label)),
              ],
              onChanged: (v) => setState(() => _repeat = v ?? RepeatRule.none),
            ),
            const SizedBox(height: 18),
            Text('Renk', style: context.text.titleSmall),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final c in _palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = _color == c.toARGB32() ? null : c.toARGB32()),
                    child: Container(
                      width: 34,
                      height: 34,
                      margin: const EdgeInsets.only(right: 10),
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: (_color ?? _category.color.toARGB32()) == c.toARGB32()
                              ? context.palette.textPrimary
                              : Colors.transparent,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'Hatırlatmalar ikinize de bildirim olarak gönderilir.',
              style: context.text.bodySmall?.copyWith(color: AppColors.lavenderGrey),
            ),
            const SizedBox(height: 24),
            PrimaryButton(label: 'Kaydet', onPressed: _save, loading: _saving),
          ],
        ),
      ),
    );
  }
}
