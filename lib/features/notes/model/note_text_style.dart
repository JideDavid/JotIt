import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';

class NoteTextStyle {
  const NoteTextStyle(this.id, this.name, this.category, this.attributes);
  final String id;
  final String name;
  final String category;
  final Map<String, dynamic> attributes;

  TextStyle get previewStyle => TextStyle(
    fontFamily: attributes['font'] as String?,
    fontSize: double.tryParse('${attributes['size'] ?? 20}') ?? 20,
    fontWeight: attributes['bold'] == true
        ? FontWeight.bold
        : FontWeight.normal,
    fontStyle: attributes['italic'] == true
        ? FontStyle.italic
        : FontStyle.normal,
    decoration: attributes['underline'] == true
        ? TextDecoration.underline
        : null,
    color: colorValue(attributes['color']),
    backgroundColor: colorValue(attributes['background']),
  );

  static Color? colorValue(dynamic value) =>
      value is String && RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(value)
      ? Color(int.parse('ff${value.substring(1)}', radix: 16))
      : null;
}

class NoteTextStyles {
  NoteTextStyles._();
  static const categories = [
    'All',
    'Essentials',
    'Headings',
    'Highlights',
    'Quotes',
    'Study',
    'Creative',
    'Saved',
  ];
  static const presets = <NoteTextStyle>[
    NoteTextStyle('everyday', 'Everyday', 'Essentials', {}),
    NoteTextStyle('strong', 'Strong', 'Essentials', {
      'bold': true,
      'size': '20',
    }),
    NoteTextStyle('gentle', 'Gentle emphasis', 'Essentials', {'italic': true}),
    NoteTextStyle('mono-note', 'Mono note', 'Essentials', {
      'font': 'monospace',
    }),
    NoteTextStyle('small-caption', 'Small caption', 'Essentials', {
      'size': '14',
    }),
    NoteTextStyle('underlined', 'Underlined', 'Essentials', {
      'underline': true,
    }),
    NoteTextStyle('editorial', 'Editorial title', 'Headings', {
      'font': 'Playfair Display',
      'bold': true,
      'header': 1,
    }),
    NoteTextStyle('section-title', 'Section title', 'Headings', {
      'header': 2,
      'bold': true,
    }),
    NoteTextStyle('clean-headline', 'Clean headline', 'Headings', {
      'font': 'DM Sans',
      'header': 1,
      'bold': true,
    }),
    NoteTextStyle('quiet-heading', 'Quiet heading', 'Headings', {
      'font': 'Space Grotesk',
      'header': 3,
    }),
    NoteTextStyle('serif-subhead', 'Serif subhead', 'Headings', {
      'font': 'DM Serif Display',
      'header': 2,
    }),
    NoteTextStyle('amber-heading', 'Amber heading', 'Headings', {
      'header': 2,
      'bold': true,
      'color': '#a66c10',
    }),
    NoteTextStyle('amber-brush', 'Amber brush', 'Highlights', {
      'bold': true,
      'italic': true,
      'background': '#ffb52e',
      'color': '#30240e',
    }),
    NoteTextStyle('lemon-marker', 'Lemon marker', 'Highlights', {
      'background': '#f6df62',
      'color': '#30240e',
    }),
    NoteTextStyle('rose-marker', 'Rose marker', 'Highlights', {
      'background': '#f0a5b5',
      'color': '#43232d',
    }),
    NoteTextStyle('mint-marker', 'Mint marker', 'Highlights', {
      'background': '#9ac9ad',
      'color': '#203d2b',
    }),
    NoteTextStyle('blue-wash', 'Blue wash', 'Highlights', {
      'italic': true,
      'background': '#a0bfe5',
      'color': '#20334b',
    }),
    NoteTextStyle('violet-marker', 'Violet marker', 'Highlights', {
      'background': '#c8afe3',
      'color': '#372745',
    }),
    NoteTextStyle('classic-quote', 'Classic quote', 'Quotes', {
      'font': 'Playfair Display',
      'italic': true,
      'blockquote': true,
    }),
    NoteTextStyle('margin-note', 'Margin note', 'Quotes', {
      'font': 'monospace',
      'size': '16',
      'blockquote': true,
    }),
    NoteTextStyle('bold-statement', 'Bold statement', 'Quotes', {
      'bold': true,
      'size': '26',
    }),
    NoteTextStyle('centered-thought', 'Centered thought', 'Quotes', {
      'font': 'DM Serif Display',
      'italic': true,
      'align': 'center',
    }),
    NoteTextStyle('soft-citation', 'Soft citation', 'Quotes', {
      'italic': true,
      'size': '16',
    }),
    NoteTextStyle('handwritten-quote', 'Handwritten quote', 'Quotes', {
      'font': 'Caveat',
      'blockquote': true,
      'size': '24',
    }),
    NoteTextStyle('key-idea', 'Key idea', 'Study', {
      'bold': true,
      'underline': true,
    }),
    NoteTextStyle('definition', 'Definition', 'Study', {
      'font': 'DM Serif Display',
      'size': '20',
    }),
    NoteTextStyle('reference', 'Reference', 'Study', {
      'font': 'monospace',
      'size': '15',
      'italic': true,
    }),
    NoteTextStyle('question', 'Question', 'Study', {
      'bold': true,
      'italic': true,
      'size': '20',
    }),
    NoteTextStyle('memory-line', 'Memory line', 'Study', {
      'bold': true,
      'background': '#9ac9ad',
      'color': '#203d2b',
    }),
    NoteTextStyle('footnote', 'Footnote', 'Study', {
      'font': 'Playfair Display',
      'size': '14',
    }),
    NoteTextStyle('handwritten', 'Handwritten', 'Creative', {
      'font': 'Caveat',
      'size': '24',
    }),
    NoteTextStyle('typewriter', 'Typewriter', 'Creative', {
      'font': 'monospace',
      'size': '20',
    }),
    NoteTextStyle('ink', 'Book ink', 'Creative', {
      'font': 'DM Serif Display',
      'size': '24',
    }),
    NoteTextStyle('poster', 'Poster', 'Creative', {
      'font': 'Bungee',
      'size': '24',
    }),
    NoteTextStyle('red-pencil', 'Red pencil', 'Creative', {
      'font': 'Caveat',
      'underline': true,
      'size': '24',
      'color': '#be4e59',
    }),
    NoteTextStyle('retro-note', 'Retro note', 'Creative', {
      'font': 'monospace',
      'background': '#e7c485',
      'color': '#3a2a16',
    }),
  ];
  static NoteTextStyle? find(String id) {
    for (final preset in presets) {
      if (preset.id == id) return preset;
    }
    return null;
  }

  static void apply(
    QuillController controller,
    NoteTextStyle preset,
    TextSelection selection, {
    bool write = false,
  }) {
    controller.updateSelection(selection, ChangeSource.local);
    controller.document.history.lastRecorded = 0;
    if (write) {
      var offset = selection.end.clamp(0, controller.document.length - 1);
      final text = controller.document.toPlainText();
      if (offset > 0 && text[offset - 1] != '\n') {
        controller.replaceText(offset, 0, '\n', null);
        offset++;
      }
      controller.updateSelection(
        TextSelection.collapsed(offset: offset),
        ChangeSource.local,
      );
    }
    const managed = [
      'bold',
      'italic',
      'underline',
      'strike',
      'font',
      'size',
      'color',
      'background',
      'header',
      'blockquote',
      'align',
      'list',
    ];
    for (final key in managed) {
      final attribute = Attribute.fromKeyValue(key, preset.attributes[key]);
      controller.formatSelection(attribute);
    }
    controller.document.history.lastRecorded = 0;
  }
}
