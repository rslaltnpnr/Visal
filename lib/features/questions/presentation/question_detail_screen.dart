import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../data/questions_repository.dart';

/// Cevaplar karşılıklıdır: iki taraf da cevaplamadan partnerin cevabı açılmaz.
class QuestionDetailScreen extends ConsumerStatefulWidget {
  const QuestionDetailScreen({super.key, required this.questionId});

  final String questionId;

  @override
  ConsumerState<QuestionDetailScreen> createState() => _QuestionDetailScreenState();
}

class _QuestionDetailScreenState extends ConsumerState<QuestionDetailScreen> {
  final _answer = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _answer.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _answer.text.trim();
    if (text.isEmpty) return;
    setState(() => _sending = true);
    try {
      await ref.read(questionsRepositoryProvider).answer(widget.questionId, text);
      HapticFeedback.mediumImpact();
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final question = ref.watch(questionProvider(widget.questionId));
    final mine = ref.watch(myAnswerProvider(widget.questionId)).value;
    final theirs = ref.watch(partnerAnswerProvider(widget.questionId)).value;
    final partner = ref.watch(partnerProfileProvider);
    final partnerName = ref.watch(partnerNameProvider);
    final me = ref.watch(currentUserProvider).value;
    final pid = ref.watch(partnerIdProvider) ?? '';

    return Scaffold(
      appBar: AppBar(),
      body: AsyncView(
        value: question,
        data: (q) {
          if (q == null) return const EmptyState(icon: Icons.help_outline, title: 'Soru bulunamadı');
          final partnerAnswered = q.answered(pid);
          return ListView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
            children: [
              Text(
                '${q.category.emoji} ${q.category.label}'.toUpperCase(),
                style: context.text.labelSmall?.copyWith(color: AppColors.mauve, letterSpacing: 1.2),
              ),
              const SizedBox(height: 12),
              Text(q.text, style: context.text.headlineMedium),
              const SizedBox(height: 28),
              if (mine == null) ...[
                TextField(
                  controller: _answer,
                  minLines: 4,
                  maxLines: 10,
                  maxLength: 1000,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'İçinden geldiği gibi yaz…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.lock_outline_rounded, size: 16, color: AppColors.lavenderGrey),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        partnerAnswered
                            ? '$partnerName cevapladı. Sen de paylaşınca cevaplar açılacak.'
                            : 'Cevabın, $partnerName da cevaplayana kadar gizli kalır.',
                        style: context.text.bodySmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                PrimaryButton(
                  label: 'Cevabını Paylaş',
                  icon: Icons.arrow_forward_rounded,
                  onPressed: _send,
                  loading: _sending,
                ),
              ] else ...[
                _AnswerCard(
                  name: 'Sen',
                  photo: me?.photoUrl,
                  fullName: me?.name ?? '',
                  text: mine.text,
                  mine: true,
                ),
                const SizedBox(height: 14),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 500),
                  transitionBuilder: (c, a) => FadeTransition(
                    opacity: a,
                    child: SlideTransition(
                      position: Tween(begin: const Offset(0, 0.1), end: Offset.zero).animate(a),
                      child: c,
                    ),
                  ),
                  child: theirs != null
                      ? _AnswerCard(
                          key: const ValueKey('theirs'),
                          name: partnerName,
                          photo: partner?.photoUrl,
                          fullName: partner?.name ?? partnerName,
                          text: theirs.text,
                          mine: false,
                        )
                      : VisalCard(
                          key: const ValueKey('locked'),
                          child: Row(
                            children: [
                              const SoftIcon(Icons.hourglass_top_rounded, size: 44),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Text(
                                  '$partnerName henüz cevaplamadı. Cevapladığında burada açılacak.',
                                  style: context.text.bodyMedium,
                                ),
                              ),
                            ],
                          ),
                        ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _AnswerCard extends StatelessWidget {
  const _AnswerCard({
    super.key,
    required this.name,
    required this.photo,
    required this.fullName,
    required this.text,
    required this.mine,
  });

  final String name;
  final String? photo;
  final String fullName;
  final String text;
  final bool mine;

  @override
  Widget build(BuildContext context) => VisalCard(
        gradient: mine ? context.palette.bubbleMine : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppAvatar(url: photo, name: fullName, size: 30),
                const SizedBox(width: 10),
                Text(
                  name,
                  style: context.text.titleSmall?.copyWith(color: mine ? context.palette.bubbleMineText : null),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              text,
              style: context.text.bodyLarge?.copyWith(color: mine ? context.palette.bubbleMineText : null),
            ),
          ],
        ),
      );
}
