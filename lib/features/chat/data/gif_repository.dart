import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;

/// Tenor API anahtarı: `--dart-define=TENOR_API_KEY=...`
/// Boşsa GIF seçici arayüzde gizlenir.
const _tenorKey = String.fromEnvironment('TENOR_API_KEY');

class GifItem {
  const GifItem({required this.previewUrl, required this.url, this.width, this.height});

  final String previewUrl;
  final String url;
  final int? width;
  final int? height;
}

/// GIF sağlayıcısı soyutlaması (Tenor, Giphy vb. değiştirilebilir).
abstract class GifRepository {
  bool get isAvailable;
  Future<List<GifItem>> trending();
  Future<List<GifItem>> search(String query);
}

final gifRepositoryProvider = Provider<GifRepository>((_) => TenorGifRepository(_tenorKey));

class TenorGifRepository implements GifRepository {
  TenorGifRepository(this._key, {http.Client? client}) : _client = client ?? http.Client();

  final String _key;
  final http.Client _client;

  @override
  bool get isAvailable => _key.isNotEmpty;

  @override
  Future<List<GifItem>> trending() => _get('featured', const {});

  @override
  Future<List<GifItem>> search(String query) => _get('search', {'q': query});

  Future<List<GifItem>> _get(String path, Map<String, String> params) async {
    if (!isAvailable) return const [];
    final uri = Uri.https('tenor.googleapis.com', '/v2/$path', {
      ...params,
      'key': _key,
      'client_key': 'visal',
      'limit': '30',
      'locale': 'tr_TR',
      'contentfilter': 'medium',
      'media_filter': 'tinygif,gif',
    });
    final res = await _client.get(uri);
    if (res.statusCode != 200) return const [];
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    final results = (body['results'] as List?) ?? const [];
    return results
        .map((r) {
          final formats = (r as Map)['media_formats'] as Map?;
          final tiny = formats?['tinygif'] as Map?;
          final gif = formats?['gif'] as Map?;
          if (tiny == null || gif == null) return null;
          final dims = (gif['dims'] as List?)?.cast<num>();
          return GifItem(
            previewUrl: tiny['url'] as String,
            url: gif['url'] as String,
            width: dims != null && dims.length == 2 ? dims[0].toInt() : null,
            height: dims != null && dims.length == 2 ? dims[1].toInt() : null,
          );
        })
        .whereType<GifItem>()
        .toList();
  }
}
