import '../model/note_ai_plan.dart';
import '../model/note_text_style.dart';

/// Resolve model-selected paragraph IDs and exact quotes locally. The model
/// never supplies numeric offsets, even when no backend is used.
class GeminiAnchors {
  static List<Map<String, dynamic>> paragraphs(
    String text,
    List<Map<String, dynamic>> structure,
  ) {
    var start = 0;
    return text.split('\n').indexed.map((entry) {
      final id = 'p${entry.$1}';
      final existing = structure.where((s) => s['paragraphId'] == id);
      final p = <String, dynamic>{
        'paragraphId': id,
        'text': entry.$2,
        'start': start,
        'end': start + entry.$2.length,
        if (existing.isNotEmpty) 'existing': existing.first,
      };
      start += entry.$2.length + 1;
      return p;
    }).toList();
  }

  static Never _fail([String reason = 'Invalid anchored proposal.']) =>
      throw FormatException(reason);
  static final _word = RegExp(r'[\p{L}\p{M}\p{N}_]', unicode: true);
  static bool _boundary(String text, int at) {
    final left = text.substring(0, at).runes.toList();
    final right = text.substring(at).runes;
    return left.isEmpty ||
        right.isEmpty ||
        !_word.hasMatch(String.fromCharCode(left.last)) ||
        !_word.hasMatch(String.fromCharCode(right.first));
  }

