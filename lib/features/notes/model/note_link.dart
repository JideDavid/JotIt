Uri? parseNoteLink(String value) {
  final text = value.trim();
  if (text.isEmpty || RegExp(r'\s').hasMatch(text)) return null;
  var uri = Uri.tryParse(text);
  if (uri == null) return null;
  if (!uri.hasScheme) uri = Uri.tryParse('https://$text');
  if (uri == null) return null;
  if ((uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty) {
    return uri;
  }
  if (uri.scheme == 'mailto' &&
      RegExp(r'^[^@]+@[^@]+\.[^@]+$').hasMatch(uri.path)) {
    return uri;
  }
  return null;
}
