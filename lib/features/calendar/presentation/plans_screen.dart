import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
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

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key, this.initialTab});

  final String? initialTab;

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(
    length: 3,
    vsync: this,
    initialIndex: switch (widget.initialTab) {
      'tasks' => 1,
      'goals' => 2,
      _ => 0,
    },
  )..addListener(() => setState(() {}));
  DateTime _selected = dateOnly(DateTime.now());

  @override
  void didUpdateWidget(covariant PlansScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != oldWidget.initialTab) {
      _tabs.animateTo(switch (widget.initialTab) {
        'tasks' => 1,
        'goals' => 2,
        _ => 0,
      });
    }
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  void _add() {
    switch (_tabs.index) {
      case 0:
        context.push(Routes.eventNew, extra: _selected);
      case 1:
        showTaskEditor(context, null);
      case 2:
        showGoalEditor(context, null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 72,
        title: Text('Planlarımız', style: context.text.headlineSmall),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Container(
            margin: const EdgeInsets.fromLTRB(20, 0, 20, 10),
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(24),
            ),
            child: TabBar(
              controller: _tabs,
              dividerColor: Colors.transparent,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                color: context.isDark ? AppColors.rose : AppColors.midnight,
                borderRadius: BorderRadius.circular(20),
              ),
              labelColor: context.isDark ? AppColors.midnight : AppColors.ivory,
              unselectedLabelColor: context.palette.textSecondary,
              labelStyle: context.text.labelLarge?.copyWith(fontSize: 14),
              tabs: const [Tab(text: 'Takvim'), Tab(text: 'Görevler'), Tab(text: 'Hedefler')],
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _add,
        backgroundColor: context.isDark ? AppColors.rose : AppColors.midnight,
        foregroundColor: context.isDark ? AppColors.midnight : AppColors.ivory,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded),
      ),
      body: TabBarView(
        controller: _tabs,
        children: [
          _CalendarTab(selected: _selected, onSelect: (d) => setState(() => _selected = d)),
          const _TasksTab(),
          const _GoalsTab(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Takvim
// ---------------------------------------------------------------------------

class _CalendarTab extends ConsumerStatefulWidget {
  const _CalendarTab({required this.selected, required this.onSelect});

  final DateTime selected;
  final ValueChanged<DateTime> onSelect;

  @override
  ConsumerState<_CalendarTab> createState() => _CalendarTabState();
}

class _CalendarTabState extends ConsumerState<_CalendarTab> {
  late DateTime _month = DateTime(widget.selected.year, widget.selected.month);

  @override
  Widget build(BuildContext context) {
    final monthEvents = ref.watch(monthEventsProvider(_month)).value ?? const [];
    final repeating = ref.watch(repeatingEventsProvider).value ?? const [];
    final byId = {for (final e in [...monthEvents, ...repeating]) e.id: e};
    final all = byId.values.toList();
    final dayEvents = all.where((e) => e.occursOn(widget.selected)).toList()
      ..sort((a, b) => (a.time ?? '').compareTo(b.time ?? ''));
    final upcoming = ref.watch(upcomingProvider).take(5).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 110),
      children: [
        VisalCard(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
          child: Column(
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1)),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Expanded(
                    child: Text(
                      _month.monthYear,
                      textAlign: TextAlign.center,
                      style: context.text.titleMedium,
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1)),
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  for (final d in const ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'])
                    Expanded(child: Center(child: Text(d, style: context.text.labelSmall))),
                ],
              ),
              const SizedBox(height: 6),
              _MonthGrid(
                month: _month,
                selected: widget.selected,
                events: all,
                onSelect: widget.onSelect,
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        SectionHeader(title: widget.selected.isSameDay(DateTime.now()) ? 'Bugün' : widget.selected.dMMMM),
        if (dayEvents.isEmpty)
          VisalCard(
            onTap: () => context.push(Routes.eventNew, extra: widget.selected),
            child: Row(
              children: [
                const SoftIcon(Icons.add_rounded, size: 40),
                const SizedBox(width: 12),
                Expanded(child: Text('Bu gün için bir plan ekle', style: context.text.bodyMedium)),
              ],
            ),
          ),
        for (final e in dayEvents) _EventTile(event: e),
        if (upcoming.isNotEmpty) ...[
          const SizedBox(height: 20),
          const SectionHeader(title: 'Yaklaşan'),
          VisalCard(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                for (final u in upcoming)
                  ListTile(
                    leading: SoftIcon(u.icon, size: 38, color: u.color),
                    title: Text(u.title, style: context.text.titleSmall),
                    subtitle: Text(u.date.dMMMMy),
                    trailing: Text(daysLeftLabel(u.daysLeft), style: context.text.labelMedium),
                    onTap: u.eventId == null ? null : () => context.push(Routes.event(u.eventId!)),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _MonthGrid extends StatelessWidget {
  const _MonthGrid({
    required this.month,
    required this.selected,
    required this.events,
    required this.onSelect,
  });

  final DateTime month;
  final DateTime selected;
  final List<PlanEvent> events;
  final ValueChanged<DateTime> onSelect;

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month);
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leading = first.weekday - 1;
    final cells = ((leading + daysInMonth) / 7).ceil() * 7;
    final today = dateOnly(DateTime.now());
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: cells,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 0.95),
      itemBuilder: (context, i) {
        final dayNum = i - leading + 1;
        if (dayNum < 1 || dayNum > daysInMonth) return const SizedBox.shrink();
        final day = DateTime(month.year, month.month, dayNum);
        final isSelected = day == selected;
        final isToday = day == today;
        final dots = events.where((e) => e.occursOn(day)).take(3).toList();
        return GestureDetector(
          onTap: () {
            HapticFeedback.selectionClick();
            onSelect(day);
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: isSelected ? AppColors.ctaGradient : null,
              border: isToday && !isSelected ? Border.all(color: AppColors.mauve) : null,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$dayNum',
                  style: context.text.bodyMedium?.copyWith(
                    color: isSelected ? Colors.white : null,
                    fontWeight: isToday || isSelected ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final e in dots)
                      Container(
                        width: 4.5,
                        height: 4.5,
                        margin: const EdgeInsets.symmetric(horizontal: 1),
                        decoration: BoxDecoration(
                          color: isSelected ? Colors.white : e.displayColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event});

  final PlanEvent event;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: VisalCard(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          onTap: () => context.push(Routes.event(event.id)),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 44,
                decoration: BoxDecoration(color: event.displayColor, borderRadius: BorderRadius.circular(2)),
              ),
              const SizedBox(width: 12),
              Text(event.category.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(event.title, style: context.text.titleSmall),
                    Text(
                      [
                        event.time ?? 'Tüm gün',
                        if (event.location?.isNotEmpty ?? false) event.location!,
                        if (event.repeat != RepeatRule.none) event.repeat.label,
                      ].join(' · '),
                      style: context.text.bodySmall,
                    ),
                  ],
                ),
              ),
              if (event.reminder != null) Icon(Icons.notifications_active_outlined, size: 18, color: context.palette.muted),
            ],
          ),
        ),
      );
}

// ---------------------------------------------------------------------------
// Görevler
// ---------------------------------------------------------------------------

enum _TaskFilter { all, mine, partner, both, done }

class _TasksTab extends ConsumerStatefulWidget {
  const _TasksTab();

  @override
  ConsumerState<_TasksTab> createState() => _TasksTabState();
}

class _TasksTabState extends ConsumerState<_TasksTab> {
  _TaskFilter _filter = _TaskFilter.all;

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final partnerId = ref.watch(partnerIdProvider) ?? '';
    final partnerName = ref.watch(partnerNameProvider);
    final async = ref.watch(tasksProvider);
    final labels = {
      _TaskFilter.all: 'Açık',
      _TaskFilter.mine: 'Benim',
      _TaskFilter.partner: partnerName,
      _TaskFilter.both: 'İkimiz',
      _TaskFilter.done: 'Tamamlanan',
    };
    return AsyncView(
      value: async,
      data: (tasks) {
        final filtered = tasks.where((t) => switch (_filter) {
              _TaskFilter.all => !t.done,
              _TaskFilter.mine => !t.done && t.assignee == uid,
              _TaskFilter.partner => !t.done && t.assignee == partnerId,
              _TaskFilter.both => !t.done && t.assignee == kAssignBoth,
              _TaskFilter.done => t.done,
            }).toList();
        return Column(
          children: [
            SizedBox(
              height: 52,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                children: [
                  for (final f in _TaskFilter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: PillChip(label: labels[f]!, selected: f == _filter, onTap: () => setState(() => _filter = f)),
                    ),
                ],
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? EmptyState(
                      icon: Icons.checklist_rounded,
                      emoji: '🧺',
                      title: _filter == _TaskFilter.done ? 'Henüz tamamlanan yok' : 'Yapılacak bir şey yok',
                      message: 'Birlikte yapacaklarınızı ekleyin ve birbirinize atayın.',
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
                      itemCount: filtered.length,
                      itemBuilder: (context, i) {
                        final t = filtered[i];
                        final assignee = t.assignee == kAssignBoth
                            ? 'İkimiz'
                            : t.assignee == uid
                                ? 'Ben'
                                : partnerName;
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: VisalCard(
                            padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
                            onTap: () => showTaskEditor(context, t),
                            child: Row(
                              children: [
                                Checkbox(
                                  value: t.done,
                                  shape: const CircleBorder(),
                                  activeColor: AppColors.mauve,
                                  onChanged: (_) {
                                    HapticFeedback.lightImpact();
                                    ref.read(plansRepositoryProvider).toggleTask(t);
                                  },
                                ),
                                Expanded(
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          t.title,
                                          style: context.text.titleSmall?.copyWith(
                                            decoration: t.done ? TextDecoration.lineThrough : null,
                                            color: t.done ? context.palette.muted : null,
                                          ),
                                        ),
                                        if (t.description.isNotEmpty)
                                          Text(t.description, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                                        const SizedBox(height: 4),
                                        Wrap(
                                          spacing: 10,
                                          children: [
                                            _MiniTag(icon: Icons.person_outline_rounded, text: assignee),
                                            if (t.dueDate != null)
                                              _MiniTag(
                                                icon: Icons.event_outlined,
                                                text: t.dueDate!.dMMM,
                                                color: t.overdue ? AppColors.error : null,
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color ?? AppColors.mauve),
          const SizedBox(width: 3),
          Text(text, style: context.text.labelSmall?.copyWith(color: color)),
        ],
      );
}

Future<void> showTaskEditor(BuildContext context, CoupleTask? task) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _TaskEditor(task: task),
    );

class _TaskEditor extends ConsumerStatefulWidget {
  const _TaskEditor({this.task});

  final CoupleTask? task;

  @override
  ConsumerState<_TaskEditor> createState() => _TaskEditorState();
}

class _TaskEditorState extends ConsumerState<_TaskEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.task?.title);
  late final _desc = TextEditingController(text: widget.task?.description);
  late DateTime? _due = widget.task?.dueDate;
  late String _assignee = widget.task?.assignee ?? kAssignBoth;
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
    final repo = ref.read(plansRepositoryProvider);
    try {
      await repo.saveTask(CoupleTask(
        id: widget.task?.id ?? '',
        title: _title.text.trim(),
        description: _desc.text.trim(),
        dueDate: _due,
        assignee: _assignee,
        done: widget.task?.done ?? false,
        doneBy: widget.task?.doneBy,
        createdBy: widget.task?.createdBy ?? repo.uid,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider) ?? '';
    final pid = ref.watch(partnerIdProvider) ?? '';
    final partnerName = ref.watch(partnerNameProvider);
    return SheetScaffold(
      title: widget.task == null ? 'Yeni görev' : 'Görevi düzenle',
      trailing: widget.task == null
          ? null
          : IconButton(
              onPressed: () async {
                await ref.read(plansRepositoryProvider).deleteTask(widget.task!.id);
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
            TextFormField(
              controller: _title,
              autofocus: widget.task == null,
              textCapitalization: TextCapitalization.sentences,
              validator: (v) => Validators.required(v, 'Başlık'),
              decoration: const InputDecoration(labelText: 'Başlık'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _desc,
              minLines: 1,
              maxLines: 4,
              decoration: const InputDecoration(labelText: 'Açıklama'),
            ),
            const SizedBox(height: 12),
            PickerField(
              label: 'Tarih',
              value: formatDateOrNull(_due),
              onClear: () => setState(() => _due = null),
              onTap: () async {
                final d = await pickDate(context, initial: _due ?? DateTime.now(), first: DateTime(2000));
                if (d != null) setState(() => _due = d);
              },
            ),
            const SizedBox(height: 16),
            Text('Kime atansın?', style: context.text.titleSmall),
            const SizedBox(height: 10),
            Row(
              children: [
                for (final (value, label) in [(uid, 'Ben'), (pid, partnerName), (kAssignBoth, 'İkimiz')])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: PillChip(label: label, selected: _assignee == value, onTap: () => setState(() => _assignee = value)),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Kaydet', onPressed: _save, loading: _saving),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Hedefler
// ---------------------------------------------------------------------------

class _GoalsTab extends ConsumerWidget {
  const _GoalsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AsyncView(
      value: ref.watch(goalsProvider),
      data: (goals) {
        if (goals.isEmpty) {
          return EmptyState(
            icon: Icons.flag_outlined,
            emoji: '🎯',
            title: 'Ortak hedefleriniz',
            message: '“Birlikte 100 film”, “Tatil birikimi”, “10 şehir”… İlerlemeyi birlikte izleyin.',
            action: OutlinedButton(onPressed: () => showGoalEditor(context, null), child: const Text('Hedef ekle')),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
          itemCount: goals.length,
          itemBuilder: (context, i) => _GoalCard(goal: goals[i]),
        );
      },
    );
  }
}

String _fmtNum(num n) => n is int || n == n.roundToDouble() ? formatThousands(n.round()) : n.toStringAsFixed(1);

class _GoalCard extends ConsumerWidget {
  const _GoalCard({required this.goal});

  final CoupleGoal goal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = goal;
    final repo = ref.read(plansRepositoryProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: VisalCard(
        onTap: () => showGoalEditor(context, g),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SoftIcon(null, emoji: g.emoji, size: 44),
                const SizedBox(width: 12),
                Expanded(child: Text(g.title, style: context.text.titleMedium)),
                if (g.completed) const Icon(Icons.verified_rounded, color: AppColors.success),
              ],
            ),
            const SizedBox(height: 16),
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: g.progress),
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => Stack(
                children: [
                  Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: context.palette.softAccent,
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                  FractionallySizedBox(
                    widthFactor: v,
                    child: Container(
                      height: 10,
                      decoration: BoxDecoration(
                        gradient: AppColors.ctaGradient,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: _fmtNum(g.current), style: context.text.titleMedium),
                        TextSpan(
                          text: ' / ${_fmtNum(g.target)} ${g.unit}',
                          style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
                Text('%${(g.progress * 100).round()}', style: context.text.labelMedium),
                const SizedBox(width: 8),
                _StepButton(icon: Icons.remove_rounded, onTap: g.current <= 0 ? null : () => repo.incrementGoal(g.id, -g.step)),
                const SizedBox(width: 6),
                _StepButton(icon: Icons.add_rounded, onTap: () {
                  HapticFeedback.lightImpact();
                  repo.incrementGoal(g.id, g.step);
                }),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
        color: context.palette.softAccent,
        shape: const CircleBorder(),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onTap,
          child: SizedBox(width: 36, height: 36, child: Icon(icon, size: 20, color: onTap == null ? context.palette.muted : null)),
        ),
      );
}

Future<void> showGoalEditor(BuildContext context, CoupleGoal? goal) => showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _GoalEditor(goal: goal),
    );

class _GoalEditor extends ConsumerStatefulWidget {
  const _GoalEditor({this.goal});

  final CoupleGoal? goal;

  @override
  ConsumerState<_GoalEditor> createState() => _GoalEditorState();
}

class _GoalEditorState extends ConsumerState<_GoalEditor> {
  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.goal?.title);
  late final _target = TextEditingController(text: widget.goal == null ? '' : _fmtRaw(widget.goal!.target));
  late final _current = TextEditingController(text: widget.goal == null ? '0' : _fmtRaw(widget.goal!.current));
  late final _unit = TextEditingController(text: widget.goal?.unit);
  late final _step = TextEditingController(text: widget.goal == null ? '1' : _fmtRaw(widget.goal!.step));
  late String _emoji = widget.goal?.emoji ?? '🎯';
  bool _saving = false;

  static String _fmtRaw(num n) => n == n.roundToDouble() ? '${n.round()}' : '$n';

  static num? _parse(String s) => num.tryParse(s.trim().replaceAll('.', '').replaceAll(',', '.'));

  @override
  void dispose() {
    for (final c in [_title, _target, _current, _unit, _step]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = ref.read(plansRepositoryProvider);
    try {
      await repo.saveGoal(CoupleGoal(
        id: widget.goal?.id ?? '',
        title: _title.text.trim(),
        current: _parse(_current.text) ?? 0,
        target: _parse(_target.text) ?? 1,
        unit: _unit.text.trim(),
        emoji: _emoji,
        step: _parse(_step.text) ?? 1,
        createdBy: widget.goal?.createdBy ?? repo.uid,
      ));
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String? numValidator(String? v) {
      final n = _parse(v ?? '');
      if (n == null) return 'Sayı girin';
      if (n < 0) return 'Negatif olamaz';
      return null;
    }

    return SheetScaffold(
      title: widget.goal == null ? 'Yeni hedef' : 'Hedefi düzenle',
      trailing: widget.goal == null
          ? null
          : IconButton(
              onPressed: () async {
                await ref.read(plansRepositoryProvider).deleteGoal(widget.goal!.id);
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
            EmojiChoice(
              value: _emoji,
              options: const ['🎯', '🎬', '✈️', '🏙️', '💰', '📚', '🏃', '🍳', '🏡', '🎵', '🌍', '💍'],
              onChanged: (e) => setState(() => _emoji = e ?? '🎯'),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _title,
              validator: (v) => Validators.required(v, 'Başlık'),
              decoration: const InputDecoration(labelText: 'Hedef', hintText: 'Birlikte 100 film'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _current,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: numValidator,
                    decoration: const InputDecoration(labelText: 'Şu an'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _target,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: (v) {
                      final base = numValidator(v);
                      if (base != null) return base;
                      return (_parse(v!) ?? 0) <= 0 ? 'Sıfırdan büyük olmalı' : null;
                    },
                    decoration: const InputDecoration(labelText: 'Hedef'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _unit,
                    decoration: const InputDecoration(labelText: 'Birim', hintText: 'film, TL, şehir'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextFormField(
                    controller: _step,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    validator: numValidator,
                    decoration: const InputDecoration(labelText: '+ adımı'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            PrimaryButton(label: 'Kaydet', onPressed: _save, loading: _saving),
          ],
        ),
      ),
    );
  }
}
