import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/utils/date_x.dart';
import '../domain/plan_models.dart';

final plansRepositoryProvider = Provider<PlansRepository>((ref) => PlansRepository(
      ref.watch(firestoreProvider),
      requireCoupleId(ref),
      ref.watch(currentUidProvider)!,
    ));

class PlansRepository {
  PlansRepository(this._db, this.coupleId, this.uid);

  final FirebaseFirestore _db;
  final String coupleId;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _events => _db.coupleCol(coupleId, 'events');
  CollectionReference<Map<String, dynamic>> get _tasks => _db.coupleCol(coupleId, 'tasks');
  CollectionReference<Map<String, dynamic>> get _goals => _db.coupleCol(coupleId, 'goals');

  // ---------- Etkinlikler ----------

  /// Bir ay aralığındaki tek seferlik etkinlikler.
  Stream<List<PlanEvent>> watchRange(DateTime from, DateTime to) => _events
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
      .where('date', isLessThan: Timestamp.fromDate(to))
      .orderBy('date')
      .snapshots()
      .map((s) => s.docs.map(PlanEvent.fromDoc).toList());

  /// Tekrarlayan tüm etkinlikler (sayıca az).
  Stream<List<PlanEvent>> watchRepeating() => _events
      .where('repeat', whereIn: ['daily', 'weekly', 'monthly', 'yearly'])
      .snapshots()
      .map((s) => s.docs.map(PlanEvent.fromDoc).toList());

  Stream<List<PlanEvent>> watchUpcoming() => _events
      .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(dateOnly(DateTime.now())))
      .orderBy('date')
      .limit(30)
      .snapshots()
      .map((s) => s.docs.map(PlanEvent.fromDoc).toList());

  Stream<PlanEvent?> watchEvent(String id) =>
      _events.doc(id).snapshots().map((s) => s.exists ? PlanEvent.fromDoc(s) : null);

  Future<void> saveEvent(PlanEvent e) async {
    if (e.id.isEmpty) {
      await _events.doc().set({...e.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _events.doc(e.id).update({...e.toMap(), 'updatedAt': FieldValue.serverTimestamp()});
    }
  }

  Future<void> deleteEvent(String id) => _events.doc(id).delete();

  Future<int> eventCount() async => (await _events.count().get()).count ?? 0;

  // ---------- Görevler ----------

  Stream<List<CoupleTask>> watchTasks() => _tasks
      .orderBy('createdAt', descending: true)
      .limit(200)
      .snapshots()
      .map((s) => s.docs.map(CoupleTask.fromDoc).toList());

  Future<void> saveTask(CoupleTask t) async {
    if (t.id.isEmpty) {
      await _tasks.doc().set({...t.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _tasks.doc(t.id).update(t.toMap());
    }
  }

  Future<void> toggleTask(CoupleTask t) => _tasks.doc(t.id).update({
        'done': !t.done,
        'doneBy': !t.done ? uid : null,
        'doneAt': !t.done ? FieldValue.serverTimestamp() : null,
      });

  Future<void> deleteTask(String id) => _tasks.doc(id).delete();

  // ---------- Hedefler ----------

  Stream<List<CoupleGoal>> watchGoals() => _goals
      .orderBy('createdAt')
      .snapshots()
      .map((s) => s.docs.map(CoupleGoal.fromDoc).toList());

  Future<void> saveGoal(CoupleGoal g) async {
    if (g.id.isEmpty) {
      await _goals.doc().set({...g.toMap(), 'createdAt': FieldValue.serverTimestamp()});
    } else {
      await _goals.doc(g.id).update(g.toMap());
    }
  }

  Future<void> incrementGoal(String id, num delta) => _goals.doc(id).update({
        'current': FieldValue.increment(delta),
      });

  Future<void> deleteGoal(String id) => _goals.doc(id).delete();
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

final eventCountProvider = FutureProvider.autoDispose<int>(
  (ref) => ref.watch(plansRepositoryProvider).eventCount(),
);

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
