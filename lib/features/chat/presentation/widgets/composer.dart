import 'dart:async';

import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import 'package:flutter/foundation.dart' as foundation;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';

import '../../../../core/services/media_service.dart';
import '../../../../core/services/presence_service.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../core/utils/date_x.dart';
import '../../../../core/widgets/common.dart';
import '../../data/gif_repository.dart';
import '../../domain/message.dart';
import 'gif_picker_sheet.dart';

class ComposerCallbacks {
  const ComposerCallbacks({
    required this.onSendText,
    required this.onSendMedia,
    required this.onSendGif,
    required this.onEdit,
    required this.onCancelReply,
    required this.onCancelEdit,
  });

  final void Function(String text) onSendText;
  final void Function(PickedMedia media, MessageType type) onSendMedia;
  final void Function(GifItem gif) onSendGif;
  final void Function(Message message, String text) onEdit;
  final VoidCallback onCancelReply;
  final VoidCallback onCancelEdit;
}

class Composer extends ConsumerStatefulWidget {
  const Composer({
    super.key,
    required this.callbacks,
    this.replyTo,
    this.editing,
    this.replyAuthor = '',
  });

  final ComposerCallbacks callbacks;
  final Message? replyTo;
  final Message? editing;
  final String replyAuthor;

  @override
  ConsumerState<Composer> createState() => _ComposerState();
}

