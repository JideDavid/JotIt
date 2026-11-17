import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import '../../model/note_link.dart';
import 'note_font_picker.dart';

class RichTextToolbar extends StatelessWidget {
  const RichTextToolbar({
    super.key,
    required this.controller,
    required this.focusNode,
    this.onStyles,
    this.onStickers,
    this.onAi,
  });
  final QuillController controller;
  final FocusNode focusNode;
  final VoidCallback? onStyles, onStickers, onAi;

  void _format(Attribute attribute) {
    controller.formatSelection(attribute);
    focusNode.requestFocus();
  }

  Widget _toggle(
    BuildContext context,
    String label,
    IconData icon,
    Attribute attribute,
  ) {
    final current = controller.getSelectionStyle().attributes[attribute.key];
    final selected =
        current?.value == attribute.value ||
        (attribute == Attribute.unchecked && current?.value == 'checked');
    return IconButton(
      tooltip: label,
      icon: Icon(icon),
      isSelected: selected,
      style: IconButton.styleFrom(
        backgroundColor: selected
            ? Theme.of(context).colorScheme.primaryContainer
            : null,
      ),
      onPressed: () =>
          _format(selected ? Attribute.clone(attribute, null) : attribute),
    );
  }

  Future<void> _pickColor(
    BuildContext context, {
    required bool highlight,
  }) async {
    final selection = controller.selection;
    final color = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (context) => _ColorDialog(
        highlight: highlight,
        selected:
            controller
                    .getSelectionStyle()
                    .attributes[highlight
                        ? Attribute.background.key
                        : Attribute.color.key]
                    ?.value
                as String?,
      ),
    );
    if (!context.mounted || color == null) return;
    controller.updateSelection(selection, ChangeSource.local);
    _format(
      highlight
          ? BackgroundAttribute(color.isEmpty ? null : color)
          : ColorAttribute(color.isEmpty ? null : color),
    );
  }

  Future<void> _editLink(BuildContext context) async {
    final selection = controller.selection;
    var range = TextRange(start: selection.start, end: selection.end);
    final currentLink =
        controller.getSelectionStyle().attributes[Attribute.link.key]?.value
            as String?;
    final leaf = controller.document.querySegmentLeafNode(selection.start).leaf;
    if (currentLink != null && leaf != null) range = getLinkRange(leaf);
    final selectedText = controller.document.getPlainText(
      range.start,
      range.end - range.start,
    );
    final result = await showDialog<_NoteLink>(
      context: context,
      useRootNavigator: false,
      builder: (_) => _LinkDialog(text: selectedText, url: currentLink),
    );
    if (!context.mounted || result == null) return;
    controller.updateSelection(selection, ChangeSource.local);
    if (result.url == null) {
      controller.formatText(
        range.start,
        range.end - range.start,
        const LinkAttribute(null),
      );
    } else {
      if (result.text != selectedText) {
        controller.replaceText(
          range.start,
          range.end - range.start,
          result.text,
          null,
        );
      }
      controller.formatText(
        range.start,
        result.text.length,
        LinkAttribute(result.url),
      );
      controller.updateSelection(
        TextSelection.collapsed(offset: range.start + result.text.length),
        ChangeSource.local,
      );
    }
    focusNode.requestFocus();
  }

  void _clearFormatting() {
    final attributes = <Attribute>{};
    for (final style in controller.getAllSelectionStyles()) {
      attributes.addAll(style.attributes.values);
    }
    for (final attribute in attributes) {
      controller.formatSelection(Attribute.clone(attribute, null));
    }
    focusNode.requestFocus();
  }

  Future<void> _pickHeading(BuildContext context) => _chooseValue<int>(
    context,
    'Headings',
    const [
      (0, 'Body text'),
      (1, 'Heading 1'),
      (2, 'Heading 2'),
      (3, 'Heading 3'),
    ],
    controller.getSelectionStyle().attributes[Attribute.header.key]?.value
            as int? ??
        0,
    (level) => _format(HeaderAttribute(level: level == 0 ? null : level)),
  );

  Future<void> _pickFontSize(BuildContext context) => _chooseValue<String>(
    context,
    'Font size',
    const [
      ('', 'Default size'),
      ('14', 'Small — 14'),
      ('18', 'Regular — 18'),
      ('24', 'Large — 24'),
      ('32', 'Extra large — 32'),
    ],
    controller
            .getSelectionStyle()
            .attributes[Attribute.size.key]
            ?.value
            ?.toString() ??
        '',
    (size) => _format(SizeAttribute(size.isEmpty ? null : size)),
  );

  Future<void> _pickFont(BuildContext context) async {
    final selection = controller.selection;
    final styles = controller.getSelectionStyle().attributes;
    final preview = selection.isCollapsed
        ? ''
        : controller.document
              .getPlainText(selection.start, selection.end - selection.start)
              .replaceAll('\uFFFC', '')
              .characters
              .take(90)
              .toString();
    focusNode.unfocus();
    final family = await showNoteFontPicker(
      context,
      family: styles[Attribute.font.key]?.value as String?,
      preview: preview,
      bold: styles[Attribute.bold.key]?.value == true,
      italic: styles[Attribute.italic.key]?.value == true,
    );
    if (!context.mounted || family == null) return;
    controller.updateSelection(selection, ChangeSource.local);
    controller.document.history.lastRecorded = 0;
    _format(FontAttribute(family.isEmpty ? null : family));
    controller.document.history.lastRecorded = 0;
  }

  Future<void> _chooseValue<T>(
    BuildContext context,
    String title,
    List<(T, String)> options,
    T selected,
    void Function(T) apply,
  ) async {
    final selection = controller.selection;
    focusNode.unfocus();
    final result = await showDialog<T>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final option in options)
                ListTile(
                  title: Text(option.$2),
                  selected: selected == option.$1,
                  trailing: selected == option.$1
                      ? const Icon(Icons.check)
                      : null,
                  onTap: () => Navigator.pop(context, option.$1),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
        ],
      ),
    );
    if (context.mounted && result != null) {
      controller.updateSelection(selection, ChangeSource.local);
      apply(result);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => Material(
        color: Theme.of(context).colorScheme.surface,
        child: Padding(
          padding: const EdgeInsets.all(2),
          child: _ScrollableFormatRail(
            key: const ValueKey('formatting-toolbar'),
            tools: [
              if (onAi != null)
                IconButton(
                  tooltip: 'AI assistance',
                  onPressed: onAi,
                  icon: const Icon(Icons.auto_awesome_outlined),
                ),
              if (onStyles != null)
                IconButton(
                  tooltip: 'Text styles',
                  onPressed: onStyles,
                  icon: const Icon(Icons.text_fields),
                ),
              if (onStickers != null)
                IconButton(
                  tooltip: 'Stickers',
                  onPressed: onStickers,
                  icon: const Icon(Icons.sticky_note_2_outlined),
                ),
              _toggle(context, 'Bold', Icons.format_bold, Attribute.bold),
              _toggle(context, 'Italic', Icons.format_italic, Attribute.italic),
              _toggle(
                context,
                'Underline',
                Icons.format_underlined,
                Attribute.underline,
              ),
              IconButton(
                tooltip: 'Font family',
                onPressed: () => _pickFont(context),
                icon: const Icon(Icons.font_download_outlined),
                isSelected:
                    controller
                        .getSelectionStyle()
                        .attributes[Attribute.font.key]
                        ?.value !=
                    null,
              ),
              PopupMenuButton<bool>(
                tooltip: 'Color & highlight',
                useRootNavigator: false,
                onSelected: (highlight) =>
                    _pickColor(context, highlight: highlight),
                icon: const Icon(Icons.format_color_text),
                itemBuilder: (_) => const [
                  PopupMenuItem(value: false, child: Text('Text color')),
                  PopupMenuItem(value: true, child: Text('Highlight')),
                ],
              ),
              IconButton(
                tooltip: 'Insert or edit link',
                onPressed: () => _editLink(context),
                icon: const Icon(Icons.link),
              ),
              IconButton(
                tooltip: 'Highlight',
                onPressed: () => _pickColor(context, highlight: true),
                icon: const Icon(Icons.highlight),
              ),
              _toggle(
                context,
                'Strikethrough',
                Icons.strikethrough_s,
                Attribute.strikeThrough,
              ),
              IconButton(
                tooltip: 'Headings',
                onPressed: () => _pickHeading(context),
                icon: const Icon(Icons.title),
              ),
              IconButton(
                tooltip: 'Font size',
                onPressed: () => _pickFontSize(context),
                icon: const Icon(Icons.format_size),
              ),
              _toggle(
                context,
                'Bulleted list',
                Icons.format_list_bulleted,
                Attribute.ul,
              ),
              _toggle(
                context,
                'Numbered list',
                Icons.format_list_numbered,
                Attribute.ol,
              ),
              _toggle(
                context,
                'Checklist',
                Icons.checklist,
                Attribute.unchecked,
              ),
              _toggle(
                context,
                'Quote',
                Icons.format_quote,
                Attribute.blockQuote,
              ),
              IconButton(
                tooltip: 'Clear formatting',
                onPressed: _clearFormatting,
                icon: const Icon(Icons.format_clear),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ScrollableFormatRail extends StatefulWidget {
  const _ScrollableFormatRail({super.key, required this.tools});

  final List<Widget> tools;

  @override
  State<_ScrollableFormatRail> createState() => _ScrollableFormatRailState();
}

class _ScrollableFormatRailState extends State<_ScrollableFormatRail> {
  final _scroll = ScrollController();
  bool _canBack = false;
  bool _canForward = false;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateArrows);
  }

  void _updateArrows() {
    if (!mounted ||
        !_scroll.hasClients ||
        !_scroll.position.hasContentDimensions) {
      return;
    }
    final back = _scroll.position.extentBefore > 1;
    final forward = _scroll.position.extentAfter > 1;
    if (back == _canBack && forward == _canForward) return;
    setState(() {
      _canBack = back;
      _canForward = forward;
    });
  }

  void _browse(int direction) {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    _scroll.animateTo(
      (_scroll.offset + direction * position.viewportDimension * 0.8).clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      ),
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        IconButton(
          tooltip: 'Previous formatting tools',
          onPressed: _canBack ? () => _browse(-1) : null,
          icon: const Icon(Icons.chevron_left),
        ),
        Expanded(
          child: NotificationListener<ScrollMetricsNotification>(
            onNotification: (_) {
              _updateArrows();
              return false;
            },
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                dragDevices: const {
                  PointerDeviceKind.touch,
                  PointerDeviceKind.mouse,
                  PointerDeviceKind.trackpad,
                  PointerDeviceKind.stylus,
                  PointerDeviceKind.invertedStylus,
                },
                scrollbars: false,
              ),
              child: SingleChildScrollView(
                key: const ValueKey('formatting-scroll-strip'),
                controller: _scroll,
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final tool in widget.tools)
                      SizedBox(width: 48, height: 48, child: tool),
                  ],
                ),
              ),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Next formatting tools',
          onPressed: _canForward ? () => _browse(1) : null,
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    ),
  );

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }
}

