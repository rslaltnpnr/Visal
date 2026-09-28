import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:record/record.dart';

import '../../../core/services/media_service.dart';
import '../../../core/session/session_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/date_x.dart';
import '../../../core/widgets/buttons.dart';
import '../../../core/widgets/common.dart';
import '../../../core/widgets/pickers.dart';
import '../data/capsules_repository.dart';

class CapsuleEditorScreen extends ConsumerStatefulWidget {
  const CapsuleEditorScreen({super.key});

  @override
  ConsumerState<CapsuleEditorScreen> createState() => _CapsuleEditorScreenState();
}

class _CapsuleEditorScreenState extends ConsumerState<CapsuleEditorScreen> {
  final _title = TextEditingController();
  final _message = TextEditingController();
  DateTime _openDate = dateOnly(DateTime.now()).add(const Duration(days: 30));
  TimeOfDay _openTime = const TimeOfDay(hour: 9, minute: 0);
  final List<PickedMedia> _media = [];
  bool _saving = false;
  double _progress = 0;

  final _recorder = AudioRecorder();
  bool _recording = false;
  DateTime? _recordStart;

  DateTime get _openAt =>
      DateTime(_openDate.year, _openDate.month, _openDate.day, _openTime.hour, _openTime.minute);

  @override
  void dispose() {
    _title.dispose();
    _message.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _pick(String kind) async {
    final service = ref.read(mediaServiceProvider);
    try {
      final m = switch (kind) {
        'photo' => await service.pickImage(),
        _ => await service.pickVideo(),
      };
      if (m != null) setState(() => _media.add(m));
    } catch (e) {
      if (mounted) context.showError(e);
    }
  }

  Future<void> _toggleRecord() async {
    if (_recording) {
      final path = await _recorder.stop();
      final duration = DateTime.now().difference(_recordStart!);
      setState(() => _recording = false);
      if (path != null) {
        setState(() => _media.add(PickedMedia(
              path: path,
              kind: MediaKind.audio,
              name: 'ses-kaydi.m4a',
              mime: 'audio/mp4',
              duration: duration,
            )));
      }
      return;
    }
    if (!await _recorder.hasPermission()) {
      if (mounted) context.showSnack('Ses kaydı için mikrofon izni gerekli.');
      return;
    }
    await _recorder.start(const RecordConfig(encoder: AudioEncoder.aacLc), path: await MediaService.tempAudioPath());
    setState(() {
      _recording = true;
      _recordStart = DateTime.now();
    });
  }

  Future<void> _lock() async {
    final partnerId = ref.read(partnerIdProvider);
    if (partnerId == null) return;
    if (_message.text.trim().isEmpty && _media.isEmpty) {
      context.showSnack('Kapsüle bir mesaj ya da medya ekleyin.');
      return;
    }
    if (!_openAt.isAfter(DateTime.now().add(const Duration(minutes: 5)))) {
      context.showSnack('Açılma zamanı gelecekte olmalı.');
      return;
    }
    final ok = await context.confirm(
      title: 'Kapsül kilitlensin mi?',
      message: 'Kilitlendikten sonra içerik değiştirilemez ve ${_openAt.dMMMMy} ${_openAt.hm} tarihinden önce açılamaz.',
      confirmLabel: 'Kilitle',
    );
    if (!ok) return;
    setState(() {
      _saving = true;
      _progress = 0;
    });
    try {
      await ref.read(capsulesRepositoryProvider).lock(
            recipientId: partnerId,
            openAt: _openAt,
            title: _title.text,
            message: _message.text,
            media: _media,
            onProgress: (p) => setState(() => _progress = p),
          );
      if (mounted) {
        context.showSnack('Kapsül kilitlendi 🔒');
        context.pop();
      }
    } catch (e) {
      if (mounted) context.showError(e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final partner = ref.watch(partnerProfileProvider);
    final partnerName = ref.watch(partnerNameProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Yeni Kapsül')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          VisalCard(
            child: Row(
              children: [
                Text('Kime', style: context.text.labelMedium),
                const SizedBox(width: 16),
                AppAvatar(url: partner?.photoUrl, name: partner?.name ?? partnerName, size: 32),
                const SizedBox(width: 10),
                Text(partner?.name ?? partnerName, style: context.text.titleSmall),
              ],
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PickerField(
                  label: 'Açılma tarihi',
                  value: _openDate.dMMMMy,
                  onTap: () async {
                    final d = await pickDate(
                      context,
                      initial: _openDate,
                      first: dateOnly(DateTime.now()),
                      last: DateTime.now().add(const Duration(days: 365 * 30)),
                    );
                    if (d != null) setState(() => _openDate = d);
                  },
                ),
              ),
              const SizedBox(width: 10),
              SizedBox(
                width: 120,
                child: PickerField(
                  label: 'Saat',
                  icon: Icons.schedule_rounded,
                  value: _openTime.format(context),
                  onTap: () async {
                    final t = await pickTime(context, initial: _openTime);
                    if (t != null) setState(() => _openTime = t);
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _title,
            maxLength: 60,
            decoration: const InputDecoration(
              labelText: 'Başlık (kilitliyken görünür)',
              hintText: 'Yıldönümümüz için',
              counterText: '',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            minLines: 5,
            maxLines: 14,
            maxLength: 5000,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Mesaj', alignLabelWithHint: true),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick('photo'),
                  icon: const Icon(Icons.photo_outlined, size: 18),
                  label: const Text('Fotoğraf'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pick('video'),
                  icon: const Icon(Icons.videocam_outlined, size: 18),
                  label: const Text('Video'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _toggleRecord,
                  style: _recording ? OutlinedButton.styleFrom(foregroundColor: AppColors.error) : null,
                  icon: Icon(_recording ? Icons.stop_rounded : Icons.mic_none_rounded, size: 18),
                  label: Text(_recording ? 'Durdur' : 'Ses'),
                ),
              ),
            ],
          ),
          if (_media.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final m in _media)
                  Stack(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: SizedBox(
                          width: 84,
                          height: 84,
                          child: m.kind == MediaKind.image
                              ? Image.file(File(m.path), fit: BoxFit.cover, cacheWidth: 250)
                              : ColoredBox(
                                  color: AppColors.deepPlum,
                                  child: Icon(
                                    m.kind == MediaKind.video ? Icons.videocam_rounded : Icons.graphic_eq_rounded,
                                    color: AppColors.rose,
                                  ),
                                ),
                        ),
                      ),
                      Positioned(
                        right: 2,
                        top: 2,
                        child: GestureDetector(
                          onTap: () => setState(() => _media.remove(m)),
                          child: const CircleAvatar(
                            radius: 11,
                            backgroundColor: Colors.black54,
                            child: Icon(Icons.close_rounded, size: 14, color: Colors.white),
                          ),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
          const SizedBox(height: 24),
          if (_saving && _media.isNotEmpty) ...[
            LinearProgressIndicator(value: _progress, minHeight: 4, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 12),
          ],
          GradientButton(label: 'Kapsülü Kilitle', icon: Icons.lock_rounded, onPressed: _lock, loading: _saving),
        ],
      ),
    );
  }
}