class _ComposerState extends ConsumerState<Composer> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  bool _emoji = false;

  // Ses kaydı
  // Kayıt başlarken oluşturulur (gereksiz yere mikrofon kanalı açılmaz).
  AudioRecorder? _recorderInstance;
  AudioRecorder get _recorder => _recorderInstance ??= AudioRecorder();
  bool _recording = false;
  DateTime? _recordStart;
  Timer? _recordTimer;
  Duration _recordElapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onChanged);
    _focus.addListener(() {
      if (_focus.hasFocus && _emoji) setState(() => _emoji = false);
    });
  }

  @override
  void didUpdateWidget(covariant Composer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.editing != null && widget.editing?.id != oldWidget.editing?.id) {
      _controller.text = widget.editing!.text ?? '';
      _focus.requestFocus();
    }
    if (widget.replyTo != null && widget.replyTo?.id != oldWidget.replyTo?.id) {
      _focus.requestFocus();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _recordTimer?.cancel();
    _recorderInstance?.dispose();
    super.dispose();
  }

  void _onChanged() {
    setState(() {});
    ref.read(presenceServiceProvider).setTyping(_controller.text.isNotEmpty);
  }

  void _send() {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    HapticFeedback.lightImpact();
    if (widget.editing != null) {
      widget.callbacks.onEdit(widget.editing!, text);
    } else {
      widget.callbacks.onSendText(text);
    }
    _controller.clear();
    ref.read(presenceServiceProvider).setTyping(false);
  }

  // ---------- Ekler ----------

  Future<void> _attach() async {
    FocusScope.of(context).unfocus();
    final gifAvailable = ref.read(gifRepositoryProvider).isAvailable;
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Wrap(
            alignment: WrapAlignment.spaceEvenly,
            runSpacing: 18,
            children: [
              _AttachOption(icon: Icons.photo_library_outlined, label: 'Galeri', value: 'gallery', gradient: AppColors.roseTile),
              _AttachOption(icon: Icons.photo_camera_outlined, label: 'Fotoğraf', value: 'camera', gradient: AppColors.mauveTile),
              _AttachOption(icon: Icons.videocam_outlined, label: 'Video', value: 'video', gradient: AppColors.chatPlumTile),
              _AttachOption(icon: Icons.insert_drive_file_outlined, label: 'Dosya', value: 'file', gradient: AppColors.ivoryTile, dark: true),
              if (gifAvailable)
                _AttachOption(icon: Icons.gif_box_outlined, label: 'GIF', value: 'gif', gradient: AppColors.roseTile),
            ],
          ),
        ),
      ),
    );
    if (choice == null || !mounted) return;
    final service = ref.read(mediaServiceProvider);
    try {
      switch (choice) {
        case 'gallery':
          final list = await service.pickMultiMedia();
          for (final m in list) {
            widget.callbacks.onSendMedia(m, m.kind == MediaKind.video ? MessageType.video : MessageType.image);
          }
        case 'camera':
          final m = await service.pickImage(source: ImageSource.camera);
          if (m != null) widget.callbacks.onSendMedia(m, MessageType.image);
        case 'video':
          final m = await service.pickVideo(source: ImageSource.camera);
          if (m != null) widget.callbacks.onSendMedia(m, MessageType.video);
        case 'file':
          final m = await service.pickFile();
          if (m != null) widget.callbacks.onSendMedia(m, MessageType.file);
        case 'gif':
          if (!mounted) return;
          final gif = await showGifPicker(context);
          if (gif != null) widget.callbacks.onSendGif(gif);
      }
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  // ---------- Ses kaydı ----------

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      if (mounted) context.showSnack('Sesli mesaj için mikrofon izni gerekli.');
      return;
    }
    final path = await MediaService.tempAudioPath();
    await _recorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc, bitRate: 64000, sampleRate: 44100, numChannels: 1),
      path: path,
    );
    HapticFeedback.mediumImpact();
    setState(() {
      _recording = true;
      _recordStart = DateTime.now();
      _recordElapsed = Duration.zero;
    });
    _recordTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      final elapsed = DateTime.now().difference(_recordStart!);
      setState(() => _recordElapsed = elapsed);
      if (elapsed.inMinutes >= 5) _stopRecording(send: true);
    });
  }

  Future<void> _stopRecording({required bool send}) async {
    _recordTimer?.cancel();
    final path = await _recorder.stop();
    final duration = _recordElapsed;
    setState(() => _recording = false);
    if (!send || path == null) return;
    if (duration < const Duration(seconds: 1)) {
      if (mounted) context.showSnack('Kayıt çok kısa');
      return;
    }
    widget.callbacks.onSendMedia(
      PickedMedia(path: path, kind: MediaKind.audio, name: 'sesli-mesaj.m4a', mime: 'audio/mp4', duration: duration),
      MessageType.voice,
    );
  }

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    final hasText = _controller.text.trim().isNotEmpty;
    final bar = Container(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      decoration: BoxDecoration(
        color: context.isDark ? AppColors.darkCard : AppColors.lightSurface,
        border: Border(top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.6))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.replyTo != null || widget.editing != null)
              _ContextPreview(
                icon: widget.editing != null ? Icons.edit_outlined : Icons.reply_rounded,
                title: widget.editing != null ? 'Mesajı düzenle' : '${widget.replyAuthor} kişisine yanıt',
                text: (widget.editing ?? widget.replyTo)!.preview,
                onClose: () {
                  if (widget.editing != null) {
                    _controller.clear();
                    widget.callbacks.onCancelEdit();
                  } else {
                    widget.callbacks.onCancelReply();
                  }
                },
              ),
            if (_recording)
              _RecordingBar(
                elapsed: _recordElapsed,
                onCancel: () => _stopRecording(send: false),
                onSend: () => _stopRecording(send: true),
              )
            else
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (widget.editing == null)
                    _RoundIcon(icon: Icons.add_rounded, onTap: _attach, color: palette.textSecondary),
                  Expanded(
                    child: Container(
                      margin: const EdgeInsets.symmetric(horizontal: 6),
                      decoration: BoxDecoration(
                        color: context.isDark ? AppColors.darkElevated : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          IconButton(
                            onPressed: () {
                              setState(() => _emoji = !_emoji);
                              if (_emoji) {
                                FocusScope.of(context).unfocus();
                              } else {
                                _focus.requestFocus();
                              }
                            },
                            icon: Icon(
                              _emoji ? Icons.keyboard_outlined : Icons.emoji_emotions_outlined,
                              color: palette.textSecondary,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _controller,
                              focusNode: _focus,
                              minLines: 1,
                              maxLines: 6,
                              maxLength: 4000,
                              textCapitalization: TextCapitalization.sentences,
                              style: context.text.bodyLarge,
                              decoration: const InputDecoration(
                                hintText: 'Mesaj yaz…',
                                counterText: '',
                                filled: false,
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: EdgeInsets.fromLTRB(0, 12, 12, 12),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 180),
                    transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
                    child: hasText || widget.editing != null
                        ? _SendButton(
                            key: const ValueKey('send'),
                            icon: widget.editing != null ? Icons.check_rounded : Icons.arrow_upward_rounded,
                            onTap: _send,
                          )
                        : _SendButton(key: const ValueKey('mic'), icon: Icons.mic_none_rounded, onTap: _startRecording),
                  ),
                ],
              ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        bar,
        if (_emoji)
          SizedBox(
            height: 280,
            child: EmojiPicker(
              textEditingController: _controller,
              config: Config(
                height: 280,
                checkPlatformCompatibility: true,
                locale: const Locale('tr'),
                emojiViewConfig: EmojiViewConfig(
                  columns: 8,
                  emojiSizeMax: 28 * (foundation.defaultTargetPlatform == TargetPlatform.iOS ? 1.2 : 1.0),
                  backgroundColor: context.isDark ? AppColors.darkCard : AppColors.lightSurface,
                ),
                categoryViewConfig: CategoryViewConfig(
                  backgroundColor: context.isDark ? AppColors.darkCard : AppColors.lightSurface,
                  indicatorColor: AppColors.mauve,
                  iconColorSelected: AppColors.mauve,
                  iconColor: palette.muted,
                  backspaceColor: AppColors.mauve,
                ),
                bottomActionBarConfig: const BottomActionBarConfig(enabled: false),
                searchViewConfig: SearchViewConfig(
                  backgroundColor: context.isDark ? AppColors.darkCard : AppColors.lightSurface,
                  hintText: 'Ara',
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({super.key, required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: Material(
          shape: const CircleBorder(),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: const BoxDecoration(gradient: AppColors.ctaGradient, shape: BoxShape.circle),
            child: InkWell(
              onTap: onTap,
              child: SizedBox(width: 46, height: 46, child: Icon(icon, color: Colors.white)),
            ),
          ),
        ),
      );
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({required this.icon, required this.onTap, required this.color});

  final IconData icon;
  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 2),
        child: IconButton(onPressed: onTap, icon: Icon(icon, color: color, size: 28)),
      );
}

class _ContextPreview extends StatelessWidget {
  const _ContextPreview({required this.icon, required this.title, required this.text, required this.onClose});

  final IconData icon;
  final String title;
  final String text;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        decoration: BoxDecoration(
          color: context.palette.softAccent,
          borderRadius: BorderRadius.circular(16),
          border: const Border(left: BorderSide(color: AppColors.mauve, width: 3)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: AppColors.mauve),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: context.text.labelMedium?.copyWith(fontWeight: FontWeight.w600)),
                  Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: context.text.bodySmall),
                ],
              ),
            ),
            IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded, size: 18)),
          ],
        ),
      );
}

