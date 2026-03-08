
import 'dart:ui';

import 'package:hive/hive.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/z_strings.dart';
part 'note_model.g.dart';

@HiveType(typeId: ZStrings.noteModelTypeId)
class NoteModel {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final String title;
  @HiveField(2)
  final String body;
  @HiveField(3)
  final DateTime timestamp;
  @HiveField(4)
  final Color color;
  @HiveField(5)
  final bool isLocked;



  NoteModel({
    required this.id,
    required this.title,
    required this.body,
    required this.timestamp,
    required this.color,
    required this.isLocked,
  });

  factory NoteModel.fromJson(Map<String, dynamic> json) {
    return NoteModel(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      body: json['body'] ?? '',
      timestamp: DateTime.parse(json['timestamp'] ?? DateTime.now()),
      color: json['color'] ?? ZColors.defaultNoteColor,
      isLocked: json['isLocked'] ?? false,
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
    };
  }

}