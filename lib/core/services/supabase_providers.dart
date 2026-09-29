import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

final supabaseProvider = Provider<SupabaseClient>((_) => Supabase.instance.client);

/// Yerel değişiklik sinyali: bir tablo yazıldığında o tabloyu izleyen
/// sorgular hemen yenilenir (Realtime silme olaylarını filtreleyemediği için).
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

/// [fetch] sorgusunu ilk dinlemede ve [table] tablosunda
/// `[column] = [value]` olan satırlar değiştikçe yeniden çalıştırır.
/// Filtreli/sıralı listeler için kullanılır (RLS Realtime'da da uygulanır).
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
      channel = db
          .channel('watch:$table:$value:${const Uuid().v4()}')
          .onPostgresChanges(
            event: PostgresChangeEvent.all,
            schema: 'public',
            table: table,
            filter: PostgresChangeFilter(
              type: PostgresChangeFilterType.eq,
              column: column,
              value: value,
            ),
            callback: (_) => schedule(),
          )
          .subscribe();
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
