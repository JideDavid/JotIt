import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/core/theme/theme.dart';
import 'package:jot_it/features/notes/view/widgets/distressed_highlight.dart';
import 'package:jot_it/features/notes/view/widgets/note_ai_workspace.dart';

Future<Uint8List> _pixels(WidgetTester tester, {String? capture}) async {
  return (await tester.runAsync(() async {
    final boundary = tester.renderObject<RenderRepaintBoundary>(
      find.byKey(const ValueKey('highlight-preview')),
    );
    final image = await boundary.toImage();
    try {
      if (capture != null && const bool.fromEnvironment('JOTIT_UI_AUDIT')) {
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final directory = Directory('.dart_tool/ui-audit');
        await directory.create(recursive: true);
        await File(
          '${directory.path}/$capture.png',
        ).writeAsBytes(png!.buffer.asUint8List());
      }
      return (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }))!;
}

int _inkPixels(Uint8List pixels, Color color) {
  var count = 0;
  final argb = color.toARGB32();
  for (var i = 0; i < pixels.length; i += 4) {
    if (pixels[i] == (argb >> 16 & 255) &&
        pixels[i + 1] == (argb >> 8 & 255) &&
        pixels[i + 2] == (argb & 255)) {
      count++;
    }
  }
  return count;
}

void main() {
  testWidgets(
    'AI preview marker moves with text and disappears outside the viewport',
    (tester) async {
      final controller = QuillController(
        document: Document.fromJson([
          {
            'insert': 'Highlighted opening',
            'attributes': {'background': '#ff9800'},
          },
          {
            'insert':
                '\n${List.filled(50, 'Plain body text without highlights.').join('\n')}\n',
          },
        ]),
        selection: const TextSelection.collapsed(offset: 0),
        readOnly: true,
      );
      addTearDown(controller.dispose);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(
            body: Center(
              child: RepaintBoundary(
                key: const ValueKey('highlight-preview'),
                child: SizedBox(
                  width: 320,
                  height: 260,
                  child: NoteAiDocumentPreview(controller: controller),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        _inkPixels(await _pixels(tester), const Color(0xffff9800)),
        greaterThan(250),
      );
      final scrollable = find
          .descendant(
            of: find.byType(NoteAiDocumentPreview),
            matching: find.byType(Scrollable),
          )
          .first;
      final position = tester.state<ScrollableState>(scrollable).position;
      position.jumpTo(160);
      await tester.pumpAndSettle();
      expect(_inkPixels(await _pixels(tester), const Color(0xffff9800)), 0);
      position.jumpTo(0);
      await tester.pumpAndSettle();
      expect(
        _inkPixels(await _pixels(tester), const Color(0xffff9800)),
        greaterThan(250),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
  setUpAll(() async {
    const directory = String.fromEnvironment('JOTIT_AUDIT_FONTS');
    if (directory.isEmpty) return;
    final loader = FontLoader('MarkerAudit');
    for (final name in ['regular', 'bold', 'italic', 'bolditalic']) {
      loader.addFont(
        File(
          '$directory/roboto-$name.ttf',
        ).readAsBytes().then(ByteData.sublistView),
      );
    }
    await loader.load();
  });

  for (final dark in [false, true]) {
    testWidgets(
      'wrapped marker colors repaint and undo without changing text in ${dark ? 'dark' : 'light'}',
      (tester) async {
        tester.view.physicalSize = const Size(420, 640);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        const text =
            'Studying the Bible like a theologian means going beyond devotional '
            'reading. It involves understanding history, languages, context, '
            'theology, and interpretation methods.';
        final controller = QuillController(
          document: Document.fromJson([
            {
              'insert': text,
              'attributes': {
                'background': '#ff9800',
                'bold': true,
                'italic': true,
              },
            },
            {'insert': '\nKeep your thoughts, in your own words.\n'},
          ]),
          selection: const TextSelection.collapsed(offset: 0),
        );
        final scroll = ScrollController();
        final focus = FocusNode();
        addTearDown(controller.dispose);
        addTearDown(scroll.dispose);
        addTearDown(focus.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? LSTAppTheme.darkTheme : LSTAppTheme.lightTheme,
            localizationsDelegates: const [FlutterQuillLocalizations.delegate],
            home: Scaffold(
              body: RepaintBoundary(
                key: const ValueKey('highlight-preview'),
                child: Builder(
                  builder: (context) => ColoredBox(
                    color: Theme.of(context).scaffoldBackgroundColor,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                          child: Text(
                            'Studying the Bible',
                            style: TextStyle(
                              fontFamily: 'MarkerAudit',
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        Expanded(
                          child: DistressedHighlightLayer(
                            repaint: Listenable.merge([controller, scroll]),
                            child: QuillEditor.basic(
                              controller: controller,
                              scrollController: scroll,
                              focusNode: focus,
                              config: QuillEditorConfig(
                                expands: true,
                                padding: const EdgeInsets.all(24),
                                textSpanBuilder: distressedHighlightSpanBuilder,
                                customStyles: DefaultStyles(
                                  paragraph: DefaultTextBlockStyle(
                                    TextStyle(
                                      fontFamily: 'MarkerAudit',
                                      fontSize: 23,
                                      height: 1.5,
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.onSurface,
                                    ),
                                    HorizontalSpacing.zero,
                                    VerticalSpacing.zero,
                                    VerticalSpacing.zero,
                                    null,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final originalText = controller.document.toPlainText();
        final orange = await _pixels(
          tester,
          capture: 'distressed-highlight-${dark ? 'dark' : 'light'}',
        );
        expect(_inkPixels(orange, const Color(0xffff9800)), greaterThan(1000));
        // A selected run can wrap, and split styles must not change its content.
        expect(
          find.byType(RichText).evaluate().any((element) {
            final span = (element.widget as RichText).text;
            var found = false;
            span.visitChildren((child) {
              found |= child is DistressedHighlightSpan;
              return true;
            });
            return found;
          }),
          true,
        );
        controller.formatText(
          0,
          text.length,
          const BackgroundAttribute('#638ed2'),
        );
        await tester.pumpAndSettle();
        final blue = await _pixels(tester);
        expect(_inkPixels(blue, const Color(0xff638ed2)), greaterThan(1000));
        expect(_inkPixels(blue, const Color(0xffff9800)), 0);
        controller.undo();
        await tester.pumpAndSettle();
        expect(
          _inkPixels(await _pixels(tester), const Color(0xffff9800)),
          greaterThan(1000),
        );
        controller.redo();
        await tester.pumpAndSettle();
        expect(
          _inkPixels(await _pixels(tester), const Color(0xff638ed2)),
          greaterThan(1000),
        );
        controller.formatText(0, text.length, const BackgroundAttribute(null));
        await tester.pumpAndSettle();
        expect(_inkPixels(await _pixels(tester), const Color(0xff638ed2)), 0);
        expect(controller.document.toPlainText(), originalText);
        expect(tester.takeException(), isNull);
      },
    );
  }

  test(
    'marker texture has worn edges and stays fixed between paints',
    () async {
      Future<Uint8List> render(int seed) async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        paintDistressedMarker(
          canvas,
          const Rect.fromLTWH(12, 8, 180, 32),
          const Color(0xffff9800),
          seed: seed,
        );
        final picture = recorder.endRecording();
        final image = await picture.toImage(210, 50);
        try {
          return (await image.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          ))!.buffer.asUint8List();
        } finally {
          image.dispose();
          picture.dispose();
        }
      }

      final pixels = await render(42);
      expect(await render(42), orderedEquals(pixels));
      expect(await render(43), isNot(orderedEquals(pixels)));
      final topEdge = <int>[];
      final center = <int>[];
      for (var x = 20; x < 180; x++) {
        topEdge.add(pixels[(12 * 210 + x) * 4 + 3]);
        center.add(pixels[(24 * 210 + x) * 4 + 3]);
      }
      expect(topEdge.toSet().length, greaterThan(2));
      expect(center.where((alpha) => alpha == 255).length, greaterThan(150));
      // The two ends have ink beyond the text bounds (x=12 through x=192).
      expect(pixels[(24 * 210 + 5) * 4 + 3], greaterThan(0));
      expect(pixels[(24 * 210 + 199) * 4 + 3], greaterThan(0));
    },
  );

  testWidgets('RTL marker spans follow scrolling and respect the viewport', (
    tester,
  ) async {
    final scroll = ScrollController();
    addTearDown(scroll.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: RepaintBoundary(
              key: const ValueKey('highlight-preview'),
              child: SizedBox(
                width: 300,
                height: 120,
                child: DistressedHighlightLayer(
                  repaint: scroll,
                  child: SingleChildScrollView(
                    controller: scroll,
                    child: Column(
                      children: [
                        const SizedBox(height: 160),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: RichText(
                            textDirection: TextDirection.rtl,
                            text: const TextSpan(
                              style: TextStyle(fontSize: 22, height: 1.5),
                              children: [
                                DistressedHighlightSpan(
                                  ink: Color(0xffff9800),
                                  text: 'نص مميز ',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                                DistressedHighlightSpan(
                                  ink: Color(0xffff9800),
                                  text: 'بأثر الفرشاة',
                                  style: TextStyle(fontStyle: FontStyle.italic),
                                ),
                                TextSpan(text: ' عادي'),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 160),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(_inkPixels(await _pixels(tester), const Color(0xffff9800)), 0);
    scroll.jumpTo(120);
    await tester.pumpAndSettle();
    expect(
      _inkPixels(await _pixels(tester), const Color(0xffff9800)),
      greaterThan(250),
    );
    scroll.jumpTo(0);
    await tester.pumpAndSettle();
    expect(_inkPixels(await _pixels(tester), const Color(0xffff9800)), 0);
    expect(tester.takeException(), isNull);
  });
}
