import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/router/routes.dart';
import '../../../../core/services/media_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/common.dart';
import '../../../../core/widgets/media_viewer.dart';
import '../../domain/message.dart';
import 'voice_player.dart';

/// Minimal, premium mesaj balonu.
class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.isMine,
    required this.partnerSeen,
    required this.showReadReceipts,
    required this.partnerName,
    required this.myUid,
    required this.onLongPress,
    required this.onReply,
    required this.onTapReply,
    this.groupedWithNext = false,
    this.highlighted = false,
  });

  final Message message;
  final bool isMine;
  final bool partnerSeen;
  final bool showReadReceipts;
  final String partnerName;
  final String myUid;
  final VoidCallback onLongPress;
  final VoidCallback onReply;
  final ValueChanged<String> onTapReply;
  final bool groupedWithNext;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final m = message;
    final fg = isMine ? palette.bubbleMineText : palette.bubbleTheirsText;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.76;
    final isMedia = !m.deletedForAll &&
        (m.type == MessageType.image || m.type == MessageType.video || m.type == MessageType.gif);
    final isLove = m.type == MessageType.love && !m.deletedForAll;

    const r = Radius.circular(22);
    const tail = Radius.circular(6);
    final radius = BorderRadius.only(
      topLeft: r,
      topRight: r,
      bottomLeft: isMine || groupedWithNext ? r : tail,
      bottomRight: !isMine || groupedWithNext ? r : tail,
    );

    Widget content;
    if (m.deletedForAll) {
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.block_rounded, size: 15, color: fg.withValues(alpha: 0.5)),
          const SizedBox(width: 6),
          Text(
            'Bu mesaj silindi',
            style: TextStyle(color: fg.withValues(alpha: 0.6), fontStyle: FontStyle.italic, fontSize: 14),
          ),
        ],
      );
    } else {
      content = switch (m.type) {
        MessageType.text => _TextBody(text: m.text ?? '', color: fg),
        MessageType.love => Text(
            m.text ?? '',
            style: context.text.titleMedium?.copyWith(color: fg, fontWeight: FontWeight.w500),
          ),
        MessageType.image || MessageType.gif || MessageType.video => _MediaBody(message: m, radius: radius),
        MessageType.voice => VoicePlayer(
            url: m.mediaUrl ?? '',
            seed: m.id,
            color: fg,
            durationMs: m.media?.durationMs,
          ),
        MessageType.file => _FileBody(message: m, color: fg),
      };
    }

    final meta = _Meta(
      message: m,
      isMine: isMine,
      seen: partnerSeen && showReadReceipts,
      color: isMedia && (m.text?.isEmpty ?? true) ? Colors.white : fg.withValues(alpha: 0.55),
    );

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        gradient: isMine
            ? (isLove ? AppColors.ctaGradient : palette.bubbleMine)
            : (isLove ? AppColors.mauveTile : null),
        color: isMine || isLove ? null : palette.bubbleTheirs,
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: palette.shadow.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: isMedia ? const EdgeInsets.all(4) : const EdgeInsets.fromLTRB(14, 10, 14, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (m.replyTo != null && !m.deletedForAll)
            _ReplyQuote(
              reply: m.replyTo!,
              isMine: isMine,
              authorLabel: m.replyTo!.senderId == myUid ? 'Sen' : partnerName,
              onTap: () => onTapReply(m.replyTo!.id),
            ),
          if (isMedia)
            Stack(
              children: [
                content,
                if (m.text?.isEmpty ?? true) Positioned(right: 10, bottom: 8, child: meta),
              ],
            )
          else
            content,
          if (isMedia && (m.text?.isNotEmpty ?? false))
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 2),
              child: _TextBody(text: m.text!, color: fg),
            ),
          if (!isMedia || (m.text?.isNotEmpty ?? false))
            Padding(
              padding: EdgeInsets.only(top: 4, right: isMedia ? 8 : 0, bottom: isMedia ? 4 : 0),
              child: Align(alignment: Alignment.bottomRight, widthFactor: 1, child: meta),
            ),
        ],
      ),
    );

    return _SwipeToReply(
      onReply: m.deletedForAll ? null : onReply,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 400),
        color: highlighted ? AppColors.rose.withValues(alpha: 0.18) : Colors.transparent,
        padding: EdgeInsets.fromLTRB(12, 1, 12, groupedWithNext ? 1 : 6),
        child: Column(
          crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onLongPress: () {
                HapticFeedback.mediumImpact();
                onLongPress();
              },
              child: bubble,
            ),
            if (m.reactions.isNotEmpty) _Reactions(reactions: m.reactions, onTap: onLongPress),
          ],
        ),
      ),
    );
  }
}

