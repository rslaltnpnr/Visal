import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../data/chat_repository.dart';
import '../domain/message.dart';

final _latestLoveProvider = StreamProvider<Message?>((ref) {
  if (ref.watch(coupleIdProvider) == null) return Stream.value(null);
  return ref
      .watch(chatRepositoryProvider)
      .watchLatest(5)
      .map((list) => list.where((m) => m.type == MessageType.love).firstOrNull);
});

/// Partner hızlı sevgi mesajı gönderdiğinde uygulamanın her yerinde
/// kısa, zarif bir animasyon gösterir: "❤️ Partnerin seni düşünüyor."
class LoveOverlayListener extends ConsumerStatefulWidget {
  const LoveOverlayListener({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<LoveOverlayListener> createState() => _LoveOverlayListenerState();
}

class _LoveOverlayListenerState extends ConsumerState<LoveOverlayListener> {
  final _sessionStart = DateTime.now().subtract(const Duration(seconds: 5));
  final _shown = <String>{};
  Message? _current;

  @override
  Widget build(BuildContext context) {
    ref.listen(_latestLoveProvider, (_, next) {
      final m = next.value;
      final uid = ref.read(currentUidProvider);
      if (m == null || m.senderId == uid || _shown.contains(m.id)) return;
      if (m.createdAt.isBefore(_sessionStart)) return;
      _shown.add(m.id);
      HapticFeedback.heavyImpact();
      setState(() => _current = m);
    });

    return Stack(
      children: [
        widget.child,
        if (_current != null)
          Positioned.fill(
            child: _LoveBurst(
              key: ValueKey(_current!.id),
              message: _current!,
              partnerName: ref.watch(partnerNameProvider),
              onDone: () => setState(() => _current = null),
            ),
          ),
      ],
    );
  }
}

class _LoveBurst extends StatefulWidget {
  const _LoveBurst({super.key, required this.message, required this.partnerName, required this.onDone});

  final Message message;
  final String partnerName;
  final VoidCallback onDone;

  @override
  State<_LoveBurst> createState() => _LoveBurstState();
}

class _LoveBurstState extends State<_LoveBurst> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 3200))
    ..forward().whenComplete(widget.onDone);
  final _rand = math.Random();
  late final _particles = List.generate(
    14,
    (_) => (x: _rand.nextDouble(), delay: _rand.nextDouble() * 0.35, size: 14 + _rand.nextDouble() * 16),
  );

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final kind = widget.message.loveKind ?? LoveKind.love;
    final title = kind == LoveKind.love || kind == LoveKind.kiss || kind == LoveKind.miss
        ? '${kind.emoji} ${widget.partnerName} seni düşünüyor.'
        : '${kind.emoji} ${widget.partnerName}: ${kind.label}';
    return IgnorePointer(
      ignoring: false,
      child: GestureDetector(
        onTap: widget.onDone,
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final fadeIn = Curves.easeOut.transform((t / 0.15).clamp(0, 1));
            final fadeOut = 1 - Curves.easeIn.transform(((t - 0.8) / 0.2).clamp(0, 1));
            final opacity = fadeIn * fadeOut;
            final size = MediaQuery.sizeOf(context);
            return Stack(
              children: [
                Positioned.fill(
                  child: ColoredBox(color: AppColors.midnight.withValues(alpha: 0.35 * opacity)),
                ),
                for (final p in _particles)
                  Builder(builder: (_) {
                    final pt = ((t - p.delay) / 0.75).clamp(0.0, 1.0);
                    return Positioned(
                      left: p.x * size.width,
                      top: size.height * (0.85 - 0.7 * Curves.easeOut.transform(pt)),
                      child: Opacity(
                        opacity: (math.sin(pt * math.pi)).clamp(0, 1) * fadeOut,
                        child: Text(kind.emoji, style: TextStyle(fontSize: p.size)),
                      ),
                    );
                  }),
                Center(
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.scale(
                      scale: 0.9 + 0.1 * Curves.elasticOut.transform((t / 0.4).clamp(0, 1)),
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 32),
                        padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 22),
                        decoration: BoxDecoration(
                          gradient: AppColors.ctaGradient,
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.plum.withValues(alpha: 0.4),
                              blurRadius: 40,
                              offset: const Offset(0, 16),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(kind.emoji, style: const TextStyle(fontSize: 46)),
                            const SizedBox(height: 10),
                            Text(
                              title,
                              textAlign: TextAlign.center,
                              style: context.text.titleMedium?.copyWith(color: Colors.white),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
