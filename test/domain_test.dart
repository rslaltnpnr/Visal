import 'package:flutter_test/flutter_test.dart';
import 'package:visal/core/utils/date_x.dart';
import 'package:visal/core/utils/validators.dart';
import 'package:visal/features/calendar/domain/plan_models.dart';
import 'package:visal/features/pairing/data/pairing_repository.dart';
import 'package:visal/features/questions/domain/question_bank.dart';

PlanEvent _event(DateTime date, RepeatRule repeat) => PlanEvent(
      id: 'e',
      title: 't',
      category: EventCategory.date,
      date: date,
      createdBy: 'u',
      repeat: repeat,
    );

void main() {
  group('tarih yardımcıları', () {
    test('birlikte geçen gün sayısı başlangıç gününü de sayar', () {
      expect(daysTogether(DateTime(2026, 9, 28), DateTime(2026, 9, 28)), 1);
      expect(daysTogether(DateTime(2023, 1, 12), DateTime(2026, 9, 28)), 1356);
    });

    test('yıllık tekrar: geçmişteyse gelecek yıla kayar', () {
      final now = DateTime(2026, 9, 28);
      expect(nextYearlyOccurrence(DateTime(1995, 10, 21), now), DateTime(2026, 10, 21));
      expect(nextYearlyOccurrence(DateTime(1995, 3, 12), now), DateTime(2027, 3, 12));
      expect(nextYearlyOccurrence(DateTime(1995, 9, 28), now), DateTime(2026, 9, 28));
    });

    test('29 Şubat artık olmayan yılda 28 Şubat olur', () {
      expect(nextYearlyOccurrence(DateTime(2024, 2, 29), DateTime(2026, 1, 1)), DateTime(2026, 2, 28));
    });

    test('kalan gün etiketi', () {
      expect(daysLeftLabel(0), 'Bugün');
      expect(daysLeftLabel(1), 'Yarın');
      expect(daysLeftLabel(23), '23 gün kaldı');
    });
  });

  group('etkinlik tekrarları', () {
    final start = DateTime(2026, 1, 15);
    test('haftalık', () {
      final e = _event(start, RepeatRule.weekly);
      expect(e.occursOn(DateTime(2026, 1, 22)), isTrue);
      expect(e.occursOn(DateTime(2026, 1, 23)), isFalse);
      expect(e.occursOn(DateTime(2026, 1, 8)), isFalse);
    });

    test('aylık ve yıllık sonraki gerçekleşme', () {
      expect(_event(start, RepeatRule.monthly).nextOccurrence(DateTime(2026, 3, 20)), DateTime(2026, 4, 15));
      expect(_event(start, RepeatRule.yearly).nextOccurrence(DateTime(2026, 3, 20)), DateTime(2027, 1, 15));
      expect(_event(start, RepeatRule.none).nextOccurrence(DateTime(2026, 3, 20)), isNull);
    });
  });

  group('günün sorusu', () {
    test('aynı gün ve çift için deterministik, günler arasında değişir', () {
      final d = DateTime(2026, 9, 28);
      expect(QuestionBank.forDay(d, 'couple-a').id, QuestionBank.forDay(d, 'couple-a').id);
      final ids = {for (var i = 0; i < 30; i++) QuestionBank.forDay(d.add(Duration(days: i)), 'couple-a').id};
      expect(ids.length, 30);
    });

    test('her kategoride soru var', () {
      for (final c in QuestionCategory.values) {
        expect(QuestionBank.byCategory(c), isNotEmpty);
      }
      expect(QuestionBank.byId('b_0')?.text, isNotEmpty);
    });
  });

  group('eşleşme kodu', () {
    test('normalize ve doğrulama', () {
      expect(PairingRepository.normalizeCode(' visal-4x72q '), 'VISAL-4X72Q');
      expect(PairingRepository.normalizeCode('4X72Q'), 'VISAL-4X72Q');
      expect(PairingRepository.isValidCode('VISAL-4X72Q'), isTrue);
      expect(PairingRepository.isValidCode('VISAL-4X7'), isFalse);
      expect(PairingRepository.isValidCode('VISAL-4O72I'), isFalse);
    });
  });

  group('doğrulayıcılar', () {
    test('şifre en az 8 karakter, harf ve rakam içerir', () {
      expect(Validators.password('kisa1'), isNotNull);
      expect(Validators.password('sadeceharf'), isNotNull);
      expect(Validators.password('guclu2026'), isNull);
    });

    test('e-posta', () {
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.email('ab.co'), isNotNull);
    });
  });
}
