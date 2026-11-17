import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import '../model/note_sticker.dart';

class PlacedSticker {
  const PlacedSticker(this.offset, this.sticker);
  final int offset;
  final NoteSticker sticker;
}

class NoteDocumentEdits {
  NoteDocumentEdits._();
  static List<PlacedSticker> stickers(Document document) {
    final result = <PlacedSticker>[];
    var offset = 0;
    for (final op in document.toDelta().toJson()) {
      final insert = op['insert'];
      final sticker = NoteSticker.fromInsert(insert);
      if (sticker != null) result.add(PlacedSticker(offset, sticker));
      offset += insert is String ? insert.length : 1;
    }
    return result;
  }

  static void compose(QuillController controller, Delta change, int caret) {
    controller.document.history.lastRecorded = 0;
    controller.compose(
      change,
      TextSelection.collapsed(offset: caret),
      ChangeSource.local,
    );
    controller.updateSelection(
      TextSelection.collapsed(
        offset: caret.clamp(0, controller.document.length - 1),
      ),
      ChangeSource.local,
    );
    controller.document.history.lastRecorded = 0;
  }

  static void insert(
    QuillController controller,
    NoteSticker sticker,
    int offset,
  ) {
    final target = offset.clamp(0, controller.document.length - 1);
    compose(
      controller,
      Delta()
        ..retain(target)
        ..insert({NoteSticker.embedType: sticker.encode()}),
      target + 1,
    );
  }

  static bool update(
    QuillController controller,
    String id,
    NoteSticker? sticker,
  ) {
    for (final placed in stickers(controller.document)) {
      if (placed.sticker.id != id) continue;
      final change = Delta()..retain(placed.offset);
      if (sticker != null) {
        change.insert({NoteSticker.embedType: sticker.encode()});
      }
      change.delete(1);
      compose(controller, change, placed.offset + (sticker == null ? 0 : 1));
      return true;
    }
    return false;
  }

  static bool move(
    QuillController controller,
    String id,
    int target,
    NoteSticker replacement,
  ) {
    for (final placed in stickers(controller.document)) {
      if (placed.sticker.id != id) continue;
      final clamped = target.clamp(0, controller.document.length - 1);
      final destination = clamped > placed.offset ? clamped - 1 : clamped;
      final deletion = Delta()
        ..retain(placed.offset)
        ..delete(1);
      final insertion = Delta()
        ..retain(destination)
        ..insert({NoteSticker.embedType: replacement.encode()});
      compose(controller, deletion.compose(insertion), destination + 1);
      return true;
    }
    return false;
  }
}
