abstract final class CreatePostValidators {
  static String? requiredText(String? value) =>
      value == null || value.trim().isEmpty ? 'Bu alan zorunludur.' : null;

  static String? schedule(
    DateTime? startsAt,
    DateTime? endsAt, {
    DateTime? now,
  }) {
    if (startsAt == null || endsAt == null) return 'Tarih ve iki saati seçin.';
    if (!startsAt.isAfter(now ?? DateTime.now())) {
      return 'Başlangıç gelecekte olmalıdır.';
    }
    if (startsAt.year != endsAt.year ||
        startsAt.month != endsAt.month ||
        startsAt.day != endsAt.day) {
      return 'Ders aynı gün başlayıp bitmelidir.';
    }
    if (!endsAt.isAfter(startsAt)) return 'Bitiş başlangıçtan sonra olmalıdır.';
    return null;
  }
}
