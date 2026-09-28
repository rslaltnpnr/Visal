import 'package:flutter/services.dart';

/// Uygulamadaki tüm görsel varlıkların tek adresi.
///
/// Marka görsellerini değiştirmek için aynı dosya adlarıyla
/// `assets/brand/` ve `assets/images/` klasörlerine koymanız yeterli.
/// `logo_mark.png` bulunmazsa vektörel V sembolü kullanılır.
abstract final class AppAssets {
  static Set<String> _available = const {};

  /// Uygulama açılışında bir kez çağrılır; hangi marka dosyalarının
  /// eklendiğini asset manifest'ten okur.
  static Future<void> load() async {
    try {
      final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      _available = manifest.listAssets().toSet();
    } catch (_) {
      _available = const {};
    }
  }

  static bool has(String path) => _available.contains(path);

  // Marka
  static const logoMark = 'assets/brand/logo_mark.png';
  static const logoMarkLight = 'assets/brand/logo_mark_light.png';
  static const appIcon = 'assets/icon/app_icon.png';

  // Varsayılan görseller
  static const splashBackground = 'assets/images/splash_bg.jpg';
  static const heroDefault = 'assets/images/hero.jpg';
  static const togetherCard = 'assets/images/together.jpg';
  static const fabric = 'assets/images/fabric.jpg';
}
