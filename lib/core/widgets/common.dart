import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/media_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_theme.dart';
import '../utils/failure.dart';

/// Hafif gölgeli premium kart.
class VisalCard extends StatelessWidget {
  const VisalCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(20),
    this.radius = AppRadii.card,
    this.onTap,
    this.color,
    this.gradient,
    this.margin,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final VoidCallback? onTap;
  final Color? color;
  final Gradient? gradient;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final palette = context.palette;
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: gradient == null ? (color ?? palette.card) : null,
        gradient: gradient,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: palette.cardBorder),
        boxShadow: [
          BoxShadow(
            color: palette.shadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(radius),
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}

/// "Hızlı Erişim ............ Tümünü Gör >"
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.leading,
    this.padding = const EdgeInsets.fromLTRB(4, 0, 0, 12),
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? leading;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 10)],
          Expanded(child: Text(title, style: context.text.titleLarge)),
          if (onAction != null)
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                child: Row(
                  children: [
                    if (actionLabel != null)
                      Text(
                        actionLabel!,
                        style: context.text.labelMedium?.copyWith(
                          color: context.palette.textSecondary,
                        ),
                      ),
                    const SizedBox(width: 6),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: context.palette.textPrimary,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Önbellekli ağ görseli. Private Storage referansları görüntüleme anında
/// kısa ömürlü signed URL'ye çevrilir; DB'de kalıcı erişim anahtarı tutulmaz.
class NetImage extends ConsumerWidget {
  const NetImage(
    this.url, {
    super.key,
    this.thumbUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.radius = 0,
    this.memCacheWidth,
  });

  final String? url;
  final String? thumbUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final double radius;
  final int? memCacheWidth;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final placeholder = Container(
      width: width,
      height: height,
      color: context.isDark ? AppColors.darkElevated : AppColors.blush,
    );
    final raw = url;
    if (raw == null || raw.isEmpty) return _clip(placeholder);
    if (raw.startsWith('/')) {
      // Yerel dosya (demo modu / gönderim önizlemesi).
      return _clip(Image.file(File(raw), fit: fit, width: width, height: height, cacheWidth: memCacheWidth));
    }

    String? resolvedThumb = thumbUrl;
    if (MediaService.isStorageRef(thumbUrl)) {
      resolvedThumb = ref.watch(resolvedStorageUrlProvider(thumbUrl!)).value;
    }

    if (MediaService.isStorageRef(raw)) {
      final resolved = ref.watch(resolvedStorageUrlProvider(raw));
      return resolved.when(
        data: (actualUrl) => _network(context, actualUrl, resolvedThumb, placeholder),
        loading: () => _clip(
          resolvedThumb == null
              ? placeholder
              : CachedNetworkImage(imageUrl: resolvedThumb, fit: fit, width: width, height: height),
        ),
        error: (_, _) => _error(context, placeholder),
      );
    }
    return _network(context, raw, resolvedThumb, placeholder);
  }

  Widget _network(BuildContext context, String actualUrl, String? resolvedThumb, Container placeholder) {
    final image = CachedNetworkImage(
      imageUrl: actualUrl,
      fit: fit,
      width: width,
      height: height,
      memCacheWidth: memCacheWidth,
      fadeInDuration: const Duration(milliseconds: 220),
      placeholder: (_, _) => resolvedThumb != null
          ? CachedNetworkImage(imageUrl: resolvedThumb, fit: fit, width: width, height: height)
          : placeholder,
      errorWidget: (_, _, _) => _error(context, placeholder, clipped: false),
    );
    return _clip(image);
  }

  Widget _error(BuildContext context, Container placeholder, {bool clipped = true}) {
    final child = Container(
      width: width,
      height: height,
      color: placeholder.color,
      alignment: Alignment.center,
      child: Icon(Icons.image_not_supported_outlined, color: context.palette.muted),
    );
    return clipped ? _clip(child) : child;
  }

  Widget _clip(Widget child) => radius > 0
      ? ClipRRect(borderRadius: BorderRadius.circular(radius), child: child)
      : child;
}

class AppAvatar extends StatelessWidget {
  const AppAvatar({super.key, this.url, this.name = '', this.size = 44, this.ring = false});

  final String? url;
  final String name;
  final double size;
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join().toUpperCase();
    final avatar = ClipOval(
      child: SizedBox(
        width: size,
        height: size,
        child: (url != null && url!.isNotEmpty)
            ? NetImage(url, memCacheWidth: (size * 3).round())
            : DecoratedBox(
                decoration: const BoxDecoration(gradient: AppColors.logoGradient),
                child: Center(
                  child: Text(
                    initials,
                    style: TextStyle(
                      fontFamily: kFontFamily,
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: size * 0.36,
                    ),
                  ),
                ),
              ),
      ),
    );
    if (!ring) return avatar;
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.logoGradient),
      child: Container(
        padding: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Theme.of(context).scaffoldBackgroundColor,
        ),
        child: avatar,
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.action,
    this.emoji,
  });

  final IconData icon;
  final String title;
  final String? message;
  final Widget? action;
  final String? emoji;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.palette.softAccent,
              ),
              alignment: Alignment.center,
              child: emoji != null
                  ? Text(emoji!, style: const TextStyle(fontSize: 32))
                  : Icon(icon, size: 32, color: AppColors.mauve),
            ),
            const SizedBox(height: 20),
            Text(title, style: context.text.titleLarge, textAlign: TextAlign.center),
            if (message != null) ...[
              const SizedBox(height: 8),
              Text(
                message!,
                style: context.text.bodyMedium?.copyWith(color: context.palette.textSecondary),
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[const SizedBox(height: 24), action!],
          ],
        ),
      ),
    );
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  @override
  Widget build(BuildContext context) => const Center(
        child: SizedBox(
          width: 28,
          height: 28,
          child: CircularProgressIndicator(strokeWidth: 2.2),
        ),
      );
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.error, this.onRetry});

  final Object error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => EmptyState(
        icon: Icons.cloud_off_rounded,
        title: 'Bir sorun oluştu',
        message: AppFailure.from(error).message,
        action: onRetry == null
            ? null
            : OutlinedButton(onPressed: onRetry, child: const Text('Tekrar dene')),
      );
}

