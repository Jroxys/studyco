/// Registration rules independent of widgets and any future API transport.
abstract final class RegistrationValidators {
  static String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Bu alan zorunludur.' : null;

  static String? email(String? value) {
    if (requiredText(value) != null) return 'E-posta adresinizi girin.';
    return RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(value!.trim())
        ? null
        : 'Geçerli bir e-posta adresi girin.';
  }

  static String? phone(String? value) {
    if (requiredText(value) != null) return 'Telefon numaranızı girin.';
    final phone = value!.trim().replaceAll(RegExp(r'[\s()\-]'), '');
    // Turkish mobile numbers or international numbers with an explicit + prefix.
    return RegExp(r'^(?:0?5\d{9}|\+[1-9]\d{7,14})$').hasMatch(phone)
        ? null
        : 'Geçerli bir telefon numarası girin.';
  }

  static String? birthDate(DateTime? value, {DateTime? today}) {
    if (value == null) return 'Doğum tarihinizi seçin.';
    final now = today ?? DateTime.now();
    final date = DateTime(value.year, value.month, value.day);
    if (date.isAfter(DateTime(now.year, now.month, now.day))) {
      return 'Doğum tarihi gelecekte olamaz.';
    }
    return null;
  }

  static String? password(String? value) {
    if (requiredText(value) != null) return 'Şifrenizi girin.';
    return value!.runes.length < 8 ? 'Şifre en az 8 karakter olmalıdır.' : null;
  }

  static String? confirmPassword(String? value, String password) {
    if (requiredText(value) != null) return 'Şifrenizi tekrar girin.';
    return value != password ? 'Şifreler eşleşmiyor.' : null;
  }

  static String? consent(bool? value) =>
      value == true ? null : 'Devam etmek için koşulları onaylayın.';
}
