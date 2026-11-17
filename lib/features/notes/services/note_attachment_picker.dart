import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:file_picker/file_picker.dart';
import '../../../../core/utils/random_id_generator.dart';
import '../model/note_attachment.dart';

class NoteAttachmentPicker {
  Future<NoteAttachment?> pick(NoteAttachmentKind kind) async {
    final extensions = NoteAttachment.mimeTypes.entries
        .where((entry) => entry.value.startsWith('${kind.name}/'))
        .map((entry) => entry.key)
        .toList();
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: extensions,
      allowMultiple: false,
      withReadStream: true,
      withData: false,
    );
    if (result == null) return null;
    final file = result.files.single;
    final mime = NoteAttachment.mimeTypes[file.extension?.toLowerCase()];
    if (mime == null || !mime.startsWith('${kind.name}/')) {
      throw const FormatException('Choose a supported image or audio file.');
    }
    if (file.size > NoteAttachment.maxFileBytes) {
      throw const FormatException('Choose a file smaller than 5 MB.');
    }
    final stream = file.readStream ?? file.xFile.openRead();
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in stream) {
      if (bytes.length + chunk.length > NoteAttachment.maxFileBytes) {
        throw const FormatException('Choose a file smaller than 5 MB.');
      }
      bytes.add(chunk);
    }
    final attachment = NoteAttachment(
      id: RandomId().generate(),
      name: file.name,
      mimeType: mime,
      bytes: bytes.takeBytes(),
    );
    if (attachment.bytes.isEmpty) {
      throw const FormatException('This file is empty.');
    }
    if (kind == NoteAttachmentKind.image) {
      final buffer = await ui.ImmutableBuffer.fromUint8List(attachment.bytes);
      final codec = await ui.instantiateImageCodecWithSize(
        buffer,
        getTargetSize: (width, height) {
          if (width * height > 40000000) {
            throw const FormatException('Choose an image under 40 megapixels.');
          }
          return ui.TargetImageSize(width: 1, height: 1);
        },
      );
      try {
        final frame = await codec.getNextFrame();
        frame.image.dispose();
      } finally {
        codec.dispose();
      }
    }
    return attachment;
  }
}