class _TextBody extends StatelessWidget {
  const _TextBody({required this.text, required this.color});

  final String text;
  final Color color;

  static final _url = RegExp(r'(https?:\/\/[^\s]+)');

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyLarge?.copyWith(color: color, height: 1.4, fontSize: 15.5);
    final runes = text.trim().runes.toList();
    final onlyEmoji = runes.isNotEmpty &&
        runes.length <= 8 &&
        runes.every((r) => r >= 0x2190 || r == 0x20) &&
        !runes.any((r) => r >= 0x3000 && r < 0x1F000 && r != 0xFE0F);
    if (onlyEmoji) return Text(text, style: const TextStyle(fontSize: 38));
    final matches = _url.allMatches(text).toList();
    if (matches.isEmpty) return Text(text, style: style);
    final spans = <InlineSpan>[];
    var last = 0;
    for (final match in matches) {
      if (match.start > last) spans.add(TextSpan(text: text.substring(last, match.start)));
      final link = match.group(0)!;
      spans.add(WidgetSpan(
        alignment: PlaceholderAlignment.baseline,
        baseline: TextBaseline.alphabetic,
        child: GestureDetector(
          onTap: () => launchUrl(Uri.parse(link), mode: LaunchMode.externalApplication),
          child: Text(link, style: style?.copyWith(decoration: TextDecoration.underline)),
        ),
      ));
      last = match.end;
    }
    if (last < text.length) spans.add(TextSpan(text: text.substring(last)));
    return Text.rich(TextSpan(children: spans), style: style);
  }
}

class _MediaBody extends StatelessWidget {
  const _MediaBody({required this.message, required this.radius});

  final Message message;
  final BorderRadius radius;

