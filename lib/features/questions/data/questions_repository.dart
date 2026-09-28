import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/firebase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/date_x.dart';
import '../domain/question.dart';
import '../domain/question_bank.dart';

final questionsRepositoryProvider = Provider<QuestionsRepository>((ref) => QuestionsRepository(
      ref.watch(firestoreProvider),
      requireCoupleId(ref),
      ref.watch(currentUidProvider)!,
    ));

class QuestionsRepository {
  QuestionsRepository(this._db, this.coupleId, this.uid);

  final FirebaseFirestore _db;
  final String coupleId;
  final String uid;

  CollectionReference<Map<String, dynamic>> get _questions => _db.coupleCol(coupleId, 'questions');
  CollectionReference<Map<String, dynamic>> get _answers => _db.coupleCol(coupleId, 'answers');
  CollectionReference<Map<String, dynamic>> get _moods => _db.coupleCol(coupleId, 'moods');

  /// Günün sorusu belgesi yoksa oluşturur (her iki partner de aynı soruyu üretir).
  Future<String> ensureDaily() async {
    final today = DateTime.now();
    final id = CoupleQuestion.dailyId(today);
    final ref = _questions.doc(id);
    final snap = await ref.get();
    if (!snap.exists) {
      final q = QuestionBank.forDay(today, coupleId);
      try {
        await ref.set({
          'text': q.text,
          'category': q.category.name,
          'bankId': q.id,
          'day': dayKey(today),
          'answeredBy': <String>[],
          'createdAt': FieldValue.serverTimestamp(),
        });
      } on FirebaseException catch (e) {
        // Partner aynı anda oluşturduysa kurallar ikinci yazmayı reddeder.
        if (e.code != 'permission-denied') rethrow;
      }
    }
    return id;
  }

  /// Bankadan bir soruyu ortak soru olarak açar.
  Future<String> openBankQuestion(BankQuestion q) async {
    final ref = _questions.doc(q.id);
    final snap = await ref.get();
    if (!snap.exists) {
      await ref.set({
        'text': q.text,
        'category': q.category.name,
        'bankId': q.id,
        'day': null,
        'answeredBy': <String>[],
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    return q.id;
  }

  Stream<CoupleQuestion?> watchQuestion(String id) =>
      _questions.doc(id).snapshots().map((s) => s.exists ? CoupleQuestion.fromDoc(s) : null);

  Stream<List<CoupleQuestion>> watchHistory({int limit = 40}) => _questions
      .orderBy('createdAt', descending: true)
      .limit(limit)
      .snapshots()
      .map((s) => s.docs.map(CoupleQuestion.fromDoc).toList());

  Stream<Answer?> watchAnswer(String questionId, String ofUid) => _answers
      .doc(Answer.docId(questionId, ofUid))
      .snapshots()
      .map((s) => s.exists ? Answer.fromDoc(s) : null);

  Future<void> answer(String questionId, String text) async {
    final batch = _db.batch();
    batch.set(_answers.doc(Answer.docId(questionId, uid)), {
      'uid': uid,
      'questionId': questionId,
      'text': text.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
    batch.update(_questions.doc(questionId), {
      'answeredBy': FieldValue.arrayUnion([uid]),
    });
    await batch.commit();
  }

  // ---------- Ruh hali ----------

  Future<void> setMood(String emoji) {
    final today = DateTime.now();
    return _moods.doc(Mood.docId(today, uid)).set({
      'uid': uid,
      'day': dayKey(today),
      'emoji': emoji,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Stream<Mood?> watchMood(String ofUid) => _moods
      .doc(Mood.docId(DateTime.now(), ofUid))
      .snapshots()
      .map((s) => s.exists ? Mood.fromDoc(s) : null);
}

final dailyQuestionIdProvider = FutureProvider.autoDispose<String>(
  (ref) => ref.watch(questionsRepositoryProvider).ensureDaily(),
);

final questionProvider = StreamProvider.autoDispose.family<CoupleQuestion?, String>(
  (ref, id) => ref.watch(questionsRepositoryProvider).watchQuestion(id),
);

final questionHistoryProvider = StreamProvider.autoDispose<List<CoupleQuestion>>(
  (ref) => ref.watch(questionsRepositoryProvider).watchHistory(),
);

final myAnswerProvider = StreamProvider.autoDispose.family<Answer?, String>((ref, qid) {
  final repo = ref.watch(questionsRepositoryProvider);
  return repo.watchAnswer(qid, repo.uid);
});

/// Partnerin cevabı: yalnızca ben cevapladıktan sonra dinlenir; kurallar da
/// aksi halde okumayı reddeder.
final partnerAnswerProvider = StreamProvider.autoDispose.family<Answer?, String>((ref, qid) {
  final mine = ref.watch(myAnswerProvider(qid)).value;
  final pid = ref.watch(partnerIdProvider);
  if (mine == null || pid == null) return Stream.value(null);
  return ref.watch(questionsRepositoryProvider).watchAnswer(qid, pid);
});

final myMoodProvider = StreamProvider.autoDispose<Mood?>((ref) {
  final repo = ref.watch(questionsRepositoryProvider);
  return repo.watchMood(repo.uid);
});

/// Partner ruh halini gizlediyse kurallar okumayı reddeder -> null.
final partnerMoodProvider = StreamProvider.autoDispose<Mood?>((ref) {
  final pid = ref.watch(partnerIdProvider);
  if (pid == null) return Stream.value(null);
  return ref
      .watch(questionsRepositoryProvider)
      .watchMood(pid)
      .handleError((Object _) {});
});
