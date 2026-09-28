import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/router/routes.dart';
import '../../../core/services/media_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/media_viewer.dart';
import '../data/memories_repository.dart';

class MemoryDetailScreen extends ConsumerStatefulWidget {
  const MemoryDetailScreen({super.key, required this.memoryId});

  final String memoryId;

  @override
  ConsumerState<MemoryDetailScreen> createState() => _MemoryDetailScreenState();
}

class _MemoryDetailScreenState extends ConsumerState<MemoryDetailScreen> {
  int _page = 0;

  Future<void> _delete() async {
    final ok = await context.confirm(
      title: 'Anı silinsin mi?',
      message: 'Bu anı ve içindeki tüm fotoğraf/videolar ikiniz için de kalıcı olarak silinir.',
      confirmLabel: 'Sil',
      destructive: true,
    );
    if (!ok) return;
    try {
      await ref.read(memoriesRepositoryProvider).delete(widget.memoryId);
      if (mounted) context.pop();
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(memoryProvider(widget.memoryId));
    final uid = ref.watch(currentUidProvider);
    final partnerName = ref.watch(partnerNameProvider);
    return AsyncView(
      value: async,
      data: (m) {
        if (m == null) {
          return Scaffold(
            appBar: AppBar(),
            body: const EmptyState(icon: Icons.photo_outlined, title: 'Anı bulunamadı'),
          );
        }
        final size = MediaQuery.sizeOf(context);
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: m.media.isEmpty && !context.isDark ? SystemUiOverlayStyle.dark : SystemUiOverlayStyle.light,
          child: Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  pinned: true,
                  expandedHeight: m.media.isEmpty ? 0 : size.width * 1.05,
                  foregroundColor: m.media.isEmpty ? null : Colors.white,
                  iconTheme: m.media.isEmpty ? null : const IconThemeData(color: Colors.white),
                  backgroundColor: m.media.isEmpty ? null : AppColors.midnight,
                  actions: [
                    IconButton(
                      onPressed: () => context.push(Routes.memoryEdit(m.id)),
                      icon: const Icon(Icons.edit_outlined),
                    ),
                    IconButton(onPressed: _delete, icon: const Icon(Icons.delete_outline_rounded)),
                  ],
                  flexibleSpace: m.media.isEmpty
                      ? null
                      : FlexibleSpaceBar(
                          background: Stack(
                            fit: StackFit.expand,
                            children: [
                              PageView.builder(
                                itemCount: m.media.length,
                                onPageChanged: (i) => setState(() => _page = i),
                                itemBuilder: (context, i) {
                                  final media = m.media[i];
                                  final image = GestureDetector(
                                    onTap: () => context.push(
                                      Routes.mediaViewer,
                                      extra: MediaViewerArgs(
                                        initialIndex: i,
                                        items: [
                                          for (final x in m.media)
                                            MediaViewerItem(
                                              url: x.url,
                                              thumbUrl: x.thumbUrl,
                                              isVideo: x.kind == MediaKind.video,
                                            ),
                                        ],
                                      ),
                                    ),
                                    child: Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        NetImage(
                                          media.kind == MediaKind.video ? media.thumbUrl : media.url,
                                          thumbUrl: media.thumbUrl,
                                        ),
                                        if (media.kind == MediaKind.video)
                                          const Center(
                                            child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 64),
                                          ),
                                      ],
                                    ),
                                  );
                                  return i == 0 ? Hero(tag: 'memory_${m.id}', child: image) : image;
                                },
                              ),
                              const IgnorePointer(
                                child: DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0x661A1124), Colors.transparent, Colors.transparent, Color(0x661A1124)],
                                      stops: [0, 0.25, 0.75, 1],
                                    ),
                                  ),
                                ),
                              ),
                              if (m.media.length > 1)
                                Positioned(
                                  bottom: 16,
                                  left: 0,
                                  right: 0,
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(
                                      m.media.length,
                                      (i) => AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        margin: const EdgeInsets.symmetric(horizontal: 3),
                                        width: i == _page ? 18 : 6,
                                        height: 6,
                                        decoration: BoxDecoration(
                                          color: i == _page ? AppColors.rose : Colors.white54,
                                          borderRadius: BorderRadius.circular(3),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
                  sliver: SliverList.list(
                    children: [
                      if (m.emoji != null) Text(m.emoji!, style: const TextStyle(fontSize: 36)),
                      const SizedBox(height: 8),
                      Text(m.title, style: context.text.headlineMedium),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 14,
                        runSpacing: 6,
                        children: [
                          _Info(icon: Icons.calendar_today_outlined, text: m.date.dMMMMy),
                          if (m.location?.isNotEmpty ?? false) _Info(icon: Icons.place_outlined, text: m.location!),
                          _Info(
                            icon: Icons.person_outline_rounded,
                            text: m.createdBy == uid ? 'Sen ekledin' : '$partnerName ekledi',
                          ),
                        ],
                      ),
                      if (m.isSpecial || m.isTravel) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (m.isSpecial) const Chip(label: Text('✨ Özel gün')),
                            if (m.isTravel) const Chip(label: Text('✈️ Seyahat')),
                          ],
                        ),
                      ],
                      if (m.description.isNotEmpty) ...[
                        const SizedBox(height: 20),
                        Text(m.description, style: context.text.bodyLarge?.copyWith(height: 1.7)),
                      ],
                      if (m.musicUrl?.isNotEmpty ?? false) ...[
                        const SizedBox(height: 24),
                        VisalCard(
                          gradient: AppColors.chatPlumTile,
                          onTap: () => launchUrl(Uri.parse(m.musicUrl!), mode: LaunchMode.externalApplication),
                          child: Row(
                            children: [
                              const Icon(Icons.music_note_rounded, color: AppColors.rose),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Bu anının şarkısını dinle',
                                  style: context.text.titleSmall?.copyWith(color: Colors.white),
                                ),
                              ),
                              const Icon(Icons.open_in_new_rounded, color: Colors.white70, size: 18),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Info extends StatelessWidget {
  const _Info({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: AppColors.mauve),
          const SizedBox(width: 5),
          Text(text, style: context.text.labelMedium),
        ],
      );
}
