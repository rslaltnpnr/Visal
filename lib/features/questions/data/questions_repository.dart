import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_providers.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/utils/failure.dart';
import '../domain/question.dart';
import '../domain/question_bank.dart';

final questionsRepositoryProvider = Provider<QuestionsRepository>((ref) => QuestionsRepository(
      ref.watch(supabaseProvider),
      ref.watch(tableBusProvider),
      requireCoupleId(ref),
      ref.watch(currentUidProvider)!,
    ));

class QuestionsRepository {
  QuestionsRepository(this._db, this._bus, this.coupleId, this.uid);

  final SupabaseClient _db;
  final TableBus _bus;
  final String coupleId;
  final String uid;

  SupabaseQueryBuilder get _questions => _db.from('questions');
  SupabaseQueryBuilder get _answers => _db.from('answers');
  SupabaseQueryBuilder get _moods => _db.from('moods');

  Stream<T> _watch<T>(String table, Future<T> Function() fetch, {List<String> alsoTables = const []}) =>
      watchQuery(_db, _bus, table: table, column: 'couple_id', value: coupleId, fetch: fetch, alsoTables: alsoTables);

  /// Soru yoksa açar; partner aynı anda açtıysa çakışma sessizce yok sayılır.
  Future<void> _open(String id, BankQuestion q, {String? day}) async {
    try {
      await _questions.upsert(
        {
          'couple_id': coupleId,
          'id': id,
          'text': q.text,
          'category': q.category.name,
          'bank_id': q.id,
          'day': day,
        },
        onConflict: 'couple_id,id',
        ignoreDuplicates: true,
      );
    } catch (e) {
      throw AppFailure.from(e);
    }
    _bus.bump('questions');
  }

  /// Günün sorusu (her iki partner de aynı soruyu üretir).
  Future<String> ensureDaily() async {
    final today = DateTime.now();
    final id = CoupleQuestion.dailyId(today);
    await _open(id, QuestionBank.forDay(today, coupleId), day: dayKey(today));
    return id;
  }

  /// Bankadan bir soruyu ortak soru olarak açar.
  Future<String> openBankQuestion(BankQuestion q) async {
    await _open(q.id, q);
    return q.id;
  }

  Stream<CoupleQuestion?> watchQuestion(String id) => _watch('questions', () async {
        final row = await _questions.select().eq('couple_id', coupleId).eq('id', id).maybeSingle();
        return row == null ? null : CoupleQuestion.fromRow(row);
      }, alsoTables: const ['answers']);

  Stream<List<CoupleQuestion>> watchHistory({int limit = 40}) => _watch('questions', () async {
        final rows =
            await _questions.select().eq('couple_id', coupleId).order('created_at', ascending: false).limit(limit);
        return rows.map(CoupleQuestion.fromRow).toList();
      }, alsoTables: const ['answers']);

  /// Partnerin cevabı, ben cevaplamadan veritabanından hiç dönmez (RLS).
  Stream<Answer?> watchAnswer(String questionId, String ofUid) => _watch('answers', () async {
        final row = await _answers
            .select()
            .eq('couple_id', coupleId)
            .eq('question_id', questionId)
            .eq('user_id', ofUid)
            .maybeSingle();
        return row == null ? null : Answer.fromRow(row);
      });

  /// Cevap eklenince tetikleyici sorudaki `answered_by` listesini günceller.
  Future<void> answer(String questionId, String text) async {
    try {
      await _answers.insert({
        'couple_id': coupleId,
        'question_id': questionId,
        'user_id': uid,
        'text': text.trim(),
      });
    } catch (e) {
      throw AppFailure.from(e);
    }
    _bus.bump('answers');
  }

  // ---------- Ruh hali ----------

  Future<void> setMood(String emoji) async {
    final day = dayKey(DateTime.now());
    try {
      try {
        await _moods.insert({'couple_id': coupleId, 'user_id': uid, 'day': day, 'emoji': emoji});
      } on PostgrestException catch (e) {
        if (e.code != '23505') rethrow;
        await _moods.update({'emoji': emoji}).eq('couple_id', coupleId).eq('user_id', uid).eq('day', day);
      }
    } catch (e) {
      throw AppFailure.from(e);
    }
    _bus.bump('moods');
  }

  /// Partner ruh halini gizlediyse satır dönmez -> null.
  Stream<Mood?> watchMood(String ofUid) => _watch('moods', () async {
        final row = await _moods
            .select()
            .eq('couple_id', coupleId)
            .eq('user_id', ofUid)
            .eq('day', dayKey(DateTime.now()))
            .maybeSingle();
        return row == null ? null : Mood.fromRow(row);
      }, alsoTables: const ['couple_members']);
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
