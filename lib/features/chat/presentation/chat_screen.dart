import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/media_service.dart';
import '../../../core/services/presence_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/common.dart';
import '../data/chat_repository.dart';
import '../domain/message.dart';
import 'chat_controller.dart';
import 'widgets/composer.dart';
import 'widgets/message_actions_sheet.dart';
import 'widgets/message_bubble.dart';
import 'widgets/quick_love_bar.dart';

class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({super.key});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scroll = ScrollController();
  final _keys = <String, GlobalKey>{};
  Message? _replyTo;
  Message? _editing;
  bool _showQuick = true;
  String? _highlight;
  final _markedSeen = <String>{};
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _onScroll() {
    // reverse liste: maxScrollExtent = en eski mesajlar
    if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 600) {
      ref.read(chatControllerProvider.notifier).loadMore();
    }
  }

  ChatRepository get _repo => ref.read(chatRepositoryProvider);

  ReplyRef? get _replyRef => _replyTo == null
      ? null
      : ReplyRef(id: _replyTo!.id, senderId: _replyTo!.senderId, preview: _replyTo!.preview, type: _replyTo!.type);

  Future<void> _guard(Future<void> Function() f) async {
    try {
      await f();
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  /// Görünür durumdayken partnerin mesajlarını okundu işaretle.
  void _markSeen(List<Message> messages) {
    if (!_visible) return;
    final uid = ref.read(currentUidProvider);
    final user = ref.read(currentUserProvider).value;
    if (uid == null || user == null) return;
    final unseen = messages
        .where((m) => m.senderId != uid && !m.seenByUser(uid) && !m.pending && !_markedSeen.contains(m.id))
        .map((m) => m.id)
        .toList();
    final latestPartner = messages.where((m) => m.senderId != uid).firstOrNull;
    final lastRead = user.chatLastReadAt;
    if (latestPartner != null && (lastRead == null || latestPartner.createdAt.isAfter(lastRead))) {
      _repo.setLastRead();
    }
    if (unseen.isEmpty || !user.settings.privacy.readReceipts) return;
    _markedSeen.addAll(unseen);
    _repo.markSeen(unseen).catchError((_) {});
  }

  Future<void> _onAction(Message m) async {
    final uid = ref.read(currentUidProvider)!;
    final result = await showMessageActions(
      context,
      message: m,
      isMine: m.isMine(uid),
      myReaction: m.reactions[uid],
    );
    if (result == null) return;
    if (result.reaction != null) return _guard(() => _repo.react(m.id, result.reaction));
    if (result.removeReaction) return _guard(() => _repo.react(m.id, null));
    switch (result.action) {
      case MessageAction.reply:
        setState(() {
          _editing = null;
          _replyTo = m;
        });
      case MessageAction.copy:
        await Clipboard.setData(ClipboardData(text: m.text ?? ''));
        if (mounted) context.showSnack('Kopyalandı');
      case MessageAction.edit:
        setState(() {
          _replyTo = null;
          _editing = m;
        });
      case MessageAction.pin:
        await _guard(() => _repo.setPinned(m.id, true));
      case MessageAction.unpin:
        await _guard(() => _repo.setPinned(m.id, false));
      case MessageAction.deleteForMe:
        await _guard(() => _repo.deleteForMe(m.id));
      case MessageAction.deleteForAll:
        if (!mounted) return;
        final ok = await context.confirm(
          title: 'Herkesten silinsin mi?',
          message: 'Bu mesaj ikiniz için de kaldırılacak.',
          confirmLabel: 'Sil',
          destructive: true,
        );
        if (ok) await _guard(() => _repo.deleteForEveryone(m.id));
      case null:
        break;
    }
  }

  Future<void> _scrollTo(String id) async {
    for (var i = 0; i < 20; i++) {
      if (!mounted) return;
      final ctx = _keys[id]?.currentContext;
      if (ctx != null && ctx.mounted) {
        await Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 350), alignment: 0.4);
        if (!mounted) return;
        setState(() => _highlight = id);
        Future<void>.delayed(const Duration(milliseconds: 1400), () {
          if (mounted) setState(() => _highlight = null);
        });
        return;
      }
      if (!_scroll.hasClients || _scroll.position.pixels >= _scroll.position.maxScrollExtent) {
        await ref.read(chatControllerProvider.notifier).loadMore();
      }
      if (!_scroll.hasClients) return;
      await _scroll.animateTo(
        (_scroll.position.pixels + 600).clamp(0, _scroll.position.maxScrollExtent),
        duration: const Duration(milliseconds: 120),
        curve: Curves.linear,
      );
      await Future<void>.delayed(const Duration(milliseconds: 30));
    }
    if (mounted) context.showSnack('Mesaj bulunamadı');
  }

  @override
  Widget build(BuildContext context) {
    _visible = TickerMode.valuesOf(context).enabled;
    if (ref.watch(coupleIdProvider) == null) {
      return const Scaffold(body: LoadingView());
    }
    final state = ref.watch(chatControllerProvider);
    final outbox = ref.watch(chatOutboxProvider);
    final uid = ref.watch(currentUidProvider) ?? '';
    final partnerId = ref.watch(partnerIdProvider) ?? '';
    final partnerName = ref.watch(partnerNameProvider);
    final myPrivacy = ref.watch(currentUserProvider).value?.settings.privacy;
    final pinned = ref.watch(pinnedMessageProvider).value;

    WidgetsBinding.instance.addPostFrameCallback((_) => _markSeen(state.messages));

    final messages = state.messages;
    final itemCount = outbox.length + messages.length + (state.hasMore ? 1 : 0);

    return Scaffold(
      backgroundColor: context.palette.chatBackground,
      appBar: _ChatAppBar(partnerName: partnerName),
      body: Column(
        children: [
          if (pinned != null)
            _PinnedBanner(
              message: pinned,
              onTap: () => _scrollTo(pinned.id),
              onUnpin: () => _guard(() => _repo.setPinned(pinned.id, false)),
            ),
          Expanded(
            child: !state.initialized
                ? const LoadingView()
                : messages.isEmpty && outbox.isEmpty
                    ? EmptyState(
                        icon: Icons.chat_bubble_outline_rounded,
                        emoji: '💌',
                        title: 'İlk mesajı sen yaz',
                        message: 'Burası yalnızca ikinize ait. Sıcak bir “merhaba” ile başlayın.',
                      )
                    : ListView.builder(
                        controller: _scroll,
                        reverse: true,
                        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
                        padding: const EdgeInsets.only(top: 12, bottom: 8),
                        itemCount: itemCount,
                        itemBuilder: (context, index) {
                          if (index < outbox.length) {
                            return _UploadTile(item: outbox[outbox.length - 1 - index]);
                          }
                          final i = index - outbox.length;
                          if (i >= messages.length) {
                            return const Padding(
                              padding: EdgeInsets.all(16),
                              child: Center(
                                child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                              ),
                            );
                          }
                          final m = messages[i];
                          final older = i + 1 < messages.length ? messages[i + 1] : null;
                          final newer = i > 0 ? messages[i - 1] : null;
                          final showDay = older == null || !older.createdAt.isSameDay(m.createdAt);
                          final grouped = newer != null &&
                              newer.senderId == m.senderId &&
                              newer.createdAt.difference(m.createdAt).inMinutes < 3 &&
                              newer.createdAt.isSameDay(m.createdAt);
                          final key = _keys.putIfAbsent(m.id, GlobalKey.new);
                          return Column(
                            key: key,
                            children: [
                              if (showDay) _DayChip(date: m.createdAt),
                              MessageBubble(
                                message: m,
                                isMine: m.isMine(uid),
                                partnerSeen: m.seenByUser(partnerId),
                                showReadReceipts: myPrivacy?.readReceipts ?? true,
                                partnerName: partnerName,
                                myUid: uid,
                                groupedWithNext: grouped,
                                highlighted: _highlight == m.id,
                                onLongPress: () => _onAction(m),
                                onReply: () => setState(() {
                                  _editing = null;
                                  _replyTo = m;
                                }),
                                onTapReply: _scrollTo,
                              ),
                            ],
                          );
                        },
                      ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 220),
            child: _showQuick && _editing == null
                ? Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: QuickLoveBar(
                      onSend: (k) => _guard(() => _repo.sendLove(k)),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          Composer(
            replyTo: _replyTo,
            editing: _editing,
            replyAuthor: _replyTo == null ? '' : (_replyTo!.senderId == uid ? 'Kendine' : partnerName),
            callbacks: ComposerCallbacks(
              onSendText: (text) {
                final reply = _replyRef;
                setState(() => _replyTo = null);
                _guard(() => _repo.sendText(text, replyTo: reply));
                _scrollToBottom();
              },
              onSendMedia: (media, type) {
                final reply = _replyRef;
                setState(() => _replyTo = null);
                ref.read(chatOutboxProvider.notifier).send(media, type, replyTo: reply);
                _scrollToBottom();
              },
              onSendGif: (gif) {
                final reply = _replyRef;
                setState(() => _replyTo = null);
                _guard(() => _repo.sendGif(gif.url, width: gif.width, height: gif.height, replyTo: reply));
              },
              onEdit: (m, text) {
                setState(() => _editing = null);
                _guard(() => _repo.edit(m.id, text));
              },
              onCancelReply: () => setState(() => _replyTo = null),
              onCancelEdit: () => setState(() => _editing = null),
            ),
          ),
        ],
      ),
      endDrawer: _QuickToggle(
        value: _showQuick,
        onChanged: (v) => setState(() => _showQuick = v),
      ),
    );
  }

  void _scrollToBottom() {
    if (_scroll.hasClients) {
      _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
  }
}

/// Hızlı mesaj çubuğu ayarı (sağdan kaydırılan panel).
class _QuickToggle extends StatelessWidget {
  const _QuickToggle({required this.value, required this.onChanged});

  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Drawer(
        child: SafeArea(
          child: SwitchListTile(
            value: value,
            onChanged: onChanged,
            title: const Text('Hızlı mesajlar'),
            subtitle: const Text('Sohbetin altında sevgi kısayollarını göster'),
          ),
        ),
      );
}

class _ChatAppBar extends ConsumerWidget implements PreferredSizeWidget {
  const _ChatAppBar({required this.partnerName});

  final String partnerName;

  @override
  Size get preferredSize => const Size.fromHeight(68);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final partner = ref.watch(partnerProfileProvider);
    final presence = ref.watch(partnerPresenceProvider).value ?? const PresenceState();
    final status = presence.typing
        ? 'yazıyor…'
        : presence.online
            ? 'çevrimiçi'
            : lastSeenLabel(presence.lastSeen);
    return AppBar(
      toolbarHeight: 68,
      backgroundColor: context.palette.chatBackground,
      titleSpacing: 20,
      title: Row(
        children: [
          Stack(
            children: [
              AppAvatar(url: partner?.photoUrl, name: partner?.name ?? partnerName, size: 42),
              if (presence.online)
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.palette.chatBackground, width: 2),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(partner?.name ?? partnerName, style: context.text.titleMedium),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Text(
                    status,
                    key: ValueKey(status),
                    style: context.text.bodySmall?.copyWith(
                      color: presence.typing ? AppColors.mauve : context.palette.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        Builder(
          builder: (ctx) => IconButton(
            tooltip: 'Sohbet ayarları',
            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
            icon: const Icon(Icons.tune_rounded),
          ),
        ),
        const SizedBox(width: 8),
      ],
      bottom: PreferredSize(
        preferredSize: const Size.fromHeight(1),
        child: Divider(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
            decoration: BoxDecoration(
              color: context.palette.card,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(date.chatDayLabel, style: context.text.labelSmall),
          ),
        ),
      );
}

class _PinnedBanner extends StatelessWidget {
  const _PinnedBanner({required this.message, required this.onTap, required this.onUnpin});

  final Message message;
  final VoidCallback onTap;
  final VoidCallback onUnpin;

  @override
  Widget build(BuildContext context) => Material(
        color: context.palette.card,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 8, 8),
            child: Row(
              children: [
                const Icon(Icons.push_pin_rounded, size: 18, color: AppColors.mauve),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Sabitlenmiş mesaj', style: context.text.labelSmall?.copyWith(color: AppColors.mauve)),
                      Text(message.preview, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodyMedium),
                    ],
                  ),
                ),
                IconButton(onPressed: onUnpin, icon: const Icon(Icons.close_rounded, size: 18)),
              ],
            ),
          ),
        ),
      );
}

class _UploadTile extends ConsumerWidget {
  const _UploadTile({required this.item});

  final OutgoingUpload item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final label = switch (item.media.kind) {
      MediaKind.image => 'Fotoğraf',
      MediaKind.video => 'Video',
      MediaKind.audio => 'Sesli mesaj',
      MediaKind.file => item.media.name,
    };
    return Align(
      alignment: Alignment.centerRight,
      child: Container(
        margin: const EdgeInsets.fromLTRB(60, 4, 12, 6),
        padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
        decoration: BoxDecoration(
          gradient: context.palette.bubbleMine,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (item.error == null)
              SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(
                  value: item.progress > 0 ? item.progress : null,
                  strokeWidth: 2.4,
                  color: AppColors.plum,
                ),
              )
            else
              const Icon(Icons.error_outline_rounded, color: AppColors.error),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                item.error ?? '$label gönderiliyor… %${(item.progress * 100).round()}',
                style: context.text.bodySmall?.copyWith(color: context.palette.bubbleMineText),
              ),
            ),
            if (item.error != null) ...[
              IconButton(
                onPressed: () => ref.read(chatOutboxProvider.notifier).retry(item),
                icon: const Icon(Icons.refresh_rounded, size: 20),
              ),
              IconButton(
                onPressed: () => ref.read(chatOutboxProvider.notifier).dismiss(item),
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
