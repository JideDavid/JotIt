import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jot_it/features/notes/view/widgets/rich_text_toolbar.dart';

void main() {
  for (final device in [PointerDeviceKind.touch, PointerDeviceKind.mouse]) {
    testWidgets('format rail scrolls with ${device.name} at phone width', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final controller = QuillController.basic();
      final focus = FocusNode();
      addTearDown(controller.dispose);
      addTearDown(focus.dispose);
      controller.replaceText(
        0,
        0,
        'Selected words',
        const TextSelection(baseOffset: 0, extentOffset: 8),
      );
      controller.formatSelection(Attribute.bold);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [FlutterQuillLocalizations.delegate],
          home: Scaffold(
            body: Column(
              children: [
                Expanded(
                  child: QuillEditor.basic(
                    controller: controller,
                    focusNode: focus,
                  ),
                ),
                RichTextToolbar(controller: controller, focusNode: focus),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('More formatting'), findsNothing);
      final strip = find.byKey(const ValueKey('formatting-scroll-strip'));
      final scroll = tester.widget<SingleChildScrollView>(strip).controller!;
      final selection = controller.selection;
      final content = controller.document.toDelta().toJson();
      expect(
        tester
            .widget<IconButton>(
              find.widgetWithIcon(IconButton, Icons.chevron_right),
            )
            .onPressed,
        isNotNull,
      );
      final gesture = await tester.startGesture(
        tester.getCenter(strip),
        kind: device,
      );
      await gesture.moveBy(const Offset(-24, 0));
      await tester.pump();
      await gesture.moveBy(const Offset(-120, 0));
      await tester.pump();
      await gesture.up();
      await tester.pumpAndSettle();
      expect(scroll.offset, greaterThan(0));
      expect(controller.selection, selection);
      expect(controller.document.toDelta().toJson(), content);
      for (var page = 0; page < 10; page++) {
        if (tester
                .widget<IconButton>(
                  find.widgetWithIcon(IconButton, Icons.chevron_right),
                )
                .onPressed ==
            null) {
          break;
        }
        await tester.tap(find.byTooltip('Next formatting tools'));
        await tester.pumpAndSettle();
      }
      expect(find.byTooltip('Clear formatting').hitTestable(), findsOneWidget);
      await tester.tap(find.byTooltip('Clear formatting'));
      await tester.pumpAndSettle();
      expect(controller.getSelectionStyle().attributes['bold'], isNull);
      expect(controller.document.toPlainText(), 'Selected words\n');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final rail = find.byKey(const ValueKey('formatting-toolbar'));
      expect(tester.getSize(rail).height, 48);
      expect(tester.getBottomLeft(rail).dy, lessThanOrEqualTo(340));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    });
  }
}
