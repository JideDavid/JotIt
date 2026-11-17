import 'dart:async';
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/model/note.dart';
import 'package:jot_it/features/notes/model/note_link.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:jot_it/features/notes/view-model/note_view_model.dart';
import 'support/fakes.dart';

void main() {
  late MemoryStorage storage;
  late NoteViewModel viewModel;

  setUp(() {
    storage = MemoryStorage();
    viewModel = NoteViewModel(
      notesRepo: NotesRepo(localStorageService: storage),
    );
  });
  tearDown(() => viewModel.dispose());

  test(
    'legacy plain-text notes preserve paragraphs and trailing newlines',
    () async {
      final note = makeNote(
        'old',
        body: 'First paragraph\n\nSecond paragraph\n',
      );
      storage.notes = [note];
      await viewModel.getNotesFromLocalStorage();
      viewModel.setOpenedNote(note);
      expect(viewModel.bodyText, note.body);
      expect(viewModel.hasUnsavedChanges, false);
      expect(await viewModel.saveNote(), true);
      expect(storage.saveCalls, 0);
      viewModel.selectColor(1);
      expect(await viewModel.saveNote(), true);
      expect(storage.notes.single.body, note.body);
      expect(storage.notes.single.richText, isNotNull);
    },
  );

  test(
    'inline styles, colors, highlight, and links survive save and reopen',
    () async {
      setBodyText(viewModel.bodyController, 'Styled text');
      viewModel.bodyController.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 6),
        ChangeSource.local,
      );
      for (final attribute in <Attribute>[
        Attribute.bold,
        Attribute.italic,
        Attribute.underline,
        Attribute.strikeThrough,
        const ColorAttribute('#ef5350'),
        const BackgroundAttribute('#ffeb3b'),
        const LinkAttribute('https://example.com'),
      ]) {
        viewModel.bodyController.formatSelection(attribute);
      }
      expect(await viewModel.saveNote(), true);
      final saved = storage.notes.single;
      expect(saved.body, 'Styled text');
      final attributes =
          (jsonDecode(saved.richText!) as List).first['attributes'];
      expect(attributes, containsPair('bold', true));
      expect(attributes, containsPair('italic', true));
      expect(attributes, containsPair('underline', true));
      expect(attributes, containsPair('strike', true));
      expect(attributes, containsPair('color', '#ef5350'));
      expect(attributes, containsPair('background', '#ffeb3b'));
      expect(attributes, containsPair('link', 'https://example.com'));
      viewModel.setOpenedNote(saved);
      expect(viewModel.bodyText, 'Styled text');
      expect(
        viewModel.bodyController.document.toDelta().toJson(),
        jsonDecode(saved.richText!),
      );
      expect(viewModel.hasUnsavedChanges, false);
    },
  );

  test(
    'formatting-only changes are dirty and undo returns to the saved document',
    () {
      viewModel.setOpenedNote(makeNote('plain', body: 'Text'));
      viewModel.bodyController.updateSelection(
        const TextSelection(baseOffset: 0, extentOffset: 4),
        ChangeSource.local,
      );
      viewModel.bodyController.formatSelection(Attribute.bold);
      expect(viewModel.hasUnsavedChanges, true);
      expect(viewModel.bodyText, 'Text');
      viewModel.bodyController.undo();
      expect(viewModel.hasUnsavedChanges, false);
      viewModel.bodyController.redo();
      expect(viewModel.hasUnsavedChanges, true);
    },
  );

  test(
    'headings, lists, and checklists are stored as paragraph formatting',
    () async {
      setBodyText(viewModel.bodyController, 'Heading\nBullet\nNumbered\nTask');
      final controller = viewModel.bodyController;
      controller.formatText(0, 7, Attribute.h1);
      controller.formatText(8, 6, Attribute.ul);
      controller.formatText(15, 8, Attribute.ol);
      controller.formatText(24, 4, Attribute.unchecked);
      expect(await viewModel.saveNote(), true);
      final operations = jsonDecode(storage.notes.single.richText!) as List;
      expect(
        operations.where(
          (operation) => operation['attributes']?['header'] == 1,
        ),
        isNotEmpty,
      );
      expect(
        operations.where(
          (operation) => operation['attributes']?['list'] == 'bullet',
        ),
        isNotEmpty,
      );
      expect(
        operations.where(
          (operation) => operation['attributes']?['list'] == 'ordered',
        ),
        isNotEmpty,
      );
      expect(
        operations.where(
          (operation) => operation['attributes']?['list'] == 'unchecked',
        ),
        isNotEmpty,
      );
      viewModel.setOpenedNote(storage.notes.single);
      expect(viewModel.bodyText, 'Heading\nBullet\nNumbered\nTask');
    },
  );

  test(
    'search uses visible text rather than serialized formatting attributes',
    () async {
      setBodyText(viewModel.bodyController, 'My shopping list');
      viewModel.bodyController.formatText(0, 2, Attribute.bold);
      await viewModel.saveNote();
      viewModel.searchController.text = 'shopping';
      expect(viewModel.visibleNotes, hasLength(1));
      viewModel.searchController.text = 'bold';
      expect(viewModel.visibleNotes, isEmpty);
    },
  );

  test(
    'failed saves retain rich formatting and preserve the saved version',
    () async {
      final original = makeNote('original', body: 'Keep me');
      storage.notes = [original];
      await viewModel.getNotesFromLocalStorage();
      viewModel.setOpenedNote(original);
      viewModel.bodyController.formatText(0, 4, Attribute.underline);
      storage.failWrites = true;
      expect(await viewModel.saveNote(), false);
      expect(storage.notes.single.richText, isNull);
      expect(viewModel.hasUnsavedChanges, true);
      storage.failWrites = false;
      expect(await viewModel.saveNote(), true);
      expect(storage.notes.single.richText, contains('underline'));
    },
  );

  test(
    'formatting applied during a pending save remains dirty afterward',
    () async {
      setBodyText(viewModel.bodyController, 'Draft');
      storage.writeBarrier = Completer<void>();
      final saving = viewModel.saveNote();
      viewModel.bodyController.formatText(0, 5, Attribute.bold);
      storage.writeBarrier!.complete();
      expect(await saving, true);
      expect(viewModel.hasUnsavedChanges, true);
      expect(await viewModel.saveNote(), true);
      expect(storage.notes.single.richText, contains('bold'));
    },
  );

  test(
    'opening a different note clears undo history and pending typing styles',
    () {
      setBodyText(viewModel.bodyController, 'Previous note');
      viewModel.bodyController.formatSelection(Attribute.bold);
      viewModel.setOpenedNote(makeNote('next', body: 'Next note'));
      expect(viewModel.bodyController.hasUndo, false);
      expect(
        viewModel.bodyController.getSelectionStyle().attributes['bold'],
        isNull,
      );
      expect(viewModel.bodyText, 'Next note');
      expect(viewModel.hasUnsavedChanges, false);
    },
  );

  test('malformed rich text falls back to the original plain text', () {
    viewModel.setOpenedNote(
      makeNote('damaged', body: 'Preserved text', richText: '{broken'),
    );
    expect(viewModel.bodyText, 'Preserved text');
    expect(viewModel.hasUnsavedChanges, false);
  });

  test(
    'note JSON round-trips rich text and accepts older plain-text payloads',
    () {
      final original = makeNote(
        'json',
        body: 'Hello',
        richText: '[{"insert":"Hello\\n"}]',
      );
      final decoded = Note.fromJson(original.toJson());
      expect(decoded.richText, original.richText);
      expect(decoded.body, original.body);
      final legacy = Note.fromJson({'id': 'old', 'body': 'Plain text'});
      expect(legacy.richText, isNull);
      expect(legacy.color, 0);
    },
  );

  test(
    'website links normalize and unsafe or malformed links are rejected',
    () {
      expect(parseNoteLink('example.com')?.toString(), 'https://example.com');
      expect(
        parseNoteLink(' https://example.com/path?q=1 ')?.host,
        'example.com',
      );
      expect(parseNoteLink('mailto:hello@example.com')?.scheme, 'mailto');
      for (final link in [
        '',
        'not a link',
        'javascript:alert(1)',
        'data:text/html,test',
        'file:///etc/passwd',
        'https://',
        'mailto:invalid',
      ]) {
        expect(parseNoteLink(link), isNull, reason: link);
      }
    },
  );
}