class _ColorDialog extends StatelessWidget {
  const _ColorDialog({required this.highlight, this.selected});
  final bool highlight;
  final String? selected;
  static const _colors = [
    ('White', '#ffffff'),
    ('Black', '#000000'),
    ('Red', '#ef5350'),
    ('Orange', '#ff9800'),
    ('Yellow', '#ffeb3b'),
    ('Green', '#66bb6a'),
    ('Teal', '#26a69a'),
    ('Blue', '#42a5f5'),
    ('Purple', '#ab47bc'),
    ('Pink', '#ec407a'),
    ('Gray', '#9e9e9e'),
    ('Brown', '#8d6e63'),
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(highlight ? 'Highlight color' : 'Text color'),
      content: SingleChildScrollView(
        child: SizedBox(
          width: 280,
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _colors
                .map(
                  (color) => Tooltip(
                    message: color.$1,
                    child: Semantics(
                      selected: selected == color.$2,
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, color.$2),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.all(10),
                          side: BorderSide(
                            color: selected == color.$2
                                ? Theme.of(context).colorScheme.primary
                                : Theme.of(context).colorScheme.outlineVariant,
                            width: selected == color.$2 ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 28,
                              height: 28,
                              decoration: BoxDecoration(
                                color: Color(
                                  int.parse(
                                    'ff${color.$2.substring(1)}',
                                    radix: 16,
                                  ),
                                ),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Theme.of(context).colorScheme.outline,
                                ),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              color.$1,
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, ''),
          child: Text(highlight ? 'Remove highlight' : 'Default color'),
        ),
      ],
    );
  }
}

class _NoteLink {
  const _NoteLink(this.text, this.url);
  final String text;
  final String? url;
}

class _LinkDialog extends StatefulWidget {
  const _LinkDialog({required this.text, required this.url});
  final String text;
  final String? url;

  @override
  State<_LinkDialog> createState() => _LinkDialogState();
}

class _LinkDialogState extends State<_LinkDialog> {
  late final _text = TextEditingController(text: widget.text);
  late final _url = TextEditingController(text: widget.url ?? '');
  String? _error;

  void _submit() {
    final uri = parseNoteLink(_url.text);
    if (uri == null) {
      setState(
        () => _error = 'Enter a valid website URL or mailto: email link.',
      );
      return;
    }
    Navigator.pop(
      context,
      _NoteLink(
        _text.text.isEmpty ? uri.toString() : _text.text,
        uri.toString(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.url == null ? 'Insert link' : 'Edit link'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _text,
              decoration: const InputDecoration(labelText: 'Display text'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              autocorrect: false,
              textCapitalization: TextCapitalization.none,
              decoration: InputDecoration(
                labelText: 'URL',
                hintText: 'https://example.com',
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.url != null)
          TextButton(
            onPressed: () =>
                Navigator.pop(context, _NoteLink(widget.text, null)),
            child: const Text('Remove link'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(onPressed: _submit, child: const Text('Apply')),
      ],
    );
  }

  @override
  void dispose() {
    _text.dispose();
    _url.dispose();
    super.dispose();
  }
}
