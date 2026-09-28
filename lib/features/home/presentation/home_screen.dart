import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_assets.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/visal_logo.dart';
import '../../calendar/data/plans_repository.dart';
import '../../calendar/domain/plan_models.dart';
import '../../memories/data/memories_repository.dart';
import '../../memories/domain/memory.dart';
import '../../profile/data/profile_repository.dart';
import '../../profile/presentation/cover_photo_sheet.dart';
import '../../questions/data/questions_repository.dart';
import '../../questions/domain/question.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        body: RefreshIndicator(
          color: AppColors.mauve,
          onRefresh: () async {
            ref.invalidate(memoryCountProvider);
            ref.invalidate(eventCountProvider);
          },
          // Kartlar hero'nun üzerine taşar; tek Column içinde çizim sırası korunur.
          child: const SingleChildScrollView(
            physics: AlwaysScrollableScrollPhysics(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Hero(),
                _OverlapUp(
                  by: 26,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(14, 0, 14, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SummaryCard(),
                        SizedBox(height: 14),
                        _QuickAccess(),
                        SizedBox(height: 14),
                        _QuestionAndUpcoming(),
                        SizedBox(height: 14),
                        _MoodCard(),
                        SizedBox(height: 14),
                        _OnThisDay(),
                        _MoreCards(),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Çocuğu [by] kadar yukarı kaydırır ve yerleşimde de bu kadar yer kazanır.
class _OverlapUp extends SingleChildRenderObjectWidget {
  const _OverlapUp({required this.by, required super.child});

  final double by;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderOverlapUp(by);

  @override
  void updateRenderObject(BuildContext context, _RenderOverlapUp renderObject) => renderObject.by = by;
}

class _RenderOverlapUp extends RenderProxyBox {
  _RenderOverlapUp(this._by);

  double _by;
  set by(double v) {
    if (v == _by) return;
    _by = v;
    markNeedsLayout();
  }

  @override
  void performLayout() {
    child!.layout(constraints, parentUsesSize: true);
    size = constraints.constrain(Size(child!.size.width, child!.size.height - _by));
  }

  @override
  void paint(PaintingContext context, Offset offset) => context.paintChild(child!, offset.translate(0, -_by));

  @override
  bool hitTestChildren(BoxHitTestResult result, {required Offset position}) => result.addWithPaintOffset(
    offset: Offset(0, -_by),
    position: position,
    hitTest: (r, p) => child!.hitTest(r, position: p),
  );

  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) => transform.translateByDouble(0, -_by, 0, 1);
}

// ---------------------------------------------------------------------------
// Hero
// ---------------------------------------------------------------------------

class _Hero extends ConsumerWidget {
  const _Hero();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(coupleProvider).value;
    final since = couple?.togetherSince;
    final days = since == null ? null : daysTogether(since);
    final hasUnread = ref.watch(unreadInboxProvider);
    final top = MediaQuery.paddingOf(context).top;
    final cover = couple?.coverPhoto;

    return GestureDetector(
      // Uzun basınca kapak fotoğrafını değiştir.
      onLongPress: () => showCoverPhotoSheet(context, ref, hasCover: cover != null),
      child: SizedBox(
        height: 360 + top,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Hero(
              tag: 'cover',
              child: cover != null
                  ? NetImage(cover)
                  : Image.asset(AppAssets.heroDefault, fit: BoxFit.cover, alignment: const Alignment(0.3, -0.2)),
            ),
            // Sinematik karartma
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x881A1124), Color(0x221A1124), Color(0x551A1124), Color(0xCC1A1124)],
                  stops: [0, 0.3, 0.6, 1],
                ),
              ),
            ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [Color(0x661A1124), Color(0x001A1124)],
                  stops: [0, 0.6],
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(24, top + 14, 18, 48),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const VisalHorizontalLogo(height: 40),
                      const Spacer(),
                      GlassIconButton(
                        icon: Icons.notifications_none_rounded,
                        badge: hasUnread,
                        onPressed: () => context.push(Routes.notifications),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Row(
                    children: [
                      Text(
                        'Biz',
                        style: context.text.titleLarge?.copyWith(
                          color: AppColors.ivory,
                          fontWeight: FontWeight.w500,
                          letterSpacing: 1,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(width: 34, height: 1.2, color: AppColors.ivory.withValues(alpha: 0.8)),
                    ],
                  ),
                  const SizedBox(height: 6),
                  if (days != null)
                    _AnimatedDays(days: days)
                  else
                    GestureDetector(
                      onTap: () => context.push(Routes.relationship),
                      child: Text(
                        'Başlangıç tarihinizi ekleyin →',
                        style: context.text.headlineSmall?.copyWith(color: AppColors.ivory),
                      ),
                    ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          'İkinize ait bir alan.',
                          style: context.text.bodyLarge?.copyWith(
                            color: AppColors.ivory.withValues(alpha: 0.9),
                            letterSpacing: 3.2,
                            fontWeight: FontWeight.w300,
                          ),
                        ),
                      ),
                      const _Heartline(),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Gün sayacı: açılışta yumuşakça sayar.
class _AnimatedDays extends StatelessWidget {
  const _AnimatedDays({required this.days});

  final int days;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: days * 0.85, end: days.toDouble()),
      duration: const Duration(milliseconds: 1400),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: formatThousands(v.round()),
              style: context.text.displayLarge?.copyWith(
                color: AppColors.ivory,
                fontSize: 56,
                fontWeight: FontWeight.w600,
              ),
            ),
            TextSpan(
              text: '  gündür birlikte',
              style: context.text.headlineMedium?.copyWith(color: AppColors.ivory, fontWeight: FontWeight.w400),
            ),
          ],
        ),
      ),
    );
  }
}

