import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final supabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

/// Yerel değişiklik sinyali: bir tablo yazıldığında o tabloyu izleyen
/// sorgular hemen yenilenir. Uzak cihaz değişiklikleri Realtime ile izlenir.
class TableBus {
  final _controller = StreamController<String>.broadcast();

  Stream<String> get changes => _controller.stream;

  void bump(String table) => _controller.add(table);

  void dispose() => _controller.close();
}

final tableBusProvider = Provider<TableBus>((ref) {
  final bus = TableBus();
  ref.onDispose(bus.dispose);
  return bus;
});

/// [fetch] sorgusunu ilk dinlemede ve ilgili Realtime olaylarında yeniden
/// çalıştırır. Ana tablonun INSERT/UPDATE olayları filtrelenir. Supabase
/// Postgres Changes DELETE olaylarında kolon filtresi güvenilir olmadığından
/// ayrıca DELETE dinleyicisi kullanılır. [alsoTables] da uzak cihazlarda
/// dinlenir; böylece örneğin privacy/couple_members değişiklikleri anında
/// sorguyu yeniler.
Stream<T> watchQuery<T>(
  SupabaseClient db,
  TableBus bus, {
  required String table,
  required String column,
  required Object value,
  required Future<T> Function() fetch,
  List<String> alsoTables = const [],
}) {
  late final StreamController<T> controller;
  RealtimeChannel? channel;
  StreamSubscription<String>? busSub;
  Timer? debounce;
  var closed = false;

  Future<void> emit() async {
    try {
      final result = await fetch();
      if (!closed) controller.add(result);
    } catch (e, s) {
      if (!closed) controller.addError(e, s);
    }
  }

  void schedule() {
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 120), emit);
  }

  controller = StreamController<T>(
    onListen: () {
      emit();
      var ch = db
          .channel('watch:$table:$value:${const Uuid().v4()}')
          .onPostgresChanges(
            event: PostgresChangeEvent.insert,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: column,
              value: value,
            ),
            callback: (_) => schedule(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.update,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: column,
              value: value,
            ),
            callback: (_) => schedule(),
          )
          .onPostgresChanges(
            event: PostgresChangeEvent.delete,
            schema: 'public',
            table: table,
            callback: (_) => schedule(),
          );
      for (final related in alsoTables.toSet()) {
        if (related == table) continue;
        ch = ch.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: related,
          callback: (_) => schedule(),
        );
      }
      channel = ch.subscribe();
      busSub = bus.changes.where((t) => t == table || alsoTables.contains(t)).listen((_) => schedule());
    },
    onCancel: () async {
      closed = true;
      debounce?.cancel();
      await busSub?.cancel();
      final ch = channel;
      if (ch != null) await db.removeChannel(ch);
    },
  );
  return controller.stream;
}

/// Tarih kolonları (date) için 'yyyy-MM-dd'.
String dbDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Zaman damgası kolonları (timestamptz) için UTC ISO-8601.
String dbTs(DateTime d) => d.toUtc().toIso8601String();
