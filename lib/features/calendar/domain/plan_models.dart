import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/date_x.dart';

enum EventCategory {
  special('Özel Gün', '❤️', Color(0xFFE7A7B1)),
  date('Randevu', '🍽️', Color(0xFFB68AA0)),
  activity('Aktivite', '🎬', Color(0xFF9C8EA3)),
  travel('Seyahat', '✈️', Color(0xFF7DAF91)),
  home('Ev', '🏠', Color(0xFFD6A25A)),
  birthday('Doğum Günü', '🎂', Color(0xFFD98C9A)),
  anniversary('Yıldönümü', '💍', Color(0xFF5B274B));

  const EventCategory(this.label, this.emoji, this.color);

  final String label;
  final String emoji;
  final Color color;
}

enum RepeatRule {
  none('Tekrarlama yok'),
  daily('Her gün'),
  weekly('Her hafta'),
  monthly('Her ay'),
  yearly('Her yıl');

  const RepeatRule(this.label);

  final String label;
}

/// Hatırlatma: etkinlikten kaç dakika önce.
const kReminderOptions = <int?, String>{
  null: 'Yok',
  0: 'Etkinlik anında',
  15: '15 dakika önce',
  60: '1 saat önce',
  1440: '1 gün önce',
  10080: '1 hafta önce',
};

/// couples/{coupleId}/events/{eventId}
class PlanEvent {
  const PlanEvent({
    required this.id,
    required this.title,
    required this.category,
    required this.date,
    required this.createdBy,
    this.time,
    this.location,
    this.note,
    this.reminder,
    this.repeat = RepeatRule.none,
    this.color,
  });

  final String id;
  final String title;
  final EventCategory category;

  /// Günün başlangıcı (saat bilgisi [time] alanında).
  final DateTime date;

  /// "HH:mm" veya tüm gün için null.
  final String? time;
  final String? location;
  final String? note;
  final int? reminder;
  final RepeatRule repeat;
  final int? color;
  final String createdBy;

  Color get displayColor => color != null ? Color(color!) : category.color;

  DateTime get startsAt {
    if (time == null) return dateOnly(date);
    final parts = time!.split(':');
    return DateTime(date.year, date.month, date.day, int.parse(parts[0]), int.parse(parts[1]));
  }

  /// [day] gününde gerçekleşiyor mu (tekrarlar dahil)?
  bool occursOn(DateTime day) {
    final d = dateOnly(day);
    final start = dateOnly(date);
    if (d.isBefore(start)) return false;
    return switch (repeat) {
      RepeatRule.none => d == start,
      RepeatRule.daily => true,
      RepeatRule.weekly => d.difference(start).inDays % 7 == 0,
      RepeatRule.monthly => d.day == start.day,
      RepeatRule.yearly => d.day == start.day && d.month == start.month,
    };
  }

  /// [from] tarihinden itibaren ilk gerçekleşme günü.
  DateTime? nextOccurrence([DateTime? from]) {
    final today = dateOnly(from ?? DateTime.now());
    final start = dateOnly(date);
    if (!start.isBefore(today)) return start;
    switch (repeat) {
      case RepeatRule.none:
        return null;
      case RepeatRule.daily:
        return today;
      case RepeatRule.weekly:
        final diff = today.difference(start).inDays % 7;
        return diff == 0 ? today : today.add(Duration(days: 7 - diff));
      case RepeatRule.monthly:
        var candidate = DateTime(today.year, today.month, start.day);
        if (candidate.isBefore(today)) candidate = DateTime(today.year, today.month + 1, start.day);
        return candidate;
      case RepeatRule.yearly:
        return nextYearlyOccurrence(start, today);
    }
  }

  Map<String, dynamic> toMap() => {
        'title': title,
        'category': category.name,
        'date': Timestamp.fromDate(dateOnly(date)),
        'startsAt': Timestamp.fromDate(startsAt),
        'time': time,
        'location': location,
        'note': note,
        'reminder': reminder,
        'repeat': repeat.name,
        'color': color,
        'createdBy': createdBy,
      };

  factory PlanEvent.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return PlanEvent(
      id: doc.id,
      title: d['title'] as String? ?? '',
      category: EventCategory.values.firstWhere((c) => c.name == d['category'], orElse: () => EventCategory.special),
      date: tsToDate(d['date']) ?? DateTime.now(),
      time: d['time'] as String?,
      location: d['location'] as String?,
      note: d['note'] as String?,
      reminder: (d['reminder'] as num?)?.toInt(),
      repeat: RepeatRule.values.firstWhere((r) => r.name == d['repeat'], orElse: () => RepeatRule.none),
      color: (d['color'] as num?)?.toInt(),
      createdBy: d['createdBy'] as String? ?? '',
    );
  }
}

/// Görev ataması: Ben / Partnerim / İkimiz
const kAssignBoth = 'both';

/// couples/{coupleId}/tasks/{taskId}
class CoupleTask {
  const CoupleTask({
    required this.id,
    required this.title,
    required this.assignee,
    required this.createdBy,
    this.description = '',
    this.dueDate,
    this.done = false,
    this.doneBy,
    this.createdAt,
  });

  final String id;
  final String title;
  final String description;
  final DateTime? dueDate;

  /// uid veya [kAssignBoth]
  final String assignee;
  final bool done;
  final String? doneBy;
  final String createdBy;
  final DateTime? createdAt;

  bool get overdue => !done && dueDate != null && dateOnly(dueDate!).isBefore(dateOnly(DateTime.now()));

  Map<String, dynamic> toMap() => {
        'title': title,
        'description': description,
        'dueDate': dueDate == null ? null : Timestamp.fromDate(dueDate!),
        'assignee': assignee,
        'done': done,
        'doneBy': doneBy,
        'createdBy': createdBy,
      };

  factory CoupleTask.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CoupleTask(
      id: doc.id,
      title: d['title'] as String? ?? '',
      description: d['description'] as String? ?? '',
      dueDate: tsToDate(d['dueDate']),
      assignee: d['assignee'] as String? ?? kAssignBoth,
      done: d['done'] as bool? ?? false,
      doneBy: d['doneBy'] as String?,
      createdBy: d['createdBy'] as String? ?? '',
      createdAt: tsToDate(d['createdAt']),
    );
  }
}

/// couples/{coupleId}/goals/{goalId} — "Birlikte 100 film 43/100"
class CoupleGoal {
  const CoupleGoal({
    required this.id,
    required this.title,
    required this.current,
    required this.target,
    required this.createdBy,
    this.unit = '',
    this.emoji = '🎯',
    this.step = 1,
  });

  final String id;
  final String title;
  final num current;
  final num target;
  final String unit;
  final String emoji;
  final num step;
  final String createdBy;

  double get progress => target <= 0 ? 0 : (current / target).clamp(0, 1).toDouble();
  bool get completed => current >= target;

  Map<String, dynamic> toMap() => {
        'title': title,
        'current': current,
        'target': target,
        'unit': unit,
        'emoji': emoji,
        'step': step,
        'createdBy': createdBy,
      };

  factory CoupleGoal.fromDoc(DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data() ?? const {};
    return CoupleGoal(
      id: doc.id,
      title: d['title'] as String? ?? '',
      current: d['current'] as num? ?? 0,
      target: d['target'] as num? ?? 1,
      unit: d['unit'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '🎯',
      step: d['step'] as num? ?? 1,
      createdBy: d['createdBy'] as String? ?? '',
    );
  }
}

/// Ana ekrandaki "Yaklaşan" satırı.
class UpcomingItem {
  const UpcomingItem({
    required this.title,
    required this.date,
    required this.icon,
    required this.color,
    this.eventId,
  });

  final String title;
  final DateTime date;
  final IconData icon;
  final Color color;
  final String? eventId;

  int get daysLeft => daysUntil(date);
}
