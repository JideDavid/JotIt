import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/model/note_sticker.dart';
import 'package:jot_it/features/notes/model/note_text_style.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/services/note_document_edits.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'package:jot_it/features/notes/view/widgets/note_stickers.dart';
import 'package:jot_it/features/notes/view/widgets/note_style_library.dart';
import 'support/fakes.dart';

void main() {
  testWidgets(
    'hold-and-drag inserts a catalog sticker at the actual text line',
    (tester) async {
      final notes = NoteViewModel(
        notesRepo: NotesRepo(localStorageService: MemoryStorage()),
      );
      final focus = FocusNode(),
          scroll = ScrollController(),
          key = GlobalKey<EditorState>();
      addTearDown(notes.dispose);
      addTearDown(focus.dispose);
      addTearDown(scroll.dispose);
      setBodyText(notes.bodyController, 'First line\nSecond line\nThird line');
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: NoteStickerLayer(
                    notes: notes,
                    editorKey: key,
                    scrollController: scroll,
                    child: QuillEditor.basic(
                      controller: notes.bodyController,
                      focusNode: focus,
                      scrollController: scroll,
                      config: QuillEditorConfig(
                        editorKey: key,
                        expands: true,
                        padding: const EdgeInsets.all(24),
                        embedBuilders: [NoteStickerEmbedBuilder(notes)],
                      ),
                    ),
                  ),
                ),
                NoteStickerTray(
                  notes: notes,
                  selection: const TextSelection.collapsed(offset: 0),
                  onClose: () {},
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final editor = key.currentState!.renderEditor;
      final point = editor.localToGlobal(
        editor.getLocalRectForCaret(const TextPosition(offset: 13)).center,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(find.text('Pinned paper')),
      );
      await tester.pump(const Duration(milliseconds: 600));
      await gesture.moveTo(point);
      await tester.pump(const Duration(milliseconds: 50));
      await gesture.up();
      await tester.pumpAndSettle();
      expect(notes.stickers.length, 1);
      expect(notes.stickers.single.offset, greaterThanOrEqualTo(11));
      expect(notes.stickers.single.offset, lessThan(23));
      notes.bodyController.undo();
      expect(notes.stickers, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  test(
    'catalog entries describe distinct visuals and colors belong to instances',
    () {
      expect(StickerCatalog.formats.map((f) => f.id).toSet().length, 17);
      expect(StickerCatalog.formats.map((f) => f.visual).toSet().length, 17);
      final sticker = NoteSticker(
        id: 'one',
        formatId: 'pinned-paper',
        text: 'Keep this',
        color: 0xff6da783,
        free: true,
        x: .7,
        dy: 80,
      );
      final decoded = NoteSticker.decode(sticker.encode())!;
      expect(decoded.toJson(), sticker.toJson());
      expect(decoded.copyWith(color: 0xff688ece).formatId, decoded.formatId);
      expect(NoteSticker.decode('{invalid'), isNull);
      expect(
        NoteSticker.decode(
          jsonEncode({'version': 99, 'id': 'future', 'format': 'new'}),
        ),
        isNull,
      );
    },
  );

  test(
    'a text style preserves text and surrounding formatting, with one undo',
    () {
      final c = QuillController.basic();
      addTearDown(c.dispose);
      setBodyText(c, 'Before chosen after');
      c.formatText(0, 6, Attribute.bold);
      final original = c.document.toDelta().toJson();
      NoteTextStyles.apply(
        c,
        NoteTextStyles.find('amber-brush')!,
        const TextSelection(baseOffset: 7, extentOffset: 13),
      );
      expect(c.document.toPlainText(), 'Before chosen after\n');
      expect(
        c.document.collectStyle(7, 6).attributes['background']?.value,
        '#ffb52e',
      );
      expect(c.document.collectStyle(0, 6).attributes['background'], isNull);
      c.undo();
      expect(c.document.toDelta().toJson(), original);
      c.redo();
      expect(
        c.document.collectStyle(7, 6).attributes['background']?.value,
        '#ffb52e',
      );
      expect(NoteTextStyles.presets.length, 36);
    },
  );

  test(
    'stickers save, reopen, move, recolor and delete using document undo',
    () async {
      final storage = MemoryStorage();
      final notes = NoteViewModel(
        notesRepo: NotesRepo(localStorageService: storage),
      );
      addTearDown(notes.dispose);
      setBodyText(notes.bodyController, 'one two');
      notes.insertSticker(
        StickerCatalog.find('pinned-paper')!,
        selection: const TextSelection.collapsed(offset: 4),
      );
      expect(notes.bodyController.document.toPlainText(), 'one \uFFFCtwo\n');
      expect(await notes.saveNote(), isTrue);
      final saved = storage.notes.single;
      notes.setOpenedNote(saved);
      var placed = notes.stickers.single;
      final original = notes.bodyController.document.toDelta().toJson();
      expect(
        notes.moveSticker(
          placed.sticker.id,
          0,
          placed.sticker.copyWith(free: true, x: .8, dy: 100),
        ),
        isTrue,
      );
      expect(notes.stickers.single.sticker.free, isTrue);
      notes.bodyController.undo();
      expect(notes.bodyController.document.toDelta().toJson(), original);
      placed = notes.stickers.single;
      notes.updateSticker(
        placed.sticker.id,
        placed.sticker.copyWith(color: 0xff688ece, text: 'Edited'),
      );
      expect(notes.stickers.single.sticker.text, 'Edited');
      notes.bodyController.undo();
      expect(notes.bodyController.document.toDelta().toJson(), original);
      notes.updateSticker(placed.sticker.id, null);
      expect(notes.stickers, isEmpty);
      notes.bodyController.undo();
      expect(notes.stickers.single.sticker.id, placed.sticker.id);
      expect(
        NoteDocumentEdits.stickers(
          Document.fromJson(jsonDecode(saved.richText!) as List),
        ).length,
        1,
      );
    },
  );

  test(
    'a doodle-only note is savable and saved style favorites persist',
    () async {
      final storage = MemoryStorage();
      final repo = NotesRepo(localStorageService: storage);
      final notes = NoteViewModel(notesRepo: repo);
      addTearDown(notes.dispose);
      expect(notes.insertSticker(StickerCatalog.find('star')!), isTrue);
      expect(notes.hasUnsavedChanges, isTrue);
      expect(await notes.saveNote(), isTrue);
      expect(storage.notes.single.richText, contains('jot-sticker'));
      expect(await notes.toggleSavedTextStyle('handwritten'), isTrue);
      final restored = NoteViewModel(notesRepo: repo);
      addTearDown(restored.dispose);
      expect(restored.savedTextStyles, ['handwritten']);
    },
  );

  testWidgets('style and sticker palettes fit a 320px phone', (tester) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final notes = NoteViewModel(
      notesRepo: NotesRepo(localStorageService: MemoryStorage()),
    );
    addTearDown(notes.dispose);
    for (final palette in <Widget>[
      NoteStylePalette(
        notes: notes,
        hasSelection: true,
        onChoose: (_) {},
        onBrowse: () {},
        onClose: () {},
      ),
      NoteStickerTray(
        notes: notes,
        selection: const TextSelection.collapsed(offset: 0),
        onClose: () {},
      ),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Align(alignment: Alignment.bottomCenter, child: palette),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('inline and free stickers render without altering note text', (
    tester,
  ) async {
    final notes = NoteViewModel(
      notesRepo: NotesRepo(localStorageService: MemoryStorage()),
    );
    final focus = FocusNode(), scroll = ScrollController();
    final editorKey = GlobalKey<EditorState>();
    addTearDown(notes.dispose);
    addTearDown(focus.dispose);
    addTearDown(scroll.dispose);
    setBodyText(notes.bodyController, 'Before after');
    notes.insertSticker(
      StickerCatalog.find('pinned-paper')!,
      selection: const TextSelection.collapsed(offset: 7),
    );
    notes.insertSticker(
      StickerCatalog.find('star')!,
      selection: const TextSelection.collapsed(offset: 0),
      free: true,
    );
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [FlutterQuillLocalizations.delegate],
        home: Scaffold(
          body: NoteStickerLayer(
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
                embedBuilders: [NoteStickerEmbedBuilder(notes)],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byType(NoteStickerVisual), findsNWidgets(2));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