class _RecordingBar extends StatefulWidget {
  const _RecordingBar({required this.elapsed, required this.onCancel, required this.onSend});

  final Duration elapsed;
  final VoidCallback onCancel;
  final VoidCallback onSend;

  @override
  State<_RecordingBar> createState() => _RecordingBarState();
}

class _RecordingBarState extends State<_RecordingBar> with SingleTickerProviderStateMixin {
  late final _blink = AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _blink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
        children: [
          IconButton(
            onPressed: widget.onCancel,
            icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
          ),
          FadeTransition(
            opacity: _blink,
            child: Container(
              width: 10,
              height: 10,
              decoration: const BoxDecoration(color: AppColors.error, shape: BoxShape.circle),
            ),
          ),
          const SizedBox(width: 10),
          Text(formatDuration(widget.elapsed), style: context.text.titleMedium),
          const SizedBox(width: 10),
          Expanded(
            child: Text('Kaydediliyor…', style: context.text.bodySmall),
          ),
          _SendButton(icon: Icons.arrow_upward_rounded, onTap: widget.onSend),
        ],
      );
}

class _AttachOption extends StatelessWidget {
  const _AttachOption({
    required this.icon,
    required this.label,
    required this.value,
    required this.gradient,
    this.dark = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final Gradient gradient;
  final bool dark;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: 76,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => Navigator.pop(context, value),
          child: Column(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(gradient: gradient, borderRadius: BorderRadius.circular(20)),
                child: Icon(icon, color: dark ? AppColors.wine : Colors.white),
              ),
              const SizedBox(height: 8),
              Text(label, style: context.text.labelMedium),
            ],
          ),
        ),
      );
}