  static NoteAiPlan resolve(
    dynamic value, {
    required String text,
    required String mode,
    required String scope,
    required String prompt,
  }) {
    if (value is! Map ||
        value['design'] is! String ||
        (value['design'] as String).length > 400 ||
        value['reviewedParagraphs'] is! List ||
        value['warnings'] is! List ||
        (value['warnings'] as List).length > 8 ||
        (value['warnings'] as List).any(
          (w) => w is! String || w.length > 250,
        ) ||
        value['edits'] is! List ||
        (value['edits'] as List).length > 200) {
      _fail('Return valid design, warnings and at most 200 anchored edits.');
    }
    final ps = paragraphs(text, const []);
    final ids = ps.map((p) => p['paragraphId']).toSet();
    final reviewed = value['reviewedParagraphs'] as List;
    if (reviewed.length != ids.length ||
        reviewed.toSet().length != ids.length ||
        reviewed.any((id) => !ids.contains(id))) {
      _fail(
        'Review every supplied paragraph ID exactly once, including blank paragraphs.',
      );
    }
    final edits = <Map<String, dynamic>>[];
    final roles = <String>{}, palette = <String>{}, fonts = <String>{};
    var titles = 0, decorations = 0, highlighted = 0, generated = 0;
    for (final raw in value['edits']) {
      if (raw is! Map) _fail();
      final matches = ps.where((p) => p['paragraphId'] == raw['paragraphId']);
      if (matches.isEmpty) _fail('Use only supplied paragraph IDs.');
      final p = matches.first, quote = raw['quote'] ?? '';
      if (quote is! String) _fail();
      final line = p['text'] as String;
      var start = p['start'] as int, length = line.length;
      if (quote.isNotEmpty) {
        final at = line.indexOf(quote);
        if (at < 0 || line.indexOf(quote, at + 1) >= 0) {
          _fail('Each quote must match exactly once in its named paragraph.');
        }
        start += at;
        length = quote.length;
      }
      if (!_boundary(text, start) || !_boundary(text, start + length)) {
        _fail('Quote targets must end at whole-word boundaries.');
      }
      final edit = <String, dynamic>{
        'kind': raw['kind'],
        'start': start,
        'length': length,
        'styleId': raw['styleId'] ?? '',
        'color': raw['color'] ?? '',
        'blocks': raw['blocks'] ?? [],
        'inlineOnly': true,
        'reset': raw['reset'] == true,
      };
      void color(dynamic c) {
        if (c == null || c == '') return;
        if (c is! String || !RegExp(r'^#[0-9a-fA-F]{6}$').hasMatch(c)) _fail();
        palette.add(c.toUpperCase());
      }

      color(edit['color']);
      switch (raw['kind']) {
        case 'paragraph':
          if (![
                'body',
                'title',
                'section',
                'subheading',
                'bullet',
                'numbered',
                'checklist',
                'quote',
              ].contains(raw['role']) ||
              quote.isNotEmpty ||
              !roles.add(p['paragraphId'] as String)) {
            _fail();
          }
          edit['role'] = raw['role'];
          if (raw['role'] == 'title' && ++titles > 1) _fail();
        case 'insert':
          if (quote.isNotEmpty ||
              !['before', 'after'].contains(raw['placement'])) {
            _fail();
          }
          edit['start'] = raw['placement'] == 'before'
              ? p['start']
              : ((p['end'] as int) + 1).clamp(0, text.length);
          edit['length'] = 0;
        case 'style':
          if (edit['styleId'] is! String) _fail();
          final style = NoteTextStyles.find(edit['styleId']);
          if (style == null) _fail('Use only supplied text style IDs.');
          final hasBlockStyle = [
            'header',
            'blockquote',
            'list',
          ].any((k) => style.attributes[k] != null);
          if (hasBlockStyle || style.category == 'Headings') {
            // The editor already strips block attributes from inline styles.
            // Permit their typography only when an explicit matching role
            // supplies the paragraph structure and the whole line is targeted.
            final header = style.attributes['header'];
            final expectedRole = header == 1
                ? 'title'
                : header == 2
                ? 'section'
                : header == 3
                ? 'subheading'
                : style.attributes['blockquote'] == true
                ? 'quote'
                : null;
            final matchingRole = (value['edits'] as List).any(
              (e) =>
                  e is Map &&
                  e['kind'] == 'paragraph' &&
                  e['paragraphId'] == raw['paragraphId'] &&
                  e['role'] == expectedRole,
            );
            if (expectedRole == null ||
                !matchingRole ||
                length != line.length) {
              _fail(
                'Block text presets require a matching paragraph role and a whole-paragraph target. Use inline presets for phrases.',
              );
            }
          }
          final attrs = style.attributes;
          if (attrs['font'] != null) fonts.add(attrs['font'].toString());
          color(attrs['background'] ?? attrs['color']);
          if (attrs['background'] != null) {
            if (length > 120 || quote.split(RegExp(r'\s+')).length > 24) {
              _fail(
                'Highlight phrases must be at most 120 characters and 24 words.',
              );
            }
            highlighted += length;
            edit['color'] = '';
          }
          if (length == 0) _fail();
        case 'replace':
          // On a completely empty Create canvas, replacing p0 is unambiguously
          // an insertion. Normalize it locally without relaxing replacement
          // rules for any existing content or a blank line in a filled note.
          if (mode == 'Create' &&
              text.isEmpty &&
              length == 0 &&
              (scope == 'whole' || scope == 'new')) {
            edit['kind'] = 'insert';
            break;
          }
          if (mode == 'Format') {
            _fail(
              'Format must preserve wording and existing objects. Use paragraph and style edits.',
            );
          }
          if (length == 0) {
            _fail(
              'There is no text to replace. Use insert with placement before or after the paragraph to add content.',
            );
          }
          if (text.substring(start, start + length).contains('\uFFFC')) {
            _fail(
              'Replacement must preserve existing objects. Target text around object markers.',
            );
          }
        case 'remove-sticker':
          if (quote != '\uFFFC') _fail();
        default:
          _fail();
      }
      if (scope == 'append' &&
          (raw['kind'] != 'insert' || edit['start'] != text.length)) {
        _fail();
      }
      if (edit['blocks'] is! List) _fail();
      for (final b in edit['blocks']) {
        if (b is! Map ||
            b['text'] is! String ||
            (b['body'] != null && b['body'] is! String)) {
          _fail();
        }
        final body = b['body'] as String? ?? '', content = b['text'] as String;
        generated += body.length + content.length;
        if (['sticker', 'doodle'].contains(b['type'])) decorations++;
        if (b['type'] == 'sticker' &&
            body.trim().isEmpty &&
            content.trim().isEmpty) {
          _fail();
        }
        color(b['color']);
        if (b['styleId'] != null && b['styleId'] is! String) _fail();
        final style = NoteTextStyles.find(b['styleId'] ?? '');
        if (style != null) {
          final a = style.attributes;
          if (a['header'] != null && b['type'] != 'heading' ||
              a['blockquote'] != null && b['type'] != 'quote') {
            _fail();
          }
          if (a['font'] != null) fonts.add(a['font'].toString());
          if (a['background'] != null) {
            color(a['background']);
            highlighted += content.length;
            if (content.length > 120) _fail();
          }
        }
      }
      edits.add(edit);
    }
    final expressive = RegExp(
      r'\b(expressive|maximalist|lots of|many stickers|many doodles)\b',
      caseSensitive: false,
    ).hasMatch(prompt);
    if (!expressive && palette.length > 3) {
      throw const FormatException(
        'Use at most three accent colors. The proposal used too many distinct highlight or ink colors.',
      );
    }
    if (generated > 60000 ||
        !expressive &&
            (decorations > 4 ||
                palette.length > 3 ||
                fonts.length > 2 ||
                highlighted > (text.length * .2).clamp(120, double.infinity))) {
      _fail();
    }
    final ranges = edits.where((e) => e['kind'] != 'paragraph').toList()
      ..sort((a, b) => (a['start'] as int).compareTo(b['start'] as int));
    var cursor = 0;
    for (final e in ranges) {
      if ((e['start'] as int) < cursor) {
        _fail(
          'Style and replacement targets must not overlap. Group insertions at the same boundary.',
        );
      }
      cursor = (e['start'] as int) + (e['length'] as int);
    }
    final counts = <String, int>{};
    for (final e in edits) {
      counts.update(e['kind'], (n) => n + 1, ifAbsent: () => 1);
    }
    const names = {
      'paragraph': 'paragraph roles',
      'style': 'text styles',
      'insert': 'insertions',
      'replace': 'wording changes',
      'remove-sticker': 'sticker removals',
    };
    return NoteAiPlan.fromJson({
      'anchored': true,
      'title': value['title'],
      'design': value['design'],
      'warnings': value['warnings'],
      'edits': edits,
      'changes': [for (final e in counts.entries) '${e.value} ${names[e.key]}'],
      'summary': edits.isEmpty
          ? 'No changes were needed for this request.'
          : mode == 'Format'
          ? 'Existing wording is preserved. Review the proposed formatting${counts.containsKey('insert') ? ' and additions' : ''}.'
          : counts.containsKey('replace')
          ? 'Review the proposed wording changes and formatting.'
          : counts.containsKey('insert')
          ? 'New content was added; existing wording was not rewritten.'
          : 'Formatting only; existing wording was not rewritten.',
    });
  }
}
