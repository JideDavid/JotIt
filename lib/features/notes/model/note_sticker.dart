import 'dart:convert';
import 'package:flutter/material.dart';

enum StickerVisual {
  pinned,
  tape,
  torn,
  folded,
  spiral,
  envelope,
  frame,
  profile,
  label,
  ticket,
  ribbon,
  bubble,
  seal,
  star,
  arrow,
  heart,
  sparkles,
}

class StickerFormat {
  const StickerFormat(
    this.id,
    this.name,
    this.category,
    this.visual, {
    this.width = 150,
    this.text = 'A thought to keep',
    this.body = 'One small idea can lead to something bigger.',
  });
  final String id, name, category, text, body;
  final StickerVisual visual;
  final double width;
  bool get isDoodle => visual.index >= StickerVisual.star.index;
  bool get hasBody => visual.index <= StickerVisual.profile.index;
}

class StickerCatalog {
  StickerCatalog._();
  static const formats = [
    StickerFormat(
      'pinned-paper',
      'Pinned paper',
      'Paper notes',
      StickerVisual.pinned,
    ),
    StickerFormat(
      'taped-memo',
      'Taped memo',
      'Paper notes',
      StickerVisual.tape,
    ),
    StickerFormat(
      'torn-paper',
      'Torn notebook',
      'Paper notes',
      StickerVisual.torn,
    ),
    StickerFormat(
      'folded-note',
      'Folded corner',
      'Paper notes',
      StickerVisual.folded,
    ),
    StickerFormat(
      'spiral-page',
      'Spiral page',
      'Paper notes',
      StickerVisual.spiral,
    ),
    StickerFormat(
      'envelope',
      'Little envelope',
      'Paper notes',
      StickerVisual.envelope,
    ),
    StickerFormat('pin-frame', 'Bold pin frame', 'Cards', StickerVisual.frame),
    StickerFormat(
      'profile-card',
      'Profile review',
      'Cards',
      StickerVisual.profile,
      width: 238,
      text: 'Your name',
      body: 'Your thoughts, recommendation, or review.',
    ),
    StickerFormat(
      'text-label',
      'Classic label',
      'Labels',
      StickerVisual.label,
      width: 130,
      text: 'KEY IDEA',
      body: '',
    ),
    StickerFormat(
      'ticket',
      'Ticket stub',
      'Labels',
      StickerVisual.ticket,
      width: 140,
      text: 'WORTH KEEPING',
      body: '',
    ),
    StickerFormat(
      'ribbon',
      'Ribbon flag',
      'Labels',
      StickerVisual.ribbon,
      width: 130,
      text: 'REMEMBER',
      body: '',
    ),
    StickerFormat(
      'speech-bubble',
      'Speech bubble',
      'Labels',
      StickerVisual.bubble,
      width: 140,
      text: 'WHAT IF?',
      body: '',
    ),
    StickerFormat(
      'seal',
      'Scalloped seal',
      'Labels',
      StickerVisual.seal,
      width: 90,
      text: 'GOOD IDEA',
      body: '',
    ),
    StickerFormat(
      'star',
      'Star',
      'Doodles',
      StickerVisual.star,
      width: 48,
      text: '',
      body: '',
    ),
    StickerFormat(
      'arrow',
      'Arrow',
      'Doodles',
      StickerVisual.arrow,
      width: 48,
      text: '',
      body: '',
    ),
    StickerFormat(
      'heart',
      'Heart',
      'Doodles',
      StickerVisual.heart,
      width: 48,
      text: '',
      body: '',
    ),
    StickerFormat(
      'sparkles',
      'Sparkle',
      'Doodles',
      StickerVisual.sparkles,
      width: 48,
      text: '',
      body: '',
    ),
  ];
  static const colors = [
    Color(0xffe9af35),
    Color(0xffee8d61),
    Color(0xff9f79cf),
    Color(0xff6da783),
    Color(0xff688ece),
  ];
  static StickerFormat? find(String id) {
    for (final format in formats) {
      if (format.id == id) return format;
    }
    return null;
  }
}

/// A placed instance owns its text and color; catalog entries represent shapes.
/// The complete payload lives in the Quill embed, so edits, moves and deletion
/// use the document's native undo history and survive export/reopening.
class NoteSticker {
  const NoteSticker({
    required this.id,
    required this.formatId,
    this.text = '',
    this.body = '',
    this.color = 0xffe9af35,
    this.width = 150,
    this.rotation = -0.06,
    this.free = false,
    this.x = 0.3,
    this.dy = 0,
    this.meta = '',
    this.rating = 5,
  });
  static const embedType = 'jot-sticker';
  final String id, formatId, text, body, meta;
  final int color, rating;
  final double width, rotation, x, dy;
  final bool free;
  StickerFormat? get format => StickerCatalog.find(formatId);
  NoteSticker copyWith({
    String? text,
    String? body,
    int? color,
    double? width,
    double? rotation,
    bool? free,
    double? x,
    double? dy,
    String? meta,
    int? rating,
  }) => NoteSticker(
    id: id,
    formatId: formatId,
    text: text ?? this.text,
    body: body ?? this.body,
    color: color ?? this.color,
    width: width ?? this.width,
    rotation: rotation ?? this.rotation,
    free: free ?? this.free,
    x: x ?? this.x,
    dy: dy ?? this.dy,
    meta: meta ?? this.meta,
    rating: rating ?? this.rating,
  );
  Map<String, dynamic> toJson() => {
    'version': 1,
    'id': id,
    'format': formatId,
    'text': text,
    'body': body,
    'color': color,
    'width': width,
    'rotation': rotation,
    'free': free,
    'x': x,
    'dy': dy,
    'meta': meta,
    'rating': rating,
  };
  String encode() => jsonEncode(toJson());
  static NoteSticker? decode(dynamic data) {
    try {
      final j = data is String ? jsonDecode(data) : data;
      if (j is! Map ||
          j['version'] != 1 ||
          j['id'] is! String ||
          j['format'] is! String) {
        return null;
      }
      String string(String key, int max) {
        final value = j[key];
        return value is String && value.length <= max ? value : '';
      }

      double number(String key, double fallback, double min, double max) {
        final n = j[key];
        return n is num && n.isFinite ? n.toDouble().clamp(min, max) : fallback;
      }

      return NoteSticker(
        id: j['id'],
        formatId: j['format'],
        text: string('text', 100),
        body: string('body', 500),
        meta: string('meta', 80),
        color: j['color'] is int
            ? (j['color'] as int) | 0xff000000
            : 0xffe9af35,
        width: number('width', 150, 28, 320),
        rotation: number('rotation', 0, -0.5, 0.5),
        free: j['free'] == true,
        x: number('x', .3, 0, 1),
        dy: number('dy', 0, -5000, 5000),
        rating: number('rating', 5, 1, 5).round(),
      );
    } catch (_) {
      return null;
    }
  }

  static NoteSticker? fromInsert(dynamic insert) =>
      insert is Map ? decode(insert[embedType]) : null;
}
