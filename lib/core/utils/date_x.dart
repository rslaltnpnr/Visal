import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

const kLocale = 'tr_TR';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime? tsToDate(Object? v) {
  if (v is Timestamp) return v.toDate();
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

/// yyyy-MM-dd biçiminde gün anahtarı (günlük soru, ruh hali vb.).
String dayKey(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

/// MM-dd (geçmişte bugün sorguları için).
String monthDayKey(DateTime d) => DateFormat('MM-dd').format(d);

extension DateFormatting on DateTime {
  String get dMMMMy => DateFormat('d MMMM y', kLocale).format(this);
  String get dMMMM => DateFormat('d MMMM', kLocale).format(this);
  String get dMMM => DateFormat('d MMM', kLocale).format(this);
  String get hm => DateFormat('HH:mm', kLocale).format(this);
  String get weekdayName => DateFormat('EEEE', kLocale).format(this);
  String get monthYear => DateFormat('MMMM y', kLocale).format(this);

  bool isSameDay(DateTime o) =>
      year == o.year && month == o.month && day == o.day;

  /// Sohbet gün ayırıcısı: Bugün / Dün / 28 Eylül 2026
  String get chatDayLabel {
    final now = DateTime.now();
    if (isSameDay(now)) return 'Bugün';
    if (isSameDay(now.subtract(const Duration(days: 1)))) return 'Dün';
    if (now.difference(this).inDays < 7) return weekdayName;
    return year == now.year ? dMMMM : dMMMMy;
  }
}

/// Başlangıç tarihinden bugüne gün sayısı (başlangıç günü = 1. gün).
int daysTogether(DateTime start, [DateTime? now]) {
  final today = dateOnly(now ?? DateTime.now());
  return today.difference(dateOnly(start)).inDays + 1;
}

/// Yıllık tekrar eden bir tarihin (doğum günü, yıldönümü) bir sonraki günü.
DateTime nextYearlyOccurrence(DateTime date, [DateTime? now]) {
  final today = dateOnly(now ?? DateTime.now());
  var next = _safeDate(today.year, date.month, date.day);
  if (next.isBefore(today)) next = _safeDate(today.year + 1, date.month, date.day);
  return next;
}

DateTime _safeDate(int y, int m, int d) {
  final last = DateTime(y, m + 1, 0).day;
  return DateTime(y, m, d > last ? last : d);
}

int daysUntil(DateTime date, [DateTime? now]) =>
    dateOnly(date).difference(dateOnly(now ?? DateTime.now())).inDays;

String daysLeftLabel(int days) {
  if (days == 0) return 'Bugün';
  if (days == 1) return 'Yarın';
  return '$days gün kaldı';
}

/// 1326 -> "1.326"
String formatThousands(num n) => NumberFormat.decimalPattern(kLocale).format(n);

String lastSeenLabel(DateTime? t) {
  if (t == null) return '';
  final now = DateTime.now();
  final diff = now.difference(t);
  if (diff.inMinutes < 1) return 'az önce görüldü';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk önce görüldü';
  if (t.isSameDay(now)) return 'bugün ${t.hm} görüldü';
  if (t.isSameDay(now.subtract(const Duration(days: 1)))) {
    return 'dün ${t.hm} görüldü';
  }
  return '${t.dMMM} ${t.hm} görüldü';
}

String relativeLabel(DateTime t) {
  final diff = DateTime.now().difference(t);
  if (diff.inMinutes < 1) return 'şimdi';
  if (diff.inMinutes < 60) return '${diff.inMinutes} dk';
  if (diff.inHours < 24) return '${diff.inHours} sa';
  if (diff.inDays < 7) return '${diff.inDays} g';
  return t.dMMM;
}

String yearsAgoLabel(int years) => years == 1 ? '1 yıl önce bugün' : '$years yıl önce bugün';

String formatDuration(Duration d) {
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return d.inHours > 0 ? '${d.inHours}:$m:$s' : '$m:$s';
}
