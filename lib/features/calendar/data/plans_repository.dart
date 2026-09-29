import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/utils/failure.dart';
import '../domain/plan_models.dart';

final plansRepositoryProvider = Provider<PlansRepository>((ref) => PlansRepository(
      ref.watch(supabaseProvider),
      ref.watch(tableBusProvider),
      requireCoupleId(ref),
      ref.watch(currentUidProvider)!,
    ));

class PlansRepository {
  PlansRepository(this._db, this._bus, this.coupleId, this.uid);

  final SupabaseClient _db;
  final TableBus _bus;
  final String coupleId;
  final String uid;

  SupabaseQueryBuilder get _events => _db.from('events');
  SupabaseQueryBuilder get _tasks => _db.from('tasks');
  SupabaseQueryBuilder get _goals => _db.from('goals');

  Stream<T> _watch<T>(String table, Future<T> Function() fetch) =>
      watchQuery(_db, _bus, table: table, column: 'couple_id', value: coupleId, fetch: fetch);

  Future<void> _write(String table, Future<void> Function() op) async {
    try {
      await op();
    } catch (e) {
      throw AppFailure.from(e);
    }
    _bus.bump(table);
  }

  // ---------- Etkinlikler ----------

  /// Bir ay aralığındaki tek seferlik etkinlikler.
  Stream<List<PlanEvent>> watchRange(DateTime from, DateTime to) => _watch('events', () async {
        final rows = await _events
            .select()
            .eq('couple_id', coupleId)
            .gte('date', dbDate(from))
            .lt('date', dbDate(to))
            .order('date')
            .order('starts_at');
        return rows.map(PlanEvent.fromRow).toList();
      });

  /// Tekrarlayan tüm etkinlikler (sayıca az).
  Stream<List<PlanEvent>> watchRepeating() => _watch('events', () async {
        final rows = await _events.select().eq('couple_id', coupleId).neq('repeat', 'none').limit(200);
        return rows.map(PlanEvent.fromRow).toList();
      });

  Stream<List<PlanEvent>> watchUpcoming() => _watch('events', () async {
        final rows = await _events
            .select()
            .eq('couple_id', coupleId)
            .gte('date', dbDate(DateTime.now()))
            .order('date')
            .order('starts_at')
            .limit(30);
        return rows.map(PlanEvent.fromRow).toList();
      });

  Stream<PlanEvent?> watchEvent(String id) => _watch('events', () async {
        final row = await _events.select().eq('id', id).maybeSingle();
        return row == null ? null : PlanEvent.fromRow(row);
      });

  Future<void> saveEvent(PlanEvent e) => _write('events', () async {
        if (e.id.isEmpty) {
          await _events.insert({...e.toRow(), 'couple_id': coupleId, 'created_by': uid});
        } else {
          await _events.update({...e.toRow(), 'updated_at': dbTs(DateTime.now())}).eq('id', e.id);
        }
      });

  Future<void> deleteEvent(String id) => _write('events', () => _events.delete().eq('id', id));

  Future<int> eventCount() async {
    final res = await _events.select('id').eq('couple_id', coupleId).count(CountOption.exact);
    return res.count;
  }

  // ---------- Görevler ----------

  Stream<List<CoupleTask>> watchTasks() => _watch('tasks', () async {
        final rows =
            await _tasks.select().eq('couple_id', coupleId).order('created_at', ascending: false).limit(200);
        return rows.map(CoupleTask.fromRow).toList();
      });

  Future<void> saveTask(CoupleTask t) => _write('tasks', () async {
        if (t.id.isEmpty) {
          await _tasks.insert({...t.toRow(), 'couple_id': coupleId, 'created_by': uid});
        } else {
          await _tasks.update(t.toRow()).eq('id', t.id);
        }
      });

  Future<void> toggleTask(CoupleTask t) => _write(
        'tasks',
        () => _tasks.update({
          'done': !t.done,
          'done_by': !t.done ? uid : null,
          'done_at': !t.done ? dbTs(DateTime.now()) : null,
        }).eq('id', t.id),
      );

  Future<void> deleteTask(String id) => _write('tasks', () => _tasks.delete().eq('id', id));

  // ---------- Hedefler ----------

  Stream<List<CoupleGoal>> watchGoals() => _watch('goals', () async {
        final rows = await _goals.select().eq('couple_id', coupleId).order('created_at');
        return rows.map(CoupleGoal.fromRow).toList();
      });

