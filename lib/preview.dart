import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';

import 'core/services/google_auth_service.dart';
import 'core/services/hive_local_storage_service.dart';
import 'core/services/internet_checker_service.dart';
import 'core/services/local_biometric_service.dart';
import 'core/theme/appearance_view_model.dart';
import 'features/auth/repository/auth_repository.dart';
import 'features/auth/view_model/auth_viewmodel.dart';
import 'features/notes/model/note.dart';
import 'features/notes/model/note_font.dart';
import 'features/notes/model/note_attachment.dart';
import 'features/notes/model/note_paper.dart';
import 'features/notes/services/note_media_controller.dart';
import 'features/notes/repository/notes_repo.dart';
import 'features/notes/view-model/note_view_model.dart';
import 'main.dart' show MyApp;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NoteFonts.registerLicenses();
  await Hive.initFlutter();
  Hive.registerAdapter(NoteAdapter());
  final authBox = await Hive.openBox('jotit_preview_auth');
  final noteBox = await Hive.openBox('jotit_preview_notes');
  final storage = HiveLocalStorageService(authBox, noteBox);
  final appearance = AppearanceViewModel(storage);
  await appearance.initialize();
  if (!noteBox.containsKey('all')) {
    await storage.saveNotes([
      await _mediaSampleNote(),
      _sampleNote('preview-welcome', 'Welcome to rich-text notes', 0, [
        {'insert': 'Make your ideas stand out'},
        {
          'insert': '\n',
          'attributes': {'header': 1},
        },
        {'insert': 'Try '},
        {
          'insert': 'bold',
          'attributes': {'bold': true},
        },
        {'insert': ', '},
        {
          'insert': 'italic',
          'attributes': {'italic': true},
        },
        {'insert': ', '},
        {
          'insert': 'underlined',
          'attributes': {'underline': true},
        },
        {'insert': ', and '},
        {
          'insert': 'strikethrough',
          'attributes': {'strike': true},
        },
        {'insert': ' text.\n\n'},
        {
          'insert': 'Highlight what matters.',
          'attributes': {'background': '#ffeb3b', 'color': '#000000'},
        },
        {'insert': '\n'},
        {
          'insert': 'Add a splash of color.',
          'attributes': {'color': '#42a5f5'},
        },
        {'insert': '\n\n'},
        {
          'insert': 'Visit a sample link',
          'attributes': {'link': 'https://example.com'},
        },
        {
          'insert':
              '\n\nSelect text, then swipe the bottom toolbar for headings, lists, quotes, and more. Undo and redo sit just above it. Use the paperclip to add images, audio, or a voice note.\n',
        },
      ]),
      _sampleNote('preview-checklist', 'A little checklist', 4, [
        {'insert': 'Explore the editor'},
        {
          'insert': '\n',
          'attributes': {'list': 'checked'},
        },
        {'insert': 'Create your first note'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
        {'insert': 'Try a heading or quote'},
        {
          'insert': '\n',
          'attributes': {'list': 'unchecked'},
        },
      ]),
    ], 'all');
  }
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: appearance),
        ChangeNotifierProvider(create: (_) => InternetCheckerService()),
        ChangeNotifierProvider(
          create: (context) => AuthViewModel(
            authRepository: AuthRepository(
              authService: const GoogleAuthService.unavailable(
                'Google sign-in is unavailable in this sample preview. Use the configured Android app to connect your account.',
              ),
              localStorageService: storage,
            ),
            localBiometricService: LocalBiometricService(),
            internetCheckerService: context.read<InternetCheckerService>(),
          ),
        ),
        ChangeNotifierProvider(
          create: (_) =>
              NoteViewModel(notesRepo: NotesRepo(localStorageService: storage)),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

Future<Note> _mediaSampleNote() async {
  final image = await rootBundle.load('assets/images/empty_list.png');
  final attachments = [
    NoteAttachment(
      id: 'preview-image',
      name: 'Sample illustration.png',
      mimeType: 'image/png',
      bytes: image.buffer.asUint8List(image.offsetInBytes, image.lengthInBytes),
    ),
    NoteAttachment(
      id: 'preview-audio',
      name: 'Silent audio example.wav',
      mimeType: 'audio/wav',
      bytes: NoteMediaController.wavFromPcm(Uint8List(32000)),
    ),
  ];
  final sample = _sampleNote('preview-media', 'Inline media example', 3, [
    {'insert': 'Keep images and audio with the thought they belong to.\n'},
    {
      'insert': {NoteAttachment.embedType: 'preview-image'},
    },
    {
      'insert':
          '\nAdd an audio file or record a voice note with the paperclip.\n',
    },
    {
      'insert': {NoteAttachment.embedType: 'preview-audio'},
    },
    {'insert': '\nThis demo audio is one second of silence.\n'},
  ]);
  return Note(
    id: sample.id,
    title: sample.title,
    body: sample.body.replaceAll('\uFFFC', ''),
    richText: sample.richText,
    color: sample.color,
    timestamp: sample.timestamp,
    isLocked: false,
    paper: const NotePaper(pattern: NotePaperPattern.dots).encode(),
    media: NoteAttachment.encodeAll(attachments),
  );
}

Note _sampleNote(
  String id,
  String title,
  int color,
  List<Map<String, Object>> delta,
) {
  final document = Document.fromJson(delta);
  final text = document.toPlainText();
  document.close();
  return Note(
    id: id,
    title: title,
    body: text.substring(0, text.length - 1),
    richText: jsonEncode(delta),
    timestamp: DateTime.now(),
    color: color,
    isLocked: false,
  );
}