class _Heartline extends StatelessWidget {
  const _Heartline();

  @override
  Widget build(BuildContext context) =>
      Icon(Icons.favorite_border_rounded, color: AppColors.ivory.withValues(alpha: 0.85), size: 40, weight: 200);
}

// ---------------------------------------------------------------------------
// İlişki Özetimiz
// ---------------------------------------------------------------------------

class _SummaryCard extends ConsumerWidget {
  const _SummaryCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final couple = ref.watch(coupleProvider).value;
    final since = couple?.togetherSince;
    final days = since == null ? 0 : daysTogether(since);
    final memories = ref.watch(memoryCountProvider).value ?? 0;
    final plans = ref.watch(eventCountProvider).value ?? 0;

    return VisalCard(
      radius: AppRadii.cardLarge,
      padding: const EdgeInsets.fromLTRB(18, 18, 14, 18),
      color: context.isDark ? AppColors.darkCard : AppColors.lightSurface,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 60,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InkWell(
                    onTap: () => context.push(Routes.story),
                    borderRadius: BorderRadius.circular(20),
                    child: Row(
                      children: [
                        const SoftIcon(Icons.favorite_rounded, size: 38),
                        const SizedBox(width: 10),
                        Flexible(
                          child: Text(
                            'İlişki Özetimiz',
                            style: context.text.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(shape: BoxShape.circle, color: context.palette.softAccent),
                          child: Icon(Icons.chevron_right_rounded, size: 18, color: context.palette.textPrimary),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Daha derin bağlar, daha güzel anlar. Birlikte büyüyen hikâyeniz her geçen gün daha özel.',
                    style: context.text.bodySmall?.copyWith(fontSize: 12.5, height: 1.5),
                  ),
                  const Spacer(),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _Stat(icon: Icons.favorite_rounded, value: formatThousands(days), label: 'Gündür birlikte'),
                      const _VDivider(),
                      _Stat(icon: Icons.star_rounded, value: formatThousands(memories), label: 'Güzel anı'),
                      const _VDivider(),
                      _Stat(icon: Icons.people_outline_rounded, value: formatThousands(plans), label: 'Birlikte plan'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 40,
              child: GestureDetector(
                onTap: () => context.go(Routes.memories),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(20),
                  child: Image.asset(AppAssets.togetherCard, fit: BoxFit.cover),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) => Expanded(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftIcon(icon, size: 32),
        const SizedBox(height: 8),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(value, style: context.text.titleMedium?.copyWith(fontSize: 17)),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(label, maxLines: 1, style: context.text.labelSmall?.copyWith(fontSize: 10.5)),
        ),
      ],
    ),
  );
}

class _VDivider extends StatelessWidget {
  const _VDivider();

  @override
  Widget build(BuildContext context) => Container(
    width: 1,
    height: 64,
    margin: const EdgeInsets.symmetric(horizontal: 5),
    color: Theme.of(context).colorScheme.outlineVariant,
  );
}

// ---------------------------------------------------------------------------
// Hızlı Erişim
// ---------------------------------------------------------------------------

class _QuickAccess extends StatelessWidget {
  const _QuickAccess();

  @override
  Widget build(BuildContext context) {
    return VisalCard(
      radius: AppRadii.cardLarge,
      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
      color: context.isDark ? AppColors.darkCard : AppColors.lightSurface,
      child: Column(
        children: [
          SectionHeader(
            title: 'Hızlı Erişim',
            actionLabel: 'Tümünü Gör',
            onAction: () => _showAll(context),
            padding: const EdgeInsets.fromLTRB(8, 0, 0, 14),
          ),
          Row(
            children: [
              _QuickTile(
                icon: Icons.chat_bubble_outline_rounded,
                title: 'Sohbet',
                subtitle: 'Daha yakın konuşun.',
                gradient: AppColors.chatPlumTile,
                light: true,
                onTap: () => context.go(Routes.chat),
              ),
              _QuickTile(
                icon: Icons.photo_outlined,
                title: 'Anılar',
                subtitle: 'Güzel anılarınızı biriktirin.',
                gradient: AppColors.roseTile,
                light: true,
                onTap: () => context.go(Routes.memories),
              ),
              _QuickTile(
                icon: Icons.calendar_today_outlined,
                title: 'Takvim',
                subtitle: 'Özel günlerinizi planlayın.',
                gradient: AppColors.mauveTile,
                light: true,
                onTap: () => context.go(Routes.plans),
              ),
              _QuickTile(
                icon: Icons.favorite_border_rounded,
                title: 'Sorular',
                subtitle: 'Birbirinizi daha iyi tanıyın.',
                gradient: context.isDark
                    ? const LinearGradient(colors: [Color(0xFF3A2A38), Color(0xFF2E2230)])
                    : AppColors.ivoryTile,
                light: context.isDark,
                onTap: () => context.push(Routes.questions),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showAll(BuildContext context) {
    final items = <(IconData, String, VoidCallback)>[
      (Icons.chat_bubble_outline_rounded, 'Sohbet', () => context.go(Routes.chat)),
      (Icons.photo_outlined, 'Anılar', () => context.go(Routes.memories)),
      (Icons.calendar_today_outlined, 'Takvim', () => context.go(Routes.plans)),
      (Icons.checklist_rounded, 'Görevler', () => context.go('${Routes.plans}?tab=tasks')),
      (Icons.flag_outlined, 'Hedefler', () => context.go('${Routes.plans}?tab=goals')),
      (Icons.favorite_border_rounded, 'Sorular', () => context.push(Routes.questions)),
      (Icons.hourglass_bottom_rounded, 'Anı Kapsülü', () => context.push(Routes.capsules)),
      (Icons.auto_stories_outlined, 'Hikâyemiz', () => context.push(Routes.story)),
    ];
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SheetScaffold(
        title: 'Tümü',
        child: GridView.count(
          shrinkWrap: true,
          crossAxisCount: 4,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          children: [
            for (final (icon, label, action) in items)
              InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  Navigator.pop(ctx);
                  action();
                },
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SoftIcon(icon, size: 50),
                    const SizedBox(height: 8),
                    Text(label, style: ctx.text.labelMedium, textAlign: TextAlign.center),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.onTap,
    this.light = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Gradient gradient;
  final VoidCallback onTap;
  final bool light;

  @override
  Widget build(BuildContext context) {
    final fg = light ? Colors.white : AppColors.wine;
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 3),
        child: SizedBox(
          height: 138,
          child: Material(
            borderRadius: BorderRadius.circular(AppRadii.tile),
            clipBehavior: Clip.antiAlias,
            child: Ink(
              decoration: BoxDecoration(gradient: gradient),
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(6, 12, 6, 10),
                  child: Column(
                    children: [
                      Icon(icon, color: fg, size: 28),
                      const Spacer(),
                      Text(
                        title,
                        style: context.text.titleSmall?.copyWith(color: light ? Colors.white : AppColors.textPrimary),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: context.text.labelSmall?.copyWith(
                          fontSize: 10,
                          height: 1.3,
                          color: light ? Colors.white.withValues(alpha: 0.85) : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bugünün Sorusu + Yaklaşan
// ---------------------------------------------------------------------------

class _QuestionAndUpcoming extends StatelessWidget {
  const _QuestionAndUpcoming();

  @override
  Widget build(BuildContext context) {
    return const IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(flex: 58, child: _TodayQuestionCard()),
          SizedBox(width: 10),
          Expanded(flex: 42, child: _UpcomingCard()),
        ],
      ),
    );
  }
}

class _TodayQuestionCard extends ConsumerWidget {
  const _TodayQuestionCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qid = ref.watch(dailyQuestionIdProvider).value;
    final question = qid == null ? null : ref.watch(questionProvider(qid)).value;
    final uid = ref.watch(currentUidProvider) ?? '';
    final answered = question?.answered(uid) ?? false;
    final both = question?.bothAnswered ?? false;
    final partner = ref.watch(partnerNameProvider);

    final label = !answered ? 'Cevabını Paylaş' : (both ? 'Cevapları Gör' : 'Cevabın gönderildi');

    return ClipRRect(
      borderRadius: BorderRadius.circular(AppRadii.card),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: context.isDark
                      ? const [Color(0xFF2A1F2E), Color(0xFF3A2838)]
                      : const [Color(0xFFFBF3F0), Color(0xFFF5E4E3)],
                ),
              ),
            ),
          ),
          Positioned(
            right: 0,
            top: 0,
            bottom: 0,
            width: 130,
            child: ShaderMask(
              shaderCallback: (r) =>
                  const LinearGradient(colors: [Colors.transparent, Colors.black], stops: [0, 0.6]).createShader(r),
              blendMode: BlendMode.dstIn,
              child: Opacity(
                opacity: context.isDark ? 0.35 : 0.9,
                child: Image.asset(AppAssets.fabric, fit: BoxFit.cover),
              ),
            ),
          ),
          Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: qid == null ? null : () => context.push(Routes.question(qid)),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(18, 16, 14, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.wb_sunny_outlined, size: 20, color: AppColors.mauve),
                        const SizedBox(width: 8),
                        Expanded(child: Text('Bugünün Sorusu', style: context.text.titleSmall)),
                        Icon(Icons.chevron_right_rounded, size: 20, color: context.palette.textPrimary),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      question?.text ?? '…',
                      style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w500, height: 1.3),
                    ),
                    const SizedBox(height: 8),
                    if (answered && !both)
                      Text('$partner cevapladığında cevaplar açılacak.', style: context.text.bodySmall),
                    const Spacer(),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: label,
                      icon: Icons.arrow_forward_rounded,
                      compact: true,
                      expand: false,
                      onPressed: qid == null ? null : () => context.push(Routes.question(qid)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _UpcomingCard extends ConsumerWidget {
  const _UpcomingCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(upcomingProvider).take(2).toList();
    return VisalCard(
      padding: const EdgeInsets.fromLTRB(14, 16, 10, 12),
      color: context.isDark ? AppColors.darkCard : AppColors.lightSurface,
      onTap: () => context.go(Routes.plans),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.calendar_today_outlined, size: 20, color: context.palette.textPrimary),
              const SizedBox(width: 8),
              Expanded(child: Text('Yaklaşan', style: context.text.titleSmall)),
              Icon(Icons.chevron_right_rounded, size: 20, color: context.palette.textPrimary),
            ],
          ),
          const SizedBox(height: 12),
          if (items.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Özel günlerinizi ekleyin; burada geri sayım başlasın.', style: context.text.bodySmall),
            ),
          for (final item in items) _UpcomingRow(item: item),
        ],
      ),
    );
  }
}

class _UpcomingRow extends StatelessWidget {
  const _UpcomingRow({required this.item});

  final UpcomingItem item;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SoftIcon(
          item.icon,
          size: 36,
          color: item.color == AppColors.rose && !context.isDark ? AppColors.wine : item.color,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleSmall?.copyWith(fontSize: 13),
              ),
              Text(item.date.dMMMMy, style: context.text.labelSmall?.copyWith(fontSize: 11)),
              Text(daysLeftLabel(item.daysLeft), style: context.text.labelSmall?.copyWith(fontSize: 11)),
            ],
          ),
        ),
      ],
    ),
  );
}

// ---------------------------------------------------------------------------
// Ruh hali
// ---------------------------------------------------------------------------

class _MoodCard extends ConsumerWidget {
  const _MoodCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mine = ref.watch(myMoodProvider).value;
    final partnerMood = ref.watch(partnerMoodProvider).value;
    final partnerName = ref.watch(partnerNameProvider);
    return VisalCard(
      color: context.isDark ? AppColors.darkCard : AppColors.lightSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  mine == null ? 'Bugün nasıl hissediyorsun?' : 'Bugünkü ruh halin: ${mine.emoji} ${mine.label}',
                  style: context.text.titleSmall,
                ),
              ),
              if (partnerMood != null)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: context.palette.softAccent, borderRadius: BorderRadius.circular(20)),
                  child: Text('$partnerName ${partnerMood.emoji}', style: context.text.labelMedium),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final e in kMoods)
                GestureDetector(
                  onTap: () async {
                    HapticFeedback.selectionClick();
                    try {
                      await ref.read(questionsRepositoryProvider).setMood(e);
                    } catch (err) {
                      if (context.mounted) context.showError(err);
                    }
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: mine?.emoji == e ? AppColors.rose.withValues(alpha: 0.3) : Colors.transparent,
                    ),
                    child: AnimatedScale(
                      duration: const Duration(milliseconds: 200),
                      scale: mine?.emoji == e ? 1.15 : 1,
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Bugün geçmişte
// ---------------------------------------------------------------------------

class _OnThisDay extends ConsumerWidget {
  const _OnThisDay();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final list = ref.watch(onThisDayProvider).value ?? const <Memory>[];
    if (list.isEmpty) return const SizedBox.shrink();
    final m = list.first;
    final years = DateTime.now().year - m.date.year;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: GestureDetector(
        onTap: () => context.push(Routes.memory(m.id)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: SizedBox(
            height: 170,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (m.coverUrl != null)
                  Hero(
                    tag: 'memory_${m.id}',
                    child: NetImage(m.coverUrl, thumbUrl: m.cover?.thumbUrl),
                  )
                else
                  const DecoratedBox(decoration: BoxDecoration(gradient: AppColors.sunsetGradient)),
                const DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Colors.transparent, Color(0xCC1A1124)],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          yearsAgoLabel(years),
                          style: context.text.labelMedium?.copyWith(color: Colors.white),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${m.emoji ?? ''} ${m.title}'.trim(),
                        style: context.text.titleLarge?.copyWith(color: Colors.white),
                      ),
                      if (list.length > 1)
                        Text(
                          '+${list.length - 1} anı daha',
                          style: context.text.bodySmall?.copyWith(color: Colors.white70),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MoreCards extends StatelessWidget {
  const _MoreCards();

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: VisalCard(
              gradient: AppColors.chatPlumTile,
              onTap: () => context.push(Routes.capsules),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.hourglass_bottom_rounded, color: AppColors.rose),
                  const SizedBox(height: 18),
                  Text('Anı Kapsülü', style: context.text.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text('Geleceğe bir not bırak.', style: context.text.bodySmall?.copyWith(color: Colors.white70)),
                ],
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: VisalCard(
              gradient: AppColors.roseTile,
              onTap: () => context.push(Routes.story),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_stories_outlined, color: Colors.white),
                  const SizedBox(height: 18),
                  Text('Bizim Hikâyemiz', style: context.text.titleMedium?.copyWith(color: Colors.white)),
                  const SizedBox(height: 4),
                  Text(
                    'İlk mesajdan bugüne.',
                    style: context.text.bodySmall?.copyWith(color: Colors.white.withValues(alpha: 0.85)),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
