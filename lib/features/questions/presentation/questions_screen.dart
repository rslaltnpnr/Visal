import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../data/questions_repository.dart';
import '../domain/question.dart';
import '../domain/question_bank.dart';

class QuestionsScreen extends ConsumerWidget {
  const QuestionsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dailyId = ref.watch(dailyQuestionIdProvider).value;
    final daily = dailyId == null ? null : ref.watch(questionProvider(dailyId)).value;
    final history = ref.watch(questionHistoryProvider).value ?? const <CoupleQuestion>[];
    final uid = ref.watch(currentUidProvider) ?? '';
    final partner = ref.watch(partnerNameProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Sorular')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
        children: [
          VisalCard(
            gradient: AppColors.chatPlumTile,
            radius: AppRadii.cardLarge,
            padding: const EdgeInsets.all(22),
            onTap: dailyId == null ? null : () => context.push(Routes.question(dailyId)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.wb_sunny_outlined, color: AppColors.rose, size: 20),
                    const SizedBox(width: 8),
                    Text('Bugünün Sorusu', style: context.text.labelLarge?.copyWith(color: AppColors.rose)),
                    const Spacer(),
                    if (daily != null)
                      Text(
                        '${daily.category.emoji} ${daily.category.label}',
                        style: context.text.labelSmall?.copyWith(color: Colors.white70),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  daily?.text ?? '…',
                  style: context.text.headlineSmall?.copyWith(color: Colors.white, fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 18),
                GradientButton(
                  label: daily?.answered(uid) ?? false
                      ? (daily!.bothAnswered ? 'Cevapları Gör' : '$partner bekleniyor')
                      : 'Cevabını Paylaş',
                  height: 50,
                  onPressed: dailyId == null ? null : () => context.push(Routes.question(dailyId)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          const SectionHeader(title: 'Kategoriler'),
          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 10,
            crossAxisSpacing: 10,
            childAspectRatio: 2.6,
            children: [
              for (final c in QuestionCategory.values)
                VisalCard(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  radius: AppRadii.tile,
                  onTap: () => _openCategory(context, ref, c),
                  child: Row(
                    children: [
                      Text(c.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          c.label,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 28),
            const SectionHeader(title: 'Geçmiş sorular'),
            for (final q in history)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: VisalCard(
                  padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
                  onTap: () => context.push(Routes.question(q.id)),
                  child: Row(
                    children: [
                      Text(q.category.emoji, style: const TextStyle(fontSize: 22)),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(q.text, maxLines: 2, overflow: TextOverflow.ellipsis, style: context.text.titleSmall),
                            const SizedBox(height: 4),
                            Text(
                              q.bothAnswered
                                  ? 'İkiniz de cevapladınız 💞'
                                  : q.answered(uid)
                                      ? '$partner bekleniyor'
                                      : 'Senin cevabın bekleniyor',
                              style: context.text.bodySmall?.copyWith(
                                color: q.bothAnswered ? AppColors.success : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        q.bothAnswered ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
                        size: 18,
                        color: context.palette.muted,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ],
      ),
    );
  }

  void _openCategory(BuildContext context, WidgetRef ref, QuestionCategory c) {
    final questions = QuestionBank.byCategory(c);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.75,
        child: SheetScaffold(
          title: '${c.emoji} ${c.label}',
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
            itemCount: questions.length,
            separatorBuilder: (_, _) => const Divider(indent: 20, endIndent: 20),
            itemBuilder: (_, i) => ListTile(
              title: Text(questions[i].text),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () async {
                Navigator.pop(ctx);
                try {
                  final id = await ref.read(questionsRepositoryProvider).openBankQuestion(questions[i]);
                  if (context.mounted) context.push(Routes.question(id));
                } catch (e) {
                  if (context.mounted) context.showError(e);
                }
              },
            ),
          ),
        ),
      ),
    );
  }
}
