import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/widgets/common.dart';
import '../../data/gif_repository.dart';

Future<GifItem?> showGifPicker(BuildContext context) => showModalBottomSheet<GifItem>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const FractionallySizedBox(heightFactor: 0.8, child: _GifPicker()),
    );

class _GifPicker extends ConsumerStatefulWidget {
  const _GifPicker();

  @override
  ConsumerState<_GifPicker> createState() => _GifPickerState();
}

class _GifPickerState extends ConsumerState<_GifPicker> {
  List<GifItem> _items = const [];
  bool _loading = true;
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    _load('');
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load(String q) async {
    setState(() => _loading = true);
    final repo = ref.read(gifRepositoryProvider);
    try {
      final items = q.trim().isEmpty ? await repo.trending() : await repo.search(q);
      if (mounted) setState(() => _items = items);
    } catch (_) {
      if (mounted) setState(() => _items = const []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SheetScaffold(
      title: 'GIF',
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'GIF ara',
                prefixIcon: Icon(Icons.search_rounded),
              ),
              onChanged: (v) {
                _debounce?.cancel();
                _debounce = Timer(const Duration(milliseconds: 400), () => _load(v));
              },
            ),
          ),
          Expanded(
            child: _loading
                ? const LoadingView()
                : GridView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 6,
                      crossAxisSpacing: 6,
                    ),
                    itemCount: _items.length,
                    itemBuilder: (context, i) => GestureDetector(
                      onTap: () => Navigator.pop(context, _items[i]),
                      child: NetImage(_items[i].previewUrl, radius: 14),
                    ),
                  ),
          ),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(ref.read(gifRepositoryProvider).attribution, style: Theme.of(context).textTheme.labelSmall),
          ),
        ],
      ),
    );
  }
}
