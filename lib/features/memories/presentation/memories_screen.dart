import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/services/preferences_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/common.dart';
import '../data/memories_repository.dart';
import '../domain/memory.dart';

const _pageSize = 24;

class _MemoriesQuery {
  const _MemoriesQuery(this.filter, this.limit);

  final MemoryFilter filter;
  final int limit;

  @override
  bool operator ==(Object other) => other is _MemoriesQuery && other.filter == filter && other.limit == limit;

  @override
  int get hashCode => Object.hash(filter, limit);
}

final _memoriesProvider = StreamProvider.autoDispose.family<List<Memory>, _MemoriesQuery>(
  (ref, q) => ref.watch(memoriesRepositoryProvider).watch(q.filter, q.limit),
);

class MemoriesScreen extends ConsumerStatefulWidget {
  const MemoriesScreen({super.key});

  @override
  ConsumerState<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends ConsumerState<MemoriesScreen> {
  MemoryFilter _filter = MemoryFilter.all;
  int _limit = _pageSize;
  late bool _grid = ref.read(preferencesProvider).memoriesGrid;
  List<Memory> _last = const [];

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.pixels > n.metrics.maxScrollExtent - 500 && _last.length >= _limit) {
      setState(() => _limit += _pageSize);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_memoriesProvider(_MemoriesQuery(_filter, _limit)));
    _last = async.value ?? _last;
    final memories = _last;

    return Scaffold(
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push(Routes.memoryNew),
        backgroundColor: context.isDark ? AppColors.rose : AppColors.midnight,
        foregroundColor: context.isDark ? AppColors.midnight : AppColors.ivory,
        shape: const CircleBorder(),
        child: const Icon(Icons.add_rounded),
      ),
      body: NotificationListener<ScrollNotification>(
        onNotification: _onScroll,
        child: CustomScrollView(
          slivers: [
            SliverAppBar(
              pinned: true,
              expandedHeight: 110,
              flexibleSpace: FlexibleSpaceBar(
                titlePadding: const EdgeInsetsDirectional.only(start: 20, bottom: 14),
                title: Text('Anılarımız', style: context.text.headlineSmall),
              ),
              actions: [
                IconButton(
                  tooltip: 'Hikâyemiz',
                  onPressed: () => context.push(Routes.story),
                  icon: const Icon(Icons.auto_stories_outlined),
                ),
                IconButton(
                  tooltip: _grid ? 'Zaman çizelgesi' : 'Izgara',
                  onPressed: () {
                    setState(() => _grid = !_grid);
                    ref.read(preferencesProvider).setMemoriesGrid(_grid);
                  },
                  icon: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      _grid ? Icons.view_agenda_outlined : Icons.grid_view_rounded,
                      key: ValueKey(_grid),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
            SliverToBoxAdapter(
              child: SizedBox(
                height: 52,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  itemCount: MemoryFilter.values.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final f = MemoryFilter.values[i];
                    return PillChip(
                      label: f.label,
                      selected: f == _filter,
                      onTap: () => setState(() {
                        _filter = f;
                        _limit = _pageSize;
                        _last = const [];
                      }),
                    );
                  },
                ),
              ),
            ),
            if (async.isLoading && memories.isEmpty)
              const SliverFillRemaining(child: LoadingView())
            else if (async.hasError && memories.isEmpty)
              SliverFillRemaining(child: ErrorView(error: async.error!))
            else if (memories.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: EmptyState(
                  icon: Icons.photo_library_outlined,
                  emoji: '📷',
                  title: _filter == MemoryFilter.all ? 'İlk anınızı ekleyin' : 'Bu filtrede anı yok',
                  message: 'Fotoğraflar, videolar, bir şarkı ve birkaç satır… Hepsi yalnızca ikinize ait.',
                ),
              )
            else if (_grid)
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
                sliver: SliverGrid.builder(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    mainAxisSpacing: 6,
                    crossAxisSpacing: 6,
                  ),
                  itemCount: memories.length,
                  itemBuilder: (context, i) => _GridTile(memory: memories[i]),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(0, 8, 20, 100),
                sliver: SliverList.builder(
                  itemCount: memories.length,
                  itemBuilder: (context, i) {
                    final m = memories[i];
                    final showYear = i == 0 || memories[i - 1].date.year != m.date.year;
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (showYear)
                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 12, 0, 12),
                            child: Text(
                              '${m.date.year}',
                              style: context.text.displaySmall?.copyWith(
                                color: context.palette.textPrimary.withValues(alpha: 0.9),
                                fontWeight: FontWeight.w300,
                              ),
                            ),
                          ),
                        _TimelineEntry(memory: m, last: i == memories.length - 1),
                      ],
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _GridTile extends StatelessWidget {
  const _GridTile({required this.memory});

  final Memory memory;

  @override
  Widget build(BuildContext context) => GestureDetector(
        onTap: () => context.push(Routes.memory(memory.id)),
        child: Hero(
          tag: 'memory_${memory.id}',
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                memory.coverUrl != null
                    ? NetImage(memory.cover?.thumbUrl ?? memory.coverUrl, memCacheWidth: 400)
                    : DecoratedBox(
                        decoration: const BoxDecoration(gradient: AppColors.logoGradient),
                        child: Center(
                          child: Text(memory.emoji ?? '✨', style: const TextStyle(fontSize: 30)),
                        ),
                      ),
                if (memory.hasVideo)
                  const Positioned(
                    right: 6,
                    top: 6,
                    child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 20),
                  ),
              ],
            ),
          ),
        ),
      );
}

