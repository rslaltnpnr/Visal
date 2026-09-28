import 'dart:io';
import 'dart:typed_data';

import 'package:fc_native_video_thumbnail/fc_native_video_thumbnail.dart';
import 'package:file_picker/file_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:video_player/video_player.dart';

import '../utils/failure.dart';
import 'firebase_providers.dart';

enum MediaKind { image, video, audio, file }

/// Cihazdan seçilmiş, henüz yüklenmemiş medya.
class PickedMedia {
  const PickedMedia({
    required this.path,
    required this.kind,
    required this.name,
    this.mime,
    this.duration,
  });

  final String path;
  final MediaKind kind;
  final String name;
  final String? mime;
  final Duration? duration;
}

/// Storage'a yüklenmiş medya. Firestore belgelerinde bu harita saklanır.
class UploadedMedia {
  const UploadedMedia({
    required this.url,
    required this.path,
    required this.kind,
    this.thumbUrl,
    this.width,
    this.height,
    this.durationMs,
    this.size,
    this.name,
    this.mime,
  });

  final String url;
  final String path;
  final MediaKind kind;
  final String? thumbUrl;
  final int? width;
  final int? height;
  final int? durationMs;
  final int? size;
  final String? name;
  final String? mime;

  double? get aspectRatio =>
      (width != null && height != null && height! > 0) ? width! / height! : null;

  Map<String, dynamic> toMap() => {
        'url': url,
        'path': path,
        'type': kind.name,
        if (thumbUrl != null) 'thumbUrl': thumbUrl,
        if (width != null) 'width': width,
        if (height != null) 'height': height,
        if (durationMs != null) 'durationMs': durationMs,
        if (size != null) 'size': size,
        if (name != null) 'name': name,
        if (mime != null) 'mime': mime,
      };

  factory UploadedMedia.fromMap(Map<String, dynamic> m) => UploadedMedia(
        url: m['url'] as String? ?? '',
        path: m['path'] as String? ?? '',
        kind: MediaKind.values.firstWhere(
          (k) => k.name == m['type'],
          orElse: () => MediaKind.file,
        ),
        thumbUrl: m['thumbUrl'] as String?,
        width: (m['width'] as num?)?.toInt(),
        height: (m['height'] as num?)?.toInt(),
        durationMs: (m['durationMs'] as num?)?.toInt(),
        size: (m['size'] as num?)?.toInt(),
        name: m['name'] as String?,
        mime: m['mime'] as String?,
      );
}

final mediaServiceProvider = Provider<MediaService>(
  (ref) => MediaService(ref.watch(storageProvider)),
);

class MediaService {
  MediaService(this._storage);

  final FirebaseStorage _storage;
  final _picker = ImagePicker();
  static const _uuid = Uuid();

  static const maxImageSide = 2048;
  static const thumbSide = 480;
  static const maxVideoBytes = 100 * 1024 * 1024;
  static const maxFileBytes = 50 * 1024 * 1024;

  // ---------- Seçim ----------

  Future<PickedMedia?> pickImage({ImageSource source = ImageSource.gallery}) async {
    final x = await _picker.pickImage(source: source, requestFullMetadata: false);
    if (x == null) return null;
    return PickedMedia(path: x.path, kind: MediaKind.image, name: x.name);
  }

  Future<List<PickedMedia>> pickMultiMedia({int limit = 10}) async {
    final list = await _picker.pickMultipleMedia(limit: limit, requestFullMetadata: false);
    return list
        .map((x) => PickedMedia(
              path: x.path,
              kind: _isVideo(x.path) ? MediaKind.video : MediaKind.image,
              name: x.name,
            ))
        .toList();
  }

  Future<PickedMedia?> pickVideo({ImageSource source = ImageSource.gallery}) async {
    final x = await _picker.pickVideo(
      source: source,
      maxDuration: const Duration(minutes: 5),
    );
    if (x == null) return null;
    return PickedMedia(path: x.path, kind: MediaKind.video, name: x.name);
  }

  /// Android'de Storage Access Framework, iOS'ta UIDocumentPicker kullanır;
  /// ek depolama izni gerektirmez.
  Future<PickedMedia?> pickFile() async {
    final f = await FilePicker.pickFile();
    final path = f?.path;
    if (f == null || path == null) return null;
    final size = await File(path).length();
    if (size > maxFileBytes) {
      throw const AppFailure('Dosya 50 MB\'dan büyük olamaz.');
    }
    return PickedMedia(path: path, kind: MediaKind.file, name: f.name);
  }