  @override
  Widget build(BuildContext context) {
    final media = message.media;
    final aspect = (media?.aspectRatio ?? 1).clamp(0.6, 1.8);
    final width = MediaQuery.sizeOf(context).width * 0.66;
    final isVideo = message.type == MessageType.video;
    final previewUrl = isVideo ? media?.thumbUrl : (message.type == MessageType.gif ? message.mediaUrl : media?.url);
    return GestureDetector(
      onTap: () => context.push(
        Routes.mediaViewer,
        extra: MediaViewerArgs(
          items: [
            MediaViewerItem(
              url: message.mediaUrl ?? '',
              thumbUrl: media?.thumbUrl,
              isVideo: isVideo,
              heroTag: 'msg_${message.id}',
            ),
          ],
        ),
      ),
      child: Hero(
        tag: 'msg_${message.id}',
        child: ClipRRect(
          borderRadius: radius.subtract(const BorderRadius.all(Radius.circular(3))),
          child: SizedBox(
            width: width,
            height: width / aspect,
            child: Stack(
              fit: StackFit.expand,
              children: [
                NetImage(previewUrl, thumbUrl: isVideo ? null : media?.thumbUrl, memCacheWidth: 900),
                if (isVideo)
                  Center(
                    child: Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white.withValues(alpha: 0.6)),
                      ),
                      child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 32),
                    ),
                  ),
                if (isVideo && media?.durationMs != null)
                  Positioned(
                    left: 10,
                    bottom: 8,
                    child: Text(
                      formatDuration(Duration(milliseconds: media!.durationMs!)),
                      style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                if (message.type == MessageType.gif)
                  Positioned(
                    left: 10,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('GIF', style: TextStyle(color: Colors.white, fontSize: 10)),
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

class _FileBody extends ConsumerWidget {
  const _FileBody({required this.message, required this.color});

  final Message message;
  final Color color;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final media = message.media;
    final size = media?.size;
    final sizeLabel = size == null
        ? ''
        : size > 1024 * 1024
            ? '${(size / 1024 / 1024).toStringAsFixed(1)} MB'
            : '${(size / 1024).ceil()} KB';
    return InkWell(
      onTap: () async {
        final raw = message.mediaUrl;
        if (raw == null || raw.isEmpty) return;
        try {
          final url = await ref.read(mediaServiceProvider).resolveUrl(raw);
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } catch (e) {
          if (context.mounted) context.showError(e);
        }
      },
      child: SizedBox(
        width: 230,
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.insert_drive_file_outlined, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    media?.name ?? 'Dosya',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                  Text(sizeLabel, style: TextStyle(color: color.withValues(alpha: 0.6), fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.download_rounded, color: color.withValues(alpha: 0.7), size: 20),
          ],
        ),
      ),
    );
  }
}

class _ReplyQuote extends StatelessWidget {
  const _ReplyQuote({
    required this.reply,
    required this.isMine,
    required this.authorLabel,
    required this.onTap,
  });

  final ReplyRef reply;
  final bool isMine;
  final String authorLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = isMine ? context.palette.bubbleMineText : context.palette.bubbleTheirsText;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
        decoration: BoxDecoration(
          color: fg.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(12),
          border: const Border(left: BorderSide(color: AppColors.mauve, width: 3)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              authorLabel,
              style: TextStyle(color: AppColors.plum.withValues(alpha: context.isDark ? 1 : 0.9), fontSize: 12, fontWeight: FontWeight.w600),
            ),
            Text(
              reply.preview,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: fg.withValues(alpha: 0.75), fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.message, required this.isMine, required this.seen, required this.color});

  final Message message;
  final bool isMine;
  final bool seen;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (message.pinned) ...[
          Icon(Icons.push_pin_rounded, size: 11, color: color),
          const SizedBox(width: 3),
        ],
        if (message.editedAt != null && !message.deletedForAll)
          Text('düzenlendi · ', style: TextStyle(fontSize: 10.5, color: color)),
        Text(message.createdAt.hm, style: TextStyle(fontSize: 11, color: color)),
        if (isMine && !message.deletedForAll) ...[
          const SizedBox(width: 4),
          Icon(
            message.pending
                ? Icons.schedule_rounded
                : seen
                    ? Icons.done_all_rounded
                    : Icons.done_rounded,
            size: 15,
            color: seen ? (context.isDark ? AppColors.midnight : AppColors.plum) : color,
          ),
        ],
      ],
    );
  }
}

class _Reactions extends StatelessWidget {
  const _Reactions({required this.reactions, required this.onTap});

  final Map<String, String> reactions;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final emojis = reactions.values.toList();
    final unique = emojis.toSet().join(' ');
    return Transform.translate(
      offset: const Offset(0, -6),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: context.isDark ? AppColors.darkElevated : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
          ),
          child: Text(
            emojis.length > 1 && emojis.toSet().length == 1 ? '$unique 2' : unique,
            style: const TextStyle(fontSize: 13),
          ),
        ),
      ),
    );
  }
}

/// Sağa kaydırarak yanıtla.
class _SwipeToReply extends StatefulWidget {
  const _SwipeToReply({required this.child, required this.onReply});

  final Widget child;
  final VoidCallback? onReply;

  @override
  State<_SwipeToReply> createState() => _SwipeToReplyState();
}

class _SwipeToReplyState extends State<_SwipeToReply> {
  double _dx = 0;
  bool _triggered = false;

  @override
  Widget build(BuildContext context) {
    if (widget.onReply == null) return widget.child;
    return GestureDetector(
      onHorizontalDragUpdate: (d) {
        setState(() => _dx = (_dx + d.delta.dx).clamp(0, 80));
        if (_dx > 60 && !_triggered) {
          _triggered = true;
          HapticFeedback.selectionClick();
        }
      },
      onHorizontalDragEnd: (_) {
        if (_triggered) widget.onReply!();
        setState(() {
          _dx = 0;
          _triggered = false;
        });
      },
      child: Stack(
        alignment: Alignment.centerLeft,
        children: [
          Opacity(
            opacity: (_dx / 60).clamp(0, 1),
            child: const Padding(
              padding: EdgeInsets.only(left: 18),
              child: Icon(Icons.reply_rounded, color: AppColors.mauve),
            ),
          ),
          AnimatedContainer(
            duration: Duration(milliseconds: _dx == 0 ? 200 : 0),
            transform: Matrix4.translationValues(_dx, 0, 0),
            child: widget.child,
          ),
        ],
      ),
    );
  }
}