class _TimelineEntry extends StatelessWidget {
  const _TimelineEntry({required this.memory, required this.last});

  final Memory memory;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final m = memory;
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 78,
            child: Padding(
              padding: const EdgeInsets.only(top: 18, left: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${m.date.day}', style: context.text.headlineSmall),
                  Text(
                    m.date.dMMMM.split(' ').last,
                    style: context.text.labelMedium,
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: 20,
            child: Stack(
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 0,
                  bottom: last ? null : 0,
                  height: last ? 30 : null,
                  child: Container(width: 1.5, color: AppColors.rose.withValues(alpha: 0.5)),
                ),
                Positioned(
                  top: 24,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: AppColors.logoGradient,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 18),
              child: VisalCard(
                padding: EdgeInsets.zero,
                onTap: () => context.push(Routes.memory(m.id)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (m.coverUrl != null)
                      Hero(
                        tag: 'memory_${m.id}',
                        child: ClipRRect(
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(AppRadii.card)),
                          child: AspectRatio(
                            aspectRatio: 16 / 10,
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                NetImage(m.coverUrl, thumbUrl: m.cover?.thumbUrl, memCacheWidth: 900),
                                if (m.media.length > 1)
                                  Positioned(
                                    right: 10,
                                    top: 10,
                                    child: _Badge(text: '+${m.media.length - 1}'),
                                  ),
                                if (m.hasVideo)
                                  const Center(
                                    child: Icon(Icons.play_circle_fill_rounded, color: Colors.white, size: 44),
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m.emoji ?? ''} ${m.title}'.trim(),
                            style: context.text.titleMedium,
                          ),
                          if (m.description.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              m.description,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall,
                            ),
                          ],
                          if (m.location != null || m.musicUrl != null) ...[
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 12,
                              children: [
                                if (m.location != null && m.location!.isNotEmpty)
                                  _Meta(icon: Icons.place_outlined, text: m.location!),
                                if (m.musicUrl != null && m.musicUrl!.isNotEmpty)
                                  const _Meta(icon: Icons.music_note_rounded, text: 'Şarkımız'),
                                if (m.isSpecial) const _Meta(icon: Icons.auto_awesome_outlined, text: 'Özel gün'),
                              ],
                            ),
                          ],
                        ],
                      ),
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

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.mauve),
          const SizedBox(width: 4),
          Text(text, style: context.text.labelSmall),
        ],
      );
}

class _Badge extends StatelessWidget {
  const _Badge({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
      );
}
