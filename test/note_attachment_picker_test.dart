import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/model/note_attachment.dart';
import 'package:jot_it/features/notes/services/note_attachment_picker.dart';
import 'support/media_fixtures.dart';

class _FilePicker extends FilePicker {
  FilePickerResult? result;
  List<String>? extensions;
  bool streamed = false;
  @override
  Future<FilePickerResult?> pickFiles({
    String? dialogTitle,
    String? initialDirectory,
    FileType type = FileType.any,
    List<String>? allowedExtensions,
    Function(FilePickerStatus)? onFileLoading,
    bool allowCompression = false,
    int compressionQuality = 0,
    bool allowMultiple = false,
    bool withData = false,
    bool withReadStream = false,
    bool lockParentWindow = false,
    bool readSequential = false,
  }) async {
    extensions = allowedExtensions;
    streamed = withReadStream && !withData && !allowMultiple;
    return result;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final platform = _FilePicker();
  final picker = NoteAttachmentPicker();
  setUp(() => FilePicker.platform = platform);

  test(
    'cancelled file selection changes nothing and filters only supported media',
    () async {
      platform.result = null;
      expect(await picker.pick(NoteAttachmentKind.image), isNull);
      expect(platform.extensions, contains('png'));
      expect(platform.extensions, isNot(contains('svg')));
      expect(platform.streamed, true);
    },
  );

  test('a streamed image is copied without retaining a source path', () async {
    final bytes = await samplePng();
    platform.result = FilePickerResult([
      PlatformFile(
        name: 'reference.png',
        size: bytes.length,
        readStream: Stream.value(bytes),
      ),
    ]);
    final selected = await picker.pick(NoteAttachmentKind.image);
    expect(selected!.bytes, bytes);
    expect(selected.mimeType, 'image/png');
    expect(selected.name, 'reference.png');
  });

  test(
    'oversized files are rejected both before and during streamed reading',
    () async {
      platform.result = FilePickerResult([
        PlatformFile(name: 'clip.wav', size: NoteAttachment.maxFileBytes + 1),
      ]);
      await expectLater(
        picker.pick(NoteAttachmentKind.audio),
        throwsFormatException,
      );
      platform.result = FilePickerResult([
        PlatformFile(
          name: 'clip.wav',
          size: 0,
          readStream: Stream.fromIterable([
            Uint8List(NoteAttachment.maxFileBytes),
            Uint8List(2),
          ]),
        ),
      ]);
      await expectLater(
        picker.pick(NoteAttachmentKind.audio),
        throwsFormatException,
      );
    },
  );

  test('wrong file kinds and empty files never become attachments', () async {
    platform.result = FilePickerResult([
      PlatformFile(
        name: 'code.svg',
        size: 5,
        readStream: Stream.value([1, 2, 3, 4, 5]),
      ),
    ]);
    await expectLater(
      picker.pick(NoteAttachmentKind.image),
      throwsFormatException,
    );
    platform.result = FilePickerResult([
      PlatformFile(
        name: 'empty.wav',
        size: 0,
        readStream: const Stream.empty(),
      ),
    ]);
    await expectLater(
      picker.pick(NoteAttachmentKind.audio),
      throwsFormatException,
    );
  });
}
