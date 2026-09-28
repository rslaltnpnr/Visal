import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/services/media_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/media_viewer.dart';
import '../../chat/presentation/widgets/voice_player.dart';
import '../data/capsules_repository.dart';
import '../domain/capsule.dart';

class CapsuleDetailScreen extends ConsumerStatefulWidget {
  const CapsuleDetailScreen({super.key, required this.capsuleId});

  final String capsuleId;

  @override
  ConsumerState<CapsuleDetailScreen> createState() => _CapsuleDetailScreenState();
}

class _CapsuleDetailScreenState extends ConsumerState<CapsuleDetailScreen> {
  Timer? _tick;
  Future<(CapsuleContent?, List<String>)>? _content;

  @override
  void initState() {
    super.initState();
    _tick = Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  Future<(CapsuleContent?, List<String>)> _load() async {
    final repo = ref.read(capsulesRepositoryProvider);
    final content = await repo.fetchContent(widget.capsuleId);
    final urls = <String>[];
    for (final m in content?.media ?? const <CapsuleMediaRef>[]) {
      urls.add(await repo.mediaUrl(m.path));
    }
    return (content, urls);
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(currentUidProvider);
    final partner = ref.watch(partnerNameProvider);
    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.deepGradient),
        child: SafeArea(
          child: AsyncView(
            value: ref.watch(capsuleProvider(widget.capsuleId)),
            data: (c) {
              if (c == null) {
                return const EmptyState(icon: Icons.hourglass_empty, title: 'Kapsül bulunamadı');
              }
              final canRead = c.isOpen || c.createdBy == uid;
              if (canRead) _content ??= _load();
              return Column(
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => context.pop(),
                      icon: const Icon(Icons.arrow_back_rounded, color: AppColors.ivory),
                    ),
                  ),
                  Expanded(
                    child: canRead
                        ? _Opened(capsule: c, future: _content!, fromLabel: c.createdBy == uid ? 'Senden' : '$partner\'den')
                        : _Locked(capsule: c, partner: partner),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

class _Locked extends StatelessWidget {
  const _Locked({required this.capsule, required this.partner});

  final Capsule capsule;
  final String partner;

  @override
  Widget build(BuildContext context) {
    final d = capsule.remaining;
    Widget unit(int v, String l) => Column(
          children: [
            Text('$v', style: context.text.displaySmall?.copyWith(color: AppColors.ivory)),
            Text(l, style: context.text.labelMedium?.copyWith(color: AppColors.ivory.withValues(alpha: 0.7))),
          ],
        );
    return Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.08),
              border: Border.all(color: AppColors.rose.withValues(alpha: 0.5)),
            ),
            child: const Icon(Icons.lock_rounded, color: AppColors.rose, size: 48),
          ),
          const SizedBox(height: 28),
          Text(
            capsule.title.isEmpty ? '$partner sana bir kapsül bıraktı' : capsule.title,
            textAlign: TextAlign.center,
            style: context.text.headlineSmall?.copyWith(color: AppColors.ivory),
          ),
          const SizedBox(height: 8),
          Text(
            '${capsule.openAt.dMMMMy} · ${capsule.openAt.hm}',
            style: context.text.bodyMedium?.copyWith(color: AppColors.ivory.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 36),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              unit(d.inDays, 'gün'),
              unit(d.inHours.remainder(24), 'saat'),
              unit(d.inMinutes.remainder(60), 'dakika'),
              unit(d.inSeconds.remainder(60), 'saniye'),
            ],
          ),
          const SizedBox(height: 36),
          Text(
            'Zamanı geldiğinde sana haber vereceğiz.',
            style: context.text.bodySmall?.copyWith(color: AppColors.ivory.withValues(alpha: 0.6)),
          ),
        ],
      ),
    );
  }
}

class _Opened extends StatelessWidget {
  const _Opened({required this.capsule, required this.future, required this.fromLabel});

  final Capsule capsule;
  final Future<(CapsuleContent?, List<String>)> future;
  final String fromLabel;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: future,
      builder: (context, snap) {
        if (snap.hasError) return ErrorView(error: snap.error!);
        if (!snap.hasData) return const LoadingView();
        final (content, urls) = snap.data!;
        if (content == null) return const EmptyState(icon: Icons.hourglass_empty, title: 'İçerik bulunamadı');
        final visuals = <MediaViewerItem>[
          for (var i = 0; i < content.media.length; i++)
            if (content.media[i].kind == MediaKind.image || content.media[i].kind == MediaKind.video)
              MediaViewerItem(url: urls[i], isVideo: content.media[i].kind == MediaKind.video),
        ];
        return ListView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 40),
          children: [
            Text(
              capsule.isOpen ? '$fromLabel bir kapsül' : 'Kilitli · ${capsule.openAt.dMMMMy} açılacak',
              style: context.text.labelLarge?.copyWith(color: AppColors.rose),
            ),
            const SizedBox(height: 8),
            Text(
              capsule.title.isEmpty ? 'Anı Kapsülü' : capsule.title,
              style: context.text.headlineMedium?.copyWith(color: AppColors.ivory),
            ),
            const SizedBox(height: 4),
            Text(
              '${capsule.createdAt?.dMMMMy ?? ''} tarihinde kilitlendi',
              style: context.text.bodySmall?.copyWith(color: AppColors.ivory.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 24),
            if (content.message.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.ivory,
                  borderRadius: BorderRadius.circular(AppRadii.card),
                ),
                child: Text(
                  content.message,
                  style: context.text.bodyLarge?.copyWith(color: AppColors.textPrimary, height: 1.7),
                ),
              ),
            const SizedBox(height: 16),
            for (var i = 0; i < content.media.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: switch (content.media[i].kind) {
                  MediaKind.audio => Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: VoicePlayer(url: urls[i], seed: content.media[i].path, color: AppColors.ivory),
                    ),
                  _ => GestureDetector(
                      onTap: () {
                        final idx = visuals.indexWhere((v) => v.url == urls[i]);
                        context.push(
                          Routes.mediaViewer,
                          extra: MediaViewerArgs(items: visuals, initialIndex: idx < 0 ? 0 : idx),
                        );
                      },
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadii.card),
                        child: AspectRatio(
                          aspectRatio: 4 / 3,
                          child: content.media[i].kind == MediaKind.video
                              ? const ColoredBox(
                                  color: Colors.black,
                                  child: Center(child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 60)),
                                )
                              : NetImage(urls[i]),
                        ),
                      ),
                    ),
                },
              ),
          ],
        );
      },
    );
  }
}
