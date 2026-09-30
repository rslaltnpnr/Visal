import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/services/media_service.dart';
import '../../../../core/utils/date_x.dart';

/// Sesli mesaj oynatıcı: oynat/durdur + dalga çubuğu ilerlemesi.
class VoicePlayer extends ConsumerStatefulWidget {
  const VoicePlayer({
    super.key,
    required this.url,
    required this.seed,
    required this.color,
    this.durationMs,
  });

  final String url;
  final String seed;
  final Color color;
  final int? durationMs;

  @override
  ConsumerState<VoicePlayer> createState() => _VoicePlayerState();
}

class _VoicePlayerState extends ConsumerState<VoicePlayer> {
  AudioPlayer? _player;
  final _subs = <StreamSubscription<dynamic>>[];
  Duration _position = Duration.zero;
  Duration? _duration;
  bool _playing = false;
  bool _loading = false;

  late final List<double> _bars = () {
    final r = math.Random(widget.seed.hashCode);
    return List.generate(28, (_) => 0.25 + r.nextDouble() * 0.75);
  }();

  @override
  void initState() {
    super.initState();
    if (widget.durationMs != null) _duration = Duration(milliseconds: widget.durationMs!);
  }

  @override
  void dispose() {
    for (final s in _subs) {
      s.cancel();
    }
    _player?.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_player == null) {
      setState(() => _loading = true);
      final p = AudioPlayer();
      _player = p;
      _subs
        ..add(p.positionStream.listen((d) {
          if (mounted) setState(() => _position = d);
        }))
        ..add(p.durationStream.listen((d) {
          if (d != null && mounted) setState(() => _duration = d);
        }))
        ..add(p.playerStateStream.listen((s) {
          if (s.processingState == ProcessingState.completed) {
            p.pause();
            p.seek(Duration.zero);
          }
          if (mounted) {
            setState(() => _playing = s.playing && s.processingState != ProcessingState.completed);
          }
        }));
      try {
        final resolved = await ref.read(mediaServiceProvider).resolveUrl(widget.url);
        widget.url.startsWith('/') ? await p.setFilePath(widget.url) : await p.setUrl(resolved);
      } catch (_) {
        await p.dispose();
        _player = null;
        if (mounted) setState(() => _loading = false);
        return;
      }
      if (mounted) setState(() => _loading = false);
    }
    final p = _player!;
    p.playing ? await p.pause() : await p.play();
  }

  @override
  Widget build(BuildContext context) {
    final total = _duration ?? Duration.zero;
    final progress = total.inMilliseconds == 0 ? 0.0 : _position.inMilliseconds / total.inMilliseconds;
    return SizedBox(
      width: 220,
      child: Row(
        children: [
          GestureDetector(
            onTap: _toggle,
            child: Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: widget.color.withValues(alpha: 0.12),
              ),
              child: _loading
                  ? Padding(
                      padding: const EdgeInsets.all(10),
                      child: CircularProgressIndicator(strokeWidth: 2, color: widget.color),
                    )
                  : Icon(_playing ? Icons.pause_rounded : Icons.play_arrow_rounded, color: widget.color),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 26,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      for (var i = 0; i < _bars.length; i++)
                        Expanded(
                          child: Center(
                            child: Container(
                              width: 2.4,
                              height: 26 * _bars[i],
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(2),
                                color: widget.color.withValues(
                                  alpha: i / _bars.length <= progress ? 0.95 : 0.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  formatDuration(_playing || _position > Duration.zero ? _position : total),
                  style: TextStyle(fontSize: 11, color: widget.color.withValues(alpha: 0.7)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