  static bool _isVideo(String path) {
    final ext = p.extension(path).toLowerCase();
    return const ['.mp4', '.mov', '.m4v', '.3gp', '.webm', '.mkv'].contains(ext);
  }

  // ---------- İşleme + yükleme ----------

  /// [folder] örn. `couples/{coupleId}/chat/{messageId}`
  Future<UploadedMedia> upload(
    PickedMedia media, {
    required String folder,
    void Function(double progress)? onProgress,
  }) async {
    try {
      return switch (media.kind) {
        MediaKind.image => await _uploadImage(media, folder, onProgress),
        MediaKind.video => await _uploadVideo(media, folder, onProgress),
        MediaKind.audio => await _uploadRaw(
            media,
            folder,
            onProgress,
            mime: 'audio/mp4',
          ),
        MediaKind.file => await _uploadRaw(media, folder, onProgress),
      };
    } catch (e) {
      throw AppFailure.from(e);
    }
  }

  Future<UploadedMedia> _uploadImage(
    PickedMedia media,
    String folder,
    void Function(double)? onProgress,
  ) async {
    final id = _uuid.v4();
    final full = await FlutterImageCompress.compressWithFile(
      media.path,
      minWidth: maxImageSide,
      minHeight: maxImageSide,
      quality: 84,
      format: CompressFormat.jpeg,
      keepExif: false,
    );
    final thumb = await FlutterImageCompress.compressWithFile(
      media.path,
      minWidth: thumbSide,
      minHeight: thumbSide,
      quality: 72,
      format: CompressFormat.jpeg,
    );
    final bytes = full ?? await File(media.path).readAsBytes();
    final dims = await _dimensions(bytes);

    final path = '$folder/$id.jpg';
    final url = await _putData(bytes, path, 'image/jpeg', (v) => onProgress?.call(v * 0.9));
    String? thumbUrl;
    if (thumb != null) {
      thumbUrl = await _putData(thumb, '$folder/${id}_thumb.jpg', 'image/jpeg', null);
    }
    onProgress?.call(1);
    return UploadedMedia(
      url: url,
      path: path,
      kind: MediaKind.image,
      thumbUrl: thumbUrl,
      width: dims?.width.toInt(),
      height: dims?.height.toInt(),
      size: bytes.length,
      mime: 'image/jpeg',
      name: media.name,
    );
  }

  Future<UploadedMedia> _uploadVideo(
    PickedMedia media,
    String folder,
    void Function(double)? onProgress,
  ) async {
    final file = File(media.path);
    final size = await file.length();
    if (size > maxVideoBytes) {
      throw const AppFailure('Video 100 MB\'dan büyük olamaz.');
    }
    final id = _uuid.v4();
    final ext = p.extension(media.path).toLowerCase();
    final mime = ext == '.mov' ? 'video/quicktime' : 'video/mp4';

    Uint8List? thumb;
    Size? dims;
    Duration? duration;
    try {
      thumb = await FcNativeVideoThumbnail().saveThumbnailToBytes(
        srcFile: media.path,
        width: thumbSide,
        height: thumbSide,
        format: 'jpeg',
        quality: 72,
      );
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      dims = controller.value.size;
      duration = controller.value.duration;
      await controller.dispose();
    } catch (_) {
      // Küçük resim üretilemese de yükleme devam eder.
    }

    final path = '$folder/$id${ext.isEmpty ? '.mp4' : ext}';
    final url = await _putFile(file, path, mime, (v) => onProgress?.call(v * 0.95));
    String? thumbUrl;
    if (thumb != null) {
      thumbUrl = await _putData(thumb, '$folder/${id}_thumb.jpg', 'image/jpeg', null);
    }
    onProgress?.call(1);
    return UploadedMedia(
      url: url,
      path: path,
      kind: MediaKind.video,
      thumbUrl: thumbUrl,
      width: dims?.width.toInt(),
      height: dims?.height.toInt(),
      durationMs: duration?.inMilliseconds,
      size: size,
      mime: mime,
      name: media.name,
    );
  }

