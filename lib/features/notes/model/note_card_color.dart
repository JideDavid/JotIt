class NoteCardColor {
  static const presetCount = 9;
  static const maxFavorites = 24;

  static bool isCustom(int value) => value >= 0xff000000 && value <= 0xffffffff;
  static bool isValid(int value) =>
      (value >= 0 && value < presetCount) || isCustom(value);
  static int normalize(int value) =>
      isCustom(value) ? value : value.clamp(0, presetCount - 1);
  static String hex(int value) =>
      '#${(value & 0xffffff).toRadixString(16).padLeft(6, '0').toUpperCase()}';

  static int? parseHex(String value) {
    final text = value.trim().replaceFirst(RegExp(r'^#'), '');
    return RegExp(r'^[0-9a-fA-F]{6}$').hasMatch(text)
        ? 0xff000000 | int.parse(text, radix: 16)
        : null;
  }

  static List<int> favoritesFrom(Object? value) => value is List
      ? value
            .whereType<int>()
            .where(isCustom)
            .toSet()
            .take(maxFavorites)
            .toList()
      : [];
}
