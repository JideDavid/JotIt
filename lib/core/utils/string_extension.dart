extension StringExtension on String {
  String toTitleCase() {
    if (isEmpty) return this;

    return replaceAll('_', ' ')      // convert _ to space
        .trim()
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .map((word) =>
    word.isEmpty
        ? ''
        : word[0].toUpperCase() + word.substring(1))
        .join(' ');
  }
}