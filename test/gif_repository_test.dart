import 'package:flutter_test/flutter_test.dart';
import 'package:visal/features/chat/data/gif_repository.dart';

void main() {
  test('GIPHY yanıtı ayrıştırılır, eksik görseller atlanır', () {
    final items = GiphyGifRepository.parse({
      'data': [
        {
          'images': {
            'fixed_width_small': {'url': 'https://media.giphy.com/a/200w.gif'},
            'downsized': {'url': 'https://media.giphy.com/a/giphy.gif', 'width': '480', 'height': '270'},
          },
        },
        {'images': <String, dynamic>{}},
      ],
    });
    expect(items, hasLength(1));
    expect(items.first.previewUrl, endsWith('200w.gif'));
    expect(items.first.url, endsWith('giphy.gif'));
    expect(items.first.width, 480);
    expect(items.first.height, 270);
  });
}
