import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';

import 'common.dart';

class MediaViewerItem {
  const MediaViewerItem({required this.url, this.thumbUrl, this.isVideo = false, this.heroTag});

  final String url;
  final String? thumbUrl;
  final bool isVideo;
  final String? heroTag;
}

class MediaViewerArgs {
  const MediaViewerArgs({required this.items, this.initialIndex = 0});

  final List<MediaViewerItem> items;
  final int initialIndex;
}

/// Tam ekran fotoğraf/video görüntüleyici (yakınlaştırma + kaydırma).
class MediaViewerScreen extends StatefulWidget {
  const MediaViewerScreen({super.key, required this.args});

  final MediaViewerArgs args;

  @override
  State<MediaViewerScreen> createState() => _MediaViewerScreenState();
}

class _MediaViewerScreenState extends State<MediaViewerScreen> {
  late final _page = PageController(initialPage: widget.args.initialIndex);
  late int _index = widget.args.initialIndex;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = widget.args.items;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: Colors.black,
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          iconTheme: const IconThemeData(color: Colors.white),
          title: items.length > 1
              ? Text('${_index + 1} / ${items.length}', style: const TextStyle(color: Colors.white))
              : null,
        ),
        body: PageView.builder(
          controller: _page,
          itemCount: items.length,
          onPageChanged: (i) => setState(() => _index = i),
          itemBuilder: (context, i) {
            final item = items[i];
            final child = item.isVideo
                ? _VideoView(url: item.url)
                : InteractiveViewer(
                    minScale: 1,
                    maxScale: 4,
                    child: Center(
                      child: NetImage(item.url, thumbUrl: item.thumbUrl, fit: BoxFit.contain),
                    ),
                  );
            return item.heroTag != null && i == widget.args.initialIndex
                ? Hero(tag: item.heroTag!, child: child)
                : child;
          },
        ),
      ),
    );
  }
}

class _VideoView extends StatefulWidget {
  const _VideoView({required this.url});

  final String url;

  @override
  State<_VideoView> createState() => _VideoViewState();
}

class _VideoViewState extends State<_VideoView> {
  late final VideoPlayerController _c = VideoPlayerController.networkUrl(Uri.parse(widget.url))
    ..initialize().then((_) {
      if (mounted) {
        setState(() {});
        _c.play();
      }
    })
    ..addListener(() {
      if (mounted) setState(() {});
    });

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_c.value.isInitialized) return const LoadingView();
    return GestureDetector(
      onTap: () => _c.value.isPlaying ? _c.pause() : _c.play(),
      child: Stack(
        alignment: Alignment.center,
        children: [
          AspectRatio(aspectRatio: _c.value.aspectRatio, child: VideoPlayer(_c)),
          if (!_c.value.isPlaying)
            const Icon(Icons.play_circle_fill_rounded, color: Colors.white70, size: 72),
          Positioned(
            left: 16,
            right: 16,
            bottom: 36,
            child: VideoProgressIndicator(
              _c,
              allowScrubbing: true,
              colors: const VideoProgressColors(
                playedColor: Color(0xFFE7A7B1),
                bufferedColor: Colors.white24,
                backgroundColor: Colors.white12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