/// AsyncValue için kısa yardımcı.
class AsyncView<T> extends StatelessWidget {
  const AsyncView({super.key, required this.value, required this.data, this.loading});

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final Widget? loading;

  @override
  Widget build(BuildContext context) => value.when(
        data: data,
        loading: () => loading ?? const LoadingView(),
        error: (e, _) => ErrorView(error: e),
      );
}

extension SnackX on BuildContext {
  void showSnack(String message) {
    ScaffoldMessenger.of(this)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  void showError(Object error) => showSnack(AppFailure.from(error).message);

  Future<bool> confirm({
    required String title,
    String? message,
    String confirmLabel = 'Onayla',
    bool destructive = false,
  }) async {
    final result = await showDialog<bool>(
      context: this,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: message == null ? null : Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Vazgeç', style: TextStyle(color: ctx.palette.textSecondary)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              confirmLabel,
              style: TextStyle(color: destructive ? AppColors.error : null),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}

/// Alt sayfa (bottom sheet) içinde başlık + içerik düzeni.
class SheetScaffold extends StatelessWidget {
  const SheetScaffold({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 16, 12),
              child: Row(
                children: [
                  Expanded(child: Text(title, style: context.text.headlineSmall)),
                  ?trailing,
                ],
              ),
            ),
            Flexible(child: child),
          ],
        ),
      ),
    );
  }
}

/// Seçilebilir hap filtre.
class PillChip extends StatelessWidget {
  const PillChip({super.key, required this.label, required this.selected, required this.onTap});

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final dark = context.isDark;
    final bg = selected ? (dark ? AppColors.rose : AppColors.midnight) : context.palette.card;
    final fg = selected
        ? (dark ? AppColors.midnight : AppColors.ivory)
        : context.palette.textSecondary;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: selected ? Colors.transparent : Theme.of(context).colorScheme.outlineVariant,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(30),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          child: Text(
            label,
            style: context.text.labelMedium?.copyWith(
              color: fg,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
