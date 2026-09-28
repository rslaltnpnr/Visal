abstract final class Validators {
  static final _email = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]{2,}$');

  static String? email(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'E-posta gerekli';
    if (!_email.hasMatch(value)) return 'Geçerli bir e-posta girin';
    return null;
  }

  static String? password(String? v) {
    final value = v ?? '';
    if (value.isEmpty) return 'Şifre gerekli';
    if (value.length < 8) return 'En az 8 karakter olmalı';
    if (!RegExp(r'[A-Za-zÇĞİÖŞÜçğıöşü]').hasMatch(value) ||
        !RegExp(r'\d').hasMatch(value)) {
      return 'Harf ve rakam içermeli';
    }
    return null;
  }

  static String? required(String? v, [String label = 'Bu alan']) =>
      (v?.trim().isEmpty ?? true) ? '$label gerekli' : null;

  static String? name(String? v) {
    final value = v?.trim() ?? '';
    if (value.isEmpty) return 'Adınız gerekli';
    if (value.length > 40) return 'En fazla 40 karakter';
    return null;
  }
}