  Future<UploadedMedia> _uploadRaw(
    PickedMedia media,
    String folder,
    void Function(double)? onProgress, {
    String? mime,
  }) async {
    final file = File(media.path);
    final size = await file.length();
    final ext = p.extension(media.name).toLowerCase();
    final safeName = '${_uuid.v4()}$ext';
    final contentType = mime ?? media.mime ?? _mimeFor(ext);
    final path = '$folder/$safeName';
    final url = await _putFile(file, path, contentType, onProgress);
    return UploadedMedia(
      url: url,
      path: path,
      kind: media.kind,
      size: size,
      name: media.name,
      mime: contentType,
      durationMs: media.duration?.inMilliseconds,
    );
  }

  Future<String> _putData(
    Uint8List data,
    String path,
    String contentType,
    void Function(double)? onProgress,
  ) async {
    final ref = _storage.ref(path);
    final task = ref.putData(data, _meta(contentType));
    _track(task, onProgress);
    await task;
    return ref.getDownloadURL();
  }

  Future<String> _putFile(
    File file,
    String path,
    String contentType,
    void Function(double)? onProgress,
  ) async {
    final ref = _storage.ref(path);
    final task = ref.putFile(file, _meta(contentType));
    _track(task, onProgress);
    await task;
    return ref.getDownloadURL();
  }

  /// Yalnızca yol saklanan içerikler (kapsüller) için: indirme URL'si
  /// istenmez, erişim anında kurallara göre alınır.
  Future<String> uploadPrivate(
    PickedMedia media, {
    required String folder,
    void Function(double)? onProgress,
  }) async {
    final ext = p.extension(media.path).toLowerCase();
    final path = '$folder/${_uuid.v4()}$ext';
    Uint8List? data;
    if (media.kind == MediaKind.image) {
      data = await FlutterImageCompress.compressWithFile(
        media.path,
        minWidth: maxImageSide,
        minHeight: maxImageSide,
        quality: 84,
      );
    }
    final ref = _storage.ref(data != null ? '${p.withoutExtension(path)}.jpg' : path);
    final UploadTask task = data != null
        ? ref.putData(data, _meta('image/jpeg'))
        : ref.putFile(File(media.path), _meta(_mimeFor(ext, media.kind)));
    _track(task, onProgress);
    await task;
    return ref.fullPath;
  }

  Future<String> downloadUrl(String path) => _storage.ref(path).getDownloadURL();

  Future<void> deletePaths(Iterable<String> paths) async {
    for (final path in paths) {
      try {
        await _storage.ref(path).delete();
      } catch (_) {}
    }
  }

  void _track(UploadTask task, void Function(double)? onProgress) {
    if (onProgress == null) return;
    task.snapshotEvents.listen((s) {
      if (s.totalBytes > 0) onProgress(s.bytesTransferred / s.totalBytes);
    }, onError: (_) {});
  }

  SettableMetadata _meta(String contentType) => SettableMetadata(
        contentType: contentType,
        cacheControl: 'private, max-age=31536000',
      );

  Future<Size?> _dimensions(Uint8List bytes) async {
    try {
      final image = await decodeImageFromList(bytes);
      final size = Size(image.width.toDouble(), image.height.toDouble());
      image.dispose();
      return size;
    } catch (_) {
      return null;
    }
  }

  static String _mimeFor(String ext, [MediaKind? kind]) => switch (ext) {
        '.jpg' || '.jpeg' => 'image/jpeg',
        '.png' => 'image/png',
        '.heic' => 'image/heic',
        '.gif' => 'image/gif',
        '.mp4' => 'video/mp4',
        '.mov' => 'video/quicktime',
        '.m4a' || '.aac' => 'audio/mp4',
        '.mp3' => 'audio/mpeg',
        '.pdf' => 'application/pdf',
        '.doc' => 'application/msword',
        '.docx' =>
          'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
        '.txt' => 'text/plain',
        '.zip' => 'application/zip',
        _ => kind == MediaKind.audio ? 'audio/mp4' : 'application/octet-stream',
      };

  /// Ses kaydı için geçici dosya yolu.
  static Future<String> tempAudioPath() async {
    final dir = await getTemporaryDirectory();
    return p.join(dir.path, 'visal_voice_${DateTime.now().millisecondsSinceEpoch}.m4a');
  }
}
