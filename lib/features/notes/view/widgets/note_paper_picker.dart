import 'package:flutter/material.dart';
import '../../model/note_paper.dart';
import 'note_paper_surface.dart';

Future<NotePaper?> showNotePaperPicker(BuildContext context, NotePaper paper) =>
    showModalBottomSheet<NotePaper>(
      context: context,
      useRootNavigator: false,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (_) => NotePaperPicker(paper: paper),
    );

class NotePaperPicker extends StatefulWidget {
  const NotePaperPicker({super.key, required this.paper});
  final NotePaper paper;

  @override
  State<NotePaperPicker> createState() => _NotePaperPickerState();
}

class _NotePaperPickerState extends State<NotePaperPicker> {
  late NotePaper _paper = widget.paper;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final labelStyle = TextStyle(color: scheme.onSurface);
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.85,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Paper style',
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() => _paper = const NotePaper()),
                  child: const Text('Reset'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: NotePaperSurface(
                      key: const ValueKey('paper-live-preview'),
                      paper: _paper,
                      child: SizedBox(
                        width: double.infinity,
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: DefaultTextStyle(
                            style: TextStyle(
                              fontSize: 16,
                              height: 1.7,
                              color: NotePaperSurface.foregroundFor(
                                _paper.tone,
                                theme,
                              ),
                            ),
                            child: const Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'A little room to think',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 19,
                                  ),
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'A quiet canvas for your ideas.\nMake this space your own.',
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text('Pattern', style: labelStyle),
                  const SizedBox(height: 8),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns = constraints.maxWidth < 360 ? 2 : 3;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 8) / columns;
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          for (final pattern in NotePaperPattern.values)
                            SizedBox(
                              width: width,
                              child: Semantics(
                                selected: _paper.pattern == pattern,
                                child: OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.all(10),
                                    foregroundColor: scheme.onSurface,
                                    side: BorderSide(
                                      color: _paper.pattern == pattern
                                          ? scheme.primary
                                          : scheme.outlineVariant,
                                      width: _paper.pattern == pattern ? 2 : 1,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () => setState(
                                    () => _paper = _paper.copyWith(
                                      pattern: pattern,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      ExcludeSemantics(
                                        child: SizedBox(
                                          height: 42,
                                          width: double.infinity,
                                          child: NotePaperSurface(
                                            paper: _paper.copyWith(
                                              pattern: pattern,
                                            ),
                                            child: const SizedBox.expand(),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        pattern.label,
                                        textAlign: TextAlign.center,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 20),
                  Text('Paper tone', style: labelStyle),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final tone in NotePaperTone.values)
                        ChoiceChip(
                          label: Text(tone.label),
                          labelStyle: labelStyle,
                          avatar: CircleAvatar(
                            backgroundColor: NotePaperSurface.backgroundFor(
                              tone,
                              theme,
                            ),
                          ),
                          selected: _paper.tone == tone,
                          onSelected: (_) => setState(
                            () => _paper = _paper.copyWith(tone: tone),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Spacing · ${_paper.spacing.round()} px',
                    style: labelStyle,
                  ),
                  Slider(
                    key: const ValueKey('paper-spacing'),
                    value: _paper.spacing,
                    min: 16,
                    max: 48,
                    divisions: 16,
                    label: '${_paper.spacing.round()} px',
                    semanticFormatterCallback: (value) =>
                        '${value.round()} pixels',
                    onChanged: !_paper.pattern.hasSpacing
                        ? null
                        : (value) => setState(
                            () => _paper = _paper.copyWith(spacing: value),
                          ),
                  ),
                  Text(
                    'Intensity · ${(_paper.intensity * 100).round()}%',
                    style: labelStyle,
                  ),
                  Slider(
                    key: const ValueKey('paper-intensity'),
                    value: _paper.intensity,
                    min: 0.04,
                    max: 0.20,
                    divisions: 16,
                    label: '${(_paper.intensity * 100).round()}%',
                    semanticFormatterCallback: (value) =>
                        '${(value * 100).round()} percent',
                    onChanged: _paper.pattern == NotePaperPattern.plain
                        ? null
                        : (value) => setState(
                            () => _paper = _paper.copyWith(intensity: value),
                          ),
                  ),
                  Text(
                    'Applies to this note only. Text formatting and note-card color stay unchanged. Ruled lines are decorative; headings and lists keep their own spacing.',
                    style: TextStyle(
                      color: scheme.onSurfaceVariant,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: OverflowBar(
                spacing: 12,
                overflowSpacing: 8,
                alignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () => Navigator.pop(context, _paper),
                    child: const Text('Apply paper'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
