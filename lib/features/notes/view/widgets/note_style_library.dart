import 'package:flutter/material.dart';
import '../../model/note_text_style.dart';
import '../../view-model/note_view_model.dart';

class NoteStyleChoice {
  const NoteStyleChoice(this.style, {this.write = false});
  final NoteTextStyle style;
  final bool write;
}

class NoteStyleLibrary extends StatefulWidget {
  const NoteStyleLibrary({
    super.key,
    required this.notes,
    required this.hasSelection,
  });
  final NoteViewModel notes;
  final bool hasSelection;
  @override
  State<NoteStyleLibrary> createState() => _NoteStyleLibraryState();
}

class _NoteStyleLibraryState extends State<NoteStyleLibrary> {
  String _category = 'All', _query = '';
  NoteTextStyle _selected = NoteTextStyles.find('amber-brush')!;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.notes,
    builder: (context, _) {
      final saved = widget.notes.savedTextStyles;
      final matches = NoteTextStyles.presets
          .where(
            (p) =>
                (_category == 'All' ||
                    p.category == _category ||
                    _category == 'Saved' && saved.contains(p.id)) &&
                '${p.name} ${p.category}'.toLowerCase().contains(
                  _query.toLowerCase(),
                ),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(title: const Text('Text styles')),
        body: SafeArea(
          top: false,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 10),
                child: TextField(
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.search),
                    hintText: 'Find a style…',
                  ),
                  onChanged: (value) => setState(() => _query = value),
                ),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Row(
                  children: [
                    for (final c in NoteTextStyles.categories)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(c),
                          selected: c == _category,
                          onSelected: (_) => setState(() => _category = c),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '${matches.length} styles · ${widget.hasSelection ? 'selected text' : 'your next words'}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: matches.isEmpty
                    ? const Center(child: Text('No matching styles.'))
                    : GridView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              mainAxisExtent: 148,
                              crossAxisSpacing: 8,
                              mainAxisSpacing: 8,
                            ),
                        itemCount: matches.length,
                        itemBuilder: (context, i) => NoteStyleCard(
                          style: matches[i],
                          selected: matches[i].id == _selected.id,
                          saved: saved.contains(matches[i].id),
                          onTap: () => setState(() => _selected = matches[i]),
                          onSave: () async {
                            if (!await widget.notes.toggleSavedTextStyle(
                                  matches[i].id,
                                ) &&
                                context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Could not save this favorite. Try again.',
                                  ),
                                ),
                              );
                            }
                          },
                        ),
                      ),
              ),
              Material(
                color: Theme.of(context).colorScheme.surfaceContainerLow,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        _selected.name,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Keep what matters.',
                          style: _selected.previewStyle.copyWith(fontSize: 23),
                        ),
                      ),
                      NoteStyleActions(
                        hasSelection: widget.hasSelection,
                        onChoose: (write) => Navigator.pop(
                          context,
                          NoteStyleChoice(_selected, write: write),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class NoteStyleCard extends StatelessWidget {
  const NoteStyleCard({
    super.key,
    required this.style,
    required this.selected,
    required this.onTap,
    this.saved = false,
    this.onSave,
  });
  final NoteTextStyle style;
  final bool selected, saved;
  final VoidCallback onTap;
  final VoidCallback? onSave;
  @override
  Widget build(BuildContext context) => Material(
    color: selected
        ? Theme.of(context).colorScheme.primaryContainer
        : Theme.of(context).colorScheme.surfaceContainerLow,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: BorderSide(
        color: selected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.outlineVariant,
      ),
    ),
    child: Stack(
      children: [
        Positioned.fill(
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 22, 12, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Good\nideas.',
                        maxLines: 2,
                        style: style.previewStyle.copyWith(
                          fontSize: 21,
                          height: 1.12,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    style.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    style.category,
                    maxLines: 1,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(fontSize: 11),
                  ),
                ],
              ),
            ),
          ),
        ),
        if (onSave != null)
          Positioned(
            top: 0,
            right: 0,
            child: IconButton(
              tooltip: saved ? 'Unsave ${style.name}' : 'Save ${style.name}',
              onPressed: onSave,
              icon: Icon(
                saved ? Icons.bookmark : Icons.bookmark_border,
                size: 18,
              ),
            ),
          ),
      ],
    ),
  );
}

class NoteStyleActions extends StatelessWidget {
  const NoteStyleActions({
    super.key,
    required this.hasSelection,
    required this.onChoose,
  });
  final bool hasSelection;
  final ValueChanged<bool> onChoose;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: OutlinedButton(
          onPressed: () => onChoose(true),
          child: const Text('Write in this style', textAlign: TextAlign.center),
        ),
      ),
      const SizedBox(width: 8),
      Expanded(
        child: FilledButton(
          onPressed: hasSelection ? () => onChoose(false) : null,
          child: const Text('Apply to selection', textAlign: TextAlign.center),
        ),
      ),
    ],
  );
}

class NoteStylePalette extends StatefulWidget {
  const NoteStylePalette({
    super.key,
    required this.notes,
    required this.hasSelection,
    required this.onChoose,
    required this.onBrowse,
    required this.onClose,
  });
  final NoteViewModel notes;
  final bool hasSelection;
  final ValueChanged<NoteStyleChoice> onChoose;
  final VoidCallback onBrowse, onClose;
  @override
  State<NoteStylePalette> createState() => _NoteStylePaletteState();
}

class _NoteStylePaletteState extends State<NoteStylePalette> {
  NoteTextStyle _selected = NoteTextStyles.find('amber-brush')!;
  @override
  Widget build(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.surface,
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Text styles',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              TextButton(
                onPressed: widget.onBrowse,
                child: const Text('Browse all 36'),
              ),
              IconButton(
                tooltip: 'Close text styles',
                onPressed: widget.onClose,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: 6,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final ids = [
                  'amber-brush',
                  'editorial',
                  'classic-quote',
                  'handwritten',
                  'memory-line',
                  'typewriter',
                ];
                final style = NoteTextStyles.find(ids[i])!;
                return SizedBox(
                  width: 126,
                  child: NoteStyleCard(
                    style: style,
                    selected: _selected.id == style.id,
                    onTap: () => setState(() => _selected = style),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 8),
          NoteStyleActions(
            hasSelection: widget.hasSelection,
            onChoose: (write) =>
                widget.onChoose(NoteStyleChoice(_selected, write: write)),
          ),
        ],
      ),
    ),
  );
}
