import 'package:flutter_test/flutter_test.dart';
import 'package:visal/core/services/supabase_providers.dart';
import 'package:visal/core/utils/date_x.dart';
import 'package:visal/features/calendar/domain/plan_models.dart';
import 'package:visal/features/chat/domain/message.dart';
import 'package:visal/features/memories/domain/memory.dart';
import 'package:visal/features/questions/domain/question.dart';

void main() {
  group('veritabanı satırı dönüşümleri', () {
    test('date ve timestamptz biçimleri', () {
      expect(dbDate(DateTime(2026, 3, 7, 23, 59)), '2026-03-07');
      final local = DateTime(2026, 3, 7, 10, 30);
      expect(DateTime.parse(dbTs(local)).isAtSameMomentAs(local), isTrue);
      expect(tsToDate('2026-03-07'), DateTime(2026, 3, 7));
      expect(tsToDate('2026-03-07T07:30:00+00:00')!.isAtSameMomentAs(DateTime.utc(2026, 3, 7, 7, 30)), isTrue);
    });

    test('anı: toRow -> fromRow', () {
      final m = Memory(
        id: 'm1',
        createdBy: 'u1',
        title: 'İlk kahve',
        date: DateTime(2024, 5, 12),
        isSpecial: true,
      );
      final row = {...m.toRow(), 'id': 'm1', 'created_by': 'u1', 'created_at': '2024-05-12T09:00:00Z'};
      expect(row['date'], '2024-05-12');
      expect(row['has_photo'], isFalse);
      final back = Memory.fromRow(row);
      expect(back.title, 'İlk kahve');
      expect(back.date, DateTime(2024, 5, 12));
      expect(back.isSpecial, isTrue);
    });

    test('etkinlik: saat ve tarih ayrı saklanır', () {
      final e = PlanEvent(
        id: '',
        title: 'Akşam yemeği',
        category: EventCategory.date,
        date: DateTime(2026, 10, 1),
        time: '20:15',
        createdBy: 'u1',
      );
      final row = e.toRow();
      expect(row['date'], '2026-10-01');
      expect(DateTime.parse(row['starts_at'] as String).isAtSameMomentAs(DateTime(2026, 10, 1, 20, 15)), isTrue);
      final back = PlanEvent.fromRow({...row, 'id': 'e1', 'created_by': 'u1'});
      expect(back.startsAt, DateTime(2026, 10, 1, 20, 15));
    });

    test('mesaj ve soru satırları', () {
      final msg = Message.fromRow({
        'id': 'x',
        'sender_id': 'u1',
        'type': 'love',
        'text': 'Seni seviyorum',
        'love_kind': LoveKind.values.first.name,
        'reactions': {'u2': '❤️'},
        'seen_by': ['u1', 'u2'],
        'created_at': '2026-09-29T10:00:00Z',
      });
      expect(msg.type, MessageType.love);
      expect(msg.loveKind, LoveKind.values.first);
      expect(msg.reactions['u2'], '❤️');
      expect(msg.seenBy, contains('u2'));

      final q = CoupleQuestion.fromRow({
        'id': 'd_2026-09-29',
        'text': 'Soru',
        'category': 'fun',
        'answered_by': ['u1'],
      });
      expect(q.isDaily, isTrue);
      expect(q.answered('u1'), isTrue);
      expect(q.bothAnswered, isFalse);
    });
  });
}
