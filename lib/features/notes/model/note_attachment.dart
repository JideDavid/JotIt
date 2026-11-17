import 'dart:convert';
import 'dart:typed_data';

enum NoteAttachmentKind { image, audio }

class NoteAttachment {
  NoteAttachment({
    required this.id,
    required String name,
    required this.mimeType,
    required Uint8List bytes,
  }) : name = name
           .split(RegExp(r'[/\\]'))
           .last
           .replaceAll(RegExp(r'[\x00-\x1f]'), ''),
       bytes = Uint8List.fromList(bytes).asUnmodifiableView();

  static const embedType = 'jotit-media';
  static const maxFileBytes = 5 * 1024 * 1024;
  static const maxNoteBytes = 20 * 1024 * 1024;
  static const maxAttachments = 12;
  static const mimeTypes = {
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'mp3': 'audio/mpeg',
    'wav': 'audio/wav',
    'm4a': 'audio/mp4',
    'aac': 'audio/aac',
    'ogg': 'audio/ogg',
    'webm': 'audio/webm',
    'flac': 'audio/flac',
  };

  final String id;
  final String name;
  final String mimeType;
  final Uint8List bytes;

  NoteAttachmentKind get kind => mimeType.startsWith('image/')
      ? NoteAttachmentKind.image
      : NoteAttachmentKind.audio;

  String get sizeLabel => bytes.length < 1024 * 1024
      ? '${(bytes.length / 1024).ceil()} KB'
      : '${(bytes.length / (1024 * 1024)).toStringAsFixed(1)} MB';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mime': mimeType,
    'bytes': base64Encode(bytes),
  };

  static List<NoteAttachment> decodeAll(String? encoded) {
    if (encoded == null) return const [];
    try {
      final data = jsonDecode(encoded);
      if (data is! List) return const [];
      return data
          .map((item) {
            if (item is! Map ||
                item['id'] is! String ||
                item['name'] is! String ||
                !mimeTypes.values.contains(item['mime']) ||
                item['bytes'] is! String) {
              throw const FormatException('Invalid attachment');
            }
            return NoteAttachment(
              id: item['id'],
              name: item['name'],
              mimeType: item['mime'],
              bytes: base64Decode(item['bytes']),
            );
          })
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  static String? encodeAll(Iterable<NoteAttachment> attachments) {
    final data = attachments.map((item) => item.toJson()).toList();
    return data.isEmpty ? null : jsonEncode(data);
  }

  static List<NoteAttachmentKind> kindsIn(String? encoded) {
    if (encoded == null) return const [];
    try {
      final data = jsonDecode(encoded);
      if (data is! List) return const [];
      return data
          .whereType<Map>()
          .map((item) => item['mime'])
          .whereType<String>()
          .where(mimeTypes.values.contains)
          .map(
            (mime) => mime.startsWith('image/')
                ? NoteAttachmentKind.image
                : NoteAttachmentKind.audio,
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  static String? embeddedId(dynamic insert) {
    try {
      if (insert is Map && insert[embedType] is String) {
        return insert[embedType] as String;
      }
      if (insert is! Map || insert['custom'] is! String) return null;
      final data = jsonDecode(insert['custom'] as String);
      return data is Map && data[embedType] is String
          ? data[embedType] as String
          : null;
    } catch (_) {
      return null;
    }
  }
}
