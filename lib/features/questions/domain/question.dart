import '../../../core/utils/date_x.dart';
import 'question_bank.dart';

/// couples/{coupleId}/questions/{questionId}
/// Günlük soru kimliği: `d_yyyy-MM-dd`; bankadan seçilen: `b_{index}`.
class CoupleQuestion {
  const CoupleQuestion({
    required this.id,
    required this.text,
    required this.category,
    this.day,
    this.answeredBy = const [],
    this.createdAt,
  });

  final String id;
  final String text;
  final QuestionCategory category;
  final String? day;
  final List<String> answeredBy;
  final DateTime? createdAt;

  bool get isDaily => id.startsWith('d_');
  bool answered(String uid) => answeredBy.contains(uid);
  bool get bothAnswered => answeredBy.length >= 2;

  static String dailyId(DateTime day) => 'd_${dayKey(day)}';

  factory CoupleQuestion.fromRow(Map<String, dynamic> d) {
    return CoupleQuestion(
      id: d['id'] as String,
      text: d['text'] as String? ?? '',
      category: QuestionCategory.values.firstWhere(
        (c) => c.name == d['category'],
        orElse: () => QuestionCategory.relationship,
      ),
      day: d['day'] as String?,
      answeredBy: List<String>.from(d['answered_by'] as List? ?? const []),
      createdAt: tsToDate(d['created_at']),
    );
  }
}

/// couples/{coupleId}/answers/{questionId}_{uid}
/// Güvenlik kuralları partnerin cevabını, kullanıcı kendi cevabını yazana
/// kadar okunamaz kılar.
class Answer {
  const Answer({required this.uid, required this.questionId, required this.text, this.createdAt});

  final String uid;
  final String questionId;
  final String text;
  final DateTime? createdAt;

  static String docId(String questionId, String uid) => '${questionId}_$uid';

  factory Answer.fromRow(Map<String, dynamic> d) {
    return Answer(
      uid: d['user_id'] as String? ?? '',
      questionId: d['question_id'] as String? ?? '',
      text: d['text'] as String? ?? '',
      createdAt: tsToDate(d['created_at']),
    );
  }
}

const kMoods = ['😍', '😊', '🙂', '😐', '😔', '😡', '🥱', '🤒'];

const kMoodLabels = {
  '😍': 'Âşık',
  '😊': 'Mutlu',
  '🙂': 'İyi',
  '😐': 'Normal',
  '😔': 'Üzgün',
  '😡': 'Kızgın',
  '🥱': 'Yorgun',
  '🤒': 'Hasta',
};

/// couples/{coupleId}/moods/{yyyy-MM-dd}_{uid} — günde bir kez.
class Mood {
  const Mood({required this.uid, required this.day, required this.emoji, this.createdAt});

  final String uid;
  final String day;
  final String emoji;
  final DateTime? createdAt;

  String get label => kMoodLabels[emoji] ?? '';

  static String docId(DateTime day, String uid) => '${dayKey(day)}_$uid';

  factory Mood.fromRow(Map<String, dynamic> d) {
    return Mood(
      uid: d['user_id'] as String? ?? '',
      day: d['day'] as String? ?? '',
      emoji: d['emoji'] as String? ?? '🙂',
      createdAt: tsToDate(d['created_at']),
    );
  }
}
