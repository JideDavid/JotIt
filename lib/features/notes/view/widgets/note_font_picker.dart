import 'package:flutter/material.dart';

import '../../model/note_font.dart';

Future<String?> showNoteFontPicker(
  BuildContext context, {
  required String? family,
  required String preview,
  required bool bold,
  required bool italic,
}) => showModalBottomSheet<String>(
  context: context,
  useRootNavigator: false,
  isScrollControlled: true,
  useSafeArea: true,
  showDragHandle: true,
  constraints: const BoxConstraints(maxWidth: 640),
  builder: (_) => _NoteFontPicker(
    family: family ?? '',
    preview: preview.trim().isEmpty ? 'Make a little magic.' : preview,
    bold: bold,
    italic: italic,
  ),
);

class _NoteFontPicker extends StatefulWidget {
  const _NoteFontPicker({
    required this.family,
    required this.preview,
    required this.bold,
    required this.italic,
  });
  final String family;
  final String preview;
  final bool bold;
  final bool italic;

  @override
  State<_NoteFontPicker> createState() => _NoteFontPickerState();
}

class _NoteFontPickerState extends State<_NoteFontPicker> {
  late String _family = widget.family;
  String _category = 'All';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final fonts = NoteFonts.families
        .where((font) => _category == 'All' || font.category == _category)
        .toList();
    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.9,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: Text('Fonts', style: theme.textTheme.headlineSmall),
                ),
                TextButton(
                  onPressed: () => setState(() => _family = ''),
                  child: const Text('Use default'),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('font-picker-scroll'),
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Give your words a little personality.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Container(
                    key: const ValueKey('font-live-preview'),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _family.isEmpty ? 'Default font' : _family,
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.preview,
                          key: const ValueKey('font-preview-text'),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: _family.isEmpty ? null : _family,
                            fontSize: 30,
                            height: 1.3,
                            fontWeight: widget.bold
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontStyle: widget.italic
                                ? FontStyle.italic
                                : FontStyle.normal,
                            color: scheme.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final category in const [
                          'All',
                          'Display',
                          'Sans serif',
                          'Serif',
                          'Handwriting',
                        ])
                          Padding(
                            padding: const EdgeInsetsDirectional.only(end: 8),
                            child: FilterChip(
                              label: Text(category),
                              selected: _category == category,
                              onSelected: (_) =>
                                  setState(() => _category = category),
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final columns =
                          constraints.maxWidth >= 440 &&
                              MediaQuery.textScalerOf(context).scale(14) <= 20
                          ? 2
                          : 1;
                      final width =
                          (constraints.maxWidth - (columns - 1) * 10) / columns;
                      return Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (final font in fonts)
                            SizedBox(
                              width: width,
                              child: Semantics(
                                button: true,
                                selected: _family == font.family,
                                label: '${font.family}, ${font.category}',
                                child: Material(
                                  color: _family == font.family
                                      ? scheme.primaryContainer
                                      : scheme.surface,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                    side: BorderSide(
                                      color: _family == font.family
                                          ? scheme.primary
                                          : scheme.outlineVariant,
                                      width: _family == font.family ? 2 : 1,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: InkWell(
                                    key: ValueKey(
                                      'font-choice-${font.sourceSlug}',
                                    ),
                                    onTap: () =>
                                        setState(() => _family = font.family),
                                    child: Padding(
                                      padding: const EdgeInsets.all(16),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Row(
                                            children: [
                                              Expanded(
                                                child: Text(
                                                  font.category,
                                                  style: theme
                                                      .textTheme
                                                      .labelSmall
                                                      ?.copyWith(
                                                        color: scheme
                                                            .onSurfaceVariant,
                                                      ),
                                                ),
                                              ),
                                              if (_family == font.family)
                                                Icon(
                                                  Icons.check_circle,
                                                  size: 18,
                                                  color: scheme.primary,
                                                ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            font.family,
                                            style: TextStyle(
                                              fontFamily: font.family,
                                              fontSize: 26,
                                              height: 1.2,
                                              color: scheme.onSurface,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            font.description,
                                            style: theme.textTheme.bodySmall,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Google Fonts · available offline',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
              child: Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.pop(context, _family),
                      child: const Text(
                        'Apply font',
                        textAlign: TextAlign.center,
                      ),
                    ),
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
