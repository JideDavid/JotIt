import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class NoteHistoryControls extends StatelessWidget {
  const NoteHistoryControls({
    super.key,
    required this.controller,
    required this.focusNode,
  });

  final QuillController controller;
  final FocusNode focusNode;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Material(
        key: const ValueKey('note-history-controls'),
        color: scheme.surfaceContainer,
        elevation: 4,
        shadowColor: Colors.black26,
        shape: StadiumBorder(side: BorderSide(color: scheme.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: 'Undo',
                onPressed: controller.hasUndo
                    ? () {
                        controller.undo();
                        focusNode.requestFocus();
                      }
                    : null,
                icon: const Icon(Icons.undo),
              ),
              SizedBox(
                height: 20,
                child: VerticalDivider(width: 1, color: scheme.outlineVariant),
              ),
              IconButton(
                tooltip: 'Redo',
                onPressed: controller.hasRedo
                    ? () {
                        controller.redo();
                        focusNode.requestFocus();
                      }
                    : null,
                icon: const Icon(Icons.redo),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