  Future<void> saveGoal(CoupleGoal g) => _write('goals', () async {
        if (g.id.isEmpty) {
          await _goals.insert({...g.toRow(), 'couple_id': coupleId, 'created_by': uid});
        } else {
          await _goals.update(g.toRow()).eq('id', g.id);
        }
      });

  /// Atomik artış (iki kişi aynı anda bassa da kayıp olmaz).
  Future<void> incrementGoal(String id, num delta) =>
      _write('goals', () => _db.rpc<void>('increment_goal', params: {'p_id': id, 'p_delta': delta}));

  Future<void> deleteGoal(String id) => _write('goals', () => _goals.delete().eq('id', id));
}

final repeatingEventsProvider = StreamProvider.autoDispose<List<PlanEvent>>(
  (ref) => ref.watch(plansRepositoryProvider).watchRepeating(),
);

final monthEventsProvider = StreamProvider.autoDispose.family<List<PlanEvent>, DateTime>((ref, month) {
  final from = DateTime(month.year, month.month);
  final to = DateTime(month.year, month.month + 1);
  return ref.watch(plansRepositoryProvider).watchRange(from, to);
});

final eventProvider = StreamProvider.autoDispose.family<PlanEvent?, String>(
  (ref, id) => ref.watch(plansRepositoryProvider).watchEvent(id),
);

final tasksProvider = StreamProvider.autoDispose<List<CoupleTask>>(
  (ref) => ref.watch(plansRepositoryProvider).watchTasks(),
);

final goalsProvider = StreamProvider.autoDispose<List<CoupleGoal>>(
  (ref) => ref.watch(plansRepositoryProvider).watchGoals(),
);

final eventCountProvider = FutureProvider.autoDispose<int>((ref) {
  final sub = ref.watch(tableBusProvider).changes.where((t) => t == 'events').listen((_) => ref.invalidateSelf());
  ref.onDispose(sub.cancel);
  return ref.watch(plansRepositoryProvider).eventCount();
});

final _upcomingEventsProvider = StreamProvider.autoDispose<List<PlanEvent>>(
  (ref) => ref.watch(plansRepositoryProvider).watchUpcoming(),
);

/// Yıldönümü, doğum günleri ve etkinliklerden oluşan "Yaklaşan" listesi.
final upcomingProvider = Provider.autoDispose<List<UpcomingItem>>((ref) {
  final items = <UpcomingItem>[];
  final couple = ref.watch(coupleProvider).value;
  final me = ref.watch(currentUserProvider).value;
  final partner = ref.watch(partnerProfileProvider);
  final today = dateOnly(DateTime.now());
  final horizon = today.add(const Duration(days: 365));

  final anniversary = couple?.effectiveAnniversary;
  if (anniversary != null) {
    items.add(UpcomingItem(
      title: 'Yıldönümü',
      date: nextYearlyOccurrence(anniversary),
      icon: Icons.favorite_rounded,
      color: AppColors.rose,
    ));
  }
  if (me?.birthday != null) {
    items.add(UpcomingItem(
      title: 'Doğum günün',
      date: nextYearlyOccurrence(me!.birthday!),
      icon: Icons.card_giftcard_rounded,
      color: AppColors.mauve,
    ));
  }
  if (partner?.birthday != null) {
    items.add(UpcomingItem(
      title: '${partner!.firstName} doğum günü',
      date: nextYearlyOccurrence(partner.birthday!),
      icon: Icons.card_giftcard_rounded,
      color: AppColors.mauve,
    ));
  }

  final events = [
    ...?ref.watch(_upcomingEventsProvider).value,
    ...?ref.watch(repeatingEventsProvider).value,
  ];
  final seen = <String>{};
  for (final e in events) {
    if (!seen.add(e.id)) continue;
    final next = e.nextOccurrence(today);
    if (next == null || next.isAfter(horizon)) continue;
    items.add(UpcomingItem(
      title: e.title,
      date: next,
      icon: switch (e.category) {
        EventCategory.birthday => Icons.cake_outlined,
        EventCategory.anniversary => Icons.favorite_rounded,
        EventCategory.travel => Icons.flight_takeoff_rounded,
        EventCategory.date => Icons.restaurant_rounded,
        EventCategory.activity => Icons.movie_outlined,
        EventCategory.home => Icons.home_outlined,
        EventCategory.special => Icons.auto_awesome_outlined,
      },
      color: e.displayColor,
      eventId: e.id,
    ));
  }
  items.sort((a, b) => a.date.compareTo(b.date));
  return items;
});
