import 'package:hive/hive.dart';
import '../../../core/constants/z_strings.dart';
import 'note_attachment.dart';
part 'note.g.dart';

@HiveType(typeId: ZStrings.noteModelTypeId)
class Note {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String body;
  @HiveField(3)
  final DateTime timestamp;
  @HiveField(4)
  final int color;
  @HiveField(5)
  final bool isLocked;

  @HiveField(6)
  final String? richText;

  @HiveField(7)
  final String? paper;

  @HiveField(8)
  final String? media;

  late final List<NoteAttachmentKind> attachmentKinds = NoteAttachment.kindsIn(
    media,
  );

  Note({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.color,
    required this.isLocked,
    this.richText,
    this.paper,
    this.media,
  });

  factory Note.fromJson(Map<String, dynamic> json) {
    return Note(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      timestamp:
          DateTime.tryParse(json['timestamp'] as String? ?? '') ??
          DateTime.now(),
      color: json['color'] ?? 0,
      isLocked: json['isLocked'] ?? false,
      richText: json['richText'] as String?,
      paper: json['paper'] is String ? json['paper'] as String : null,
      media: json['media'] is String ? json['media'] as String : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'body': body,
      'timestamp': timestamp.toIso8601String(),
      'color': color,
      'isLocked': isLocked,
      'richText': richText,
      'paper': paper,
      'media': media,
    };
  }
}
