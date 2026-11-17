import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/model/note_attachment.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/services/note_media_controller.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/widgets/note_attachment_drag.dart';
import 'package:jot_it/features/notes/view/widgets/note_attachment_embed.dart';

import 'support/fakes.dart';
import 'support/media_fixtures.dart';

void main() {
  for (final kind in NoteAttachmentKind.values) {
    testWidgets('${kind.name} can drag down and back up with undo', (
      tester,
    ) async {
      final notes = NoteViewModel(
        notesRepo: NotesRepo(localStorageService: MemoryStorage()),
      );
      final media = NoteMediaController();
      final focus = FocusNode();
      final scroll = ScrollController();
      final editorKey = GlobalKey<EditorState>();
      addTearDown(() {
        media.dispose();
        notes.dispose();
        focus.dispose();
        scroll.dispose();
      });
      final bytes = await tester.runAsync(samplePng);
      setBodyText(notes.bodyController, 'First\nSecond\nThird');
      notes.attachMedia(
        NoteAttachment(
          id: 'drag',
          name: kind == NoteAttachmentKind.image ? 'Photo.png' : 'Voice.wav',
          mimeType: kind == NoteAttachmentKind.image
              ? 'image/png'
              : 'audio/wav',
          bytes: kind == NoteAttachmentKind.image
              ? bytes!
              : NoteMediaController.wavFromPcm(bytes!),
        ),
        selection: const TextSelection.collapsed(offset: 0),
      );
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(
            body: NoteAttachmentDragLayer(
              notes: notes,
              editorKey: editorKey,
              scrollController: scroll,
              child: QuillEditor.basic(
                controller: notes.bodyController,
                focusNode: focus,
                scrollController: scroll,
                config: QuillEditorConfig(
                  editorKey: editorKey,
                  expands: true,
                  padding: const EdgeInsets.all(24),
                  embedBuilders: [
                    NoteAttachmentEmbedBuilder(notes: notes, media: media),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = notes.bodyController.document.toDelta().toJson();
      Future<void> dragTo(int offset, PointerDeviceKind device) async {
        final editor = editorKey.currentState!.renderEditor;
        final caret = editor.getLocalRectForCaret(TextPosition(offset: offset));
        final target = editor.localToGlobal(Offset(30, caret.top + 1));
        final gesture = await tester.startGesture(
          tester.getCenter(find.byKey(const ValueKey('attachment-drag-drag'))),
          kind: device,
        );
        await gesture.moveBy(const Offset(0, -24));
        await tester.pump();
        await gesture.moveTo(target);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('attachment-drop-marker')),
          findsOneWidget,
        );
        await gesture.up();
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('attachment-drop-marker')),
          findsNothing,
        );
      }

      await dragTo(15, PointerDeviceKind.touch);
      expect(
        notes.bodyController.document.toPlainText(),
        'First\nSecond\n\uFFFC\nThird\n',
      );
      await dragTo(0, PointerDeviceKind.mouse);
      expect(notes.bodyController.document.toDelta().toJson(), before);
      notes.bodyController.undo();
      await tester.pumpAndSettle();
      expect(
        notes.bodyController.document.toPlainText(),
        'First\nSecond\n\uFFFC\nThird\n',
      );
      expect(tester.takeException(), isNull);
      // Leaving the editor cancels without changing the document.
      final unchanged = notes.bodyController.document.toDelta().toJson();
      final cancelled = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('attachment-drag-drag'))),
      );
      await cancelled.moveBy(const Offset(0, -24));
      await tester.pump();
      await cancelled.moveTo(const Offset(-50, -50));
      await cancelled.up();
      await tester.pumpAndSettle();
      expect(notes.bodyController.document.toDelta().toJson(), unchanged);
      expect(
        find.byKey(const ValueKey('attachment-drop-marker')),
        findsNothing,
      );

      // A soft-wrapped line is also a drop position inside a paragraph.
      notes.bodyController.replaceText(
        15,
        5,
        List.filled(60, 'Wrapword ').join(),
        null,
      );
      await tester.pumpAndSettle();
      final wrappedText = notes.bodyController.document.toPlainText();
      final wrappedLine = editorKey.currentState!.renderEditor.getLineAtOffset(
        const TextPosition(offset: 170),
      );
      expect(wrappedLine.start, greaterThan(15));
      final withoutMedia = wrappedText.replaceRange(13, 15, '');
      final destination = wrappedLine.start - 2;
      await dragTo(170, PointerDeviceKind.touch);
      expect(
        notes.bodyController.document.toPlainText(),
        '${withoutMedia.substring(0, destination)}\n\uFFFC\n${withoutMedia.substring(destination)}',
      );
      notes.bodyController.undo();
      await tester.pumpAndSettle();
      expect(notes.bodyController.document.toPlainText(), wrappedText);

      // Long notes scroll while the pointer rests near the viewport edge.
      notes.bodyController.replaceText(
        notes.bodyController.document.length - 1,
        0,
        List.generate(50, (index) => '\nLine $index').join(),
        null,
      );
      await tester.pumpAndSettle();
      final longDocument = notes.bodyController.document.toDelta().toJson();
      final autoScroll = await tester.startGesture(
        tester.getCenter(find.byKey(const ValueKey('attachment-drag-drag'))),
      );
      await autoScroll.moveBy(const Offset(0, -24));
      await tester.pump();
      final viewport = tester.getRect(find.byType(NoteAttachmentDragLayer));
      await autoScroll.moveTo(Offset(viewport.left + 40, viewport.bottom - 10));
      await tester.pump();
      final startScroll = scroll.offset;
      await tester.pump(const Duration(milliseconds: 300));
      expect(scroll.offset, greaterThan(startScroll));
      await autoScroll.moveTo(const Offset(-50, -50));
      await autoScroll.up();
      await tester.pumpAndSettle();
      expect(notes.bodyController.document.toDelta().toJson(), longDocument);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
