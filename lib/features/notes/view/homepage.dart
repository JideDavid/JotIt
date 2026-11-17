import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/quiet_palette.dart';
import '../../../core/utils/date_time_helper.dart';
import '../../../shared/widgets/quiet_chrome.dart';
import '../../../views/settings_page.dart';
import '../model/note.dart';
import '../model/note_paper.dart';
import '../model/note_attachment.dart';
import '../view-model/note_view_model.dart';
import 'widgets/note_paper_surface.dart';
import 'widgets/note_pin_prompt.dart';

class Homepage extends StatefulWidget {
  const Homepage({super.key});

  @override
  State<Homepage> createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  String? _selectedNoteId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<NoteViewModel>().getNotesFromLocalStorage();
    });
  }

  Future<void> _deleteNote(Note note) async {
    final notes = context.read<NoteViewModel>();
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Delete this note?'),
        content: const Text(
          'This cannot be undone. Locked notes also require the shared note PIN.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep note'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true) return;
    final deleted = note.isLocked
        ? await showNotePinPrompt(
            context,
            title: 'Delete locked note?',
            submitLabel: 'Delete note',
            onSubmit: (pin) => notes.deleteNote(note.id, pin: pin),
          )
        : await notes.deleteNote(note.id);
    if (!mounted) return;
    if (deleted) {
      setState(() => _selectedNoteId = null);
    } else if (!note.isLocked) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(notes.errorMessage ?? 'Please try again.')),
      );
    }
  }

  Widget _card(Note note, NoteViewModel notes) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final palette = QuietPalette.of(context);
    final selected = _selectedNoteId == note.id;
    final attachments = note.isLocked
        ? const <NoteAttachmentKind>[]
        : note.attachmentKinds;
    final imageCount = attachments
        .where((kind) => kind == NoteAttachmentKind.image)
        .length;
    final audioCount = attachments.length - imageCount;
    return Padding(
      key: ValueKey('note-${note.id}'),
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: note.isLocked
            ? scheme.surfaceContainer
            : palette.cardSurface(note.color),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: note.isLocked
              ? null
              : NotePaperDecoration(
                  paper: NotePaper.decode(note.paper),
                  background: palette.cardSurface(note.color),
                  foreground: scheme.onSurface,
                  intensityScale: 0.65,
                ),
          child: InkWell(
            onTap: notes.isSaving ? null : () => notes.openNote(context, note),
            onLongPress: () => setState(() => _selectedNoteId = note.id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 12),
              child: selected
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          tooltip: 'Delete note',
                          onPressed: notes.isSaving
                              ? null
                              : () => _deleteNote(note),
                          icon: Icon(Icons.delete_outline, color: scheme.error),
                        ),
                        IconButton(
                          tooltip: 'Cancel selection',
                          onPressed: () =>
                              setState(() => _selectedNoteId = null),
                          icon: const Icon(Icons.close),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            if (note.isLocked) ...[
                              const Icon(Icons.lock_outline, size: 20),
                              const SizedBox(width: 8),
                            ],
                            Expanded(
                              child: Text(
                                note.isLocked
                                    ? 'Locked note'
                                    : note.title.isEmpty
                                    ? note.body.isEmpty
                                          ? 'Media note'
                                          : note.body
                                    : note.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.titleMedium,
                              ),
                            ),
                            PopupMenuButton<String>(
                              tooltip: 'Note actions',
                              enabled: !notes.isSaving,
                              onSelected: (action) {
                                if (action == 'open') {
                                  notes.openNote(context, note);
                                }
                                if (action == 'delete') _deleteNote(note);
                              },
                              itemBuilder: (_) => [
                                const PopupMenuItem(
                                  value: 'open',
                                  child: Text('Open note'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: Text(
                                    'Delete note',
                                    style: TextStyle(color: scheme.error),
                                  ),
                                ),
                              ],
                              icon: const Icon(Icons.more_horiz),
                            ),
                          ],
                        ),
                        if (note.isLocked) ...[
                          Text(
                            'Content stays private.',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Shared note PIN required',
                            style: theme.textTheme.bodySmall,
                          ),
                        ] else ...[
                          if (note.body.isNotEmpty &&
                              note.title.isNotEmpty) ...[
                            Text(
                              note.body,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          if (attachments.isNotEmpty) ...[
                            Wrap(
                              spacing: 16,
                              runSpacing: 4,
                              children: [
                                if (imageCount > 0)
                                  Text(
                                    '$imageCount ${imageCount == 1 ? 'image' : 'images'}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                if (audioCount > 0)
                                  Text(
                                    '$audioCount ${audioCount == 1 ? 'audio file' : 'audio files'}',
                                    style: theme.textTheme.bodySmall,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 6),
                          ],
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: palette.cardMarker(note.color),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Updated: ${DateTimeHelper.formatToReadable(note.timestamp)}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notes = context.watch<NoteViewModel>();
    final visible = notes.visibleNotes;
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 72,
        titleSpacing: 0,
        title: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 0, 12, 0),
              child: Row(
                children: [
                  const Expanded(child: JotWordmark()),
                  IconButton(
                    tooltip: 'Settings',
                    icon: const Icon(Icons.tune_rounded),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SettingsPage()),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        tooltip: 'Create note',
        onPressed: notes.isSaving ? null : () => notes.openNote(context, null),
        icon: const Icon(Icons.add),
        label: const Text('New note'),
      ),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Expanded(
                                  child: Text(
                                    'Your notes',
                                    style: theme.textTheme.headlineLarge,
                                  ),
                                ),
                                Text(
                                  '${visible.length} ${visible.length == 1 ? 'note' : 'notes'}',
                                  style: theme.textTheme.bodySmall,
                                ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            TextField(
                              controller: notes.searchController,
                              onChanged: (_) =>
                                  setState(() => _selectedNoteId = null),
                              decoration: InputDecoration(
                                hintText: 'Search notes',
                                prefixIcon: const Icon(Icons.search),
                                suffixIcon: notes.hasSearchQuery
                                    ? IconButton(
                                        tooltip: 'Clear search',
                                        icon: const Icon(Icons.close),
                                        onPressed: notes.searchController.clear,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 20),
                            Row(
                              children: [
                                const Expanded(
                                  child: QuietSectionLabel('Recently updated'),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 10),
                                  child: Text(
                                    'Newest first',
                                    style: theme.textTheme.bodySmall,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      if (notes.errorMessage != null)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 22),
                          child: Column(
                            children: [
                              Text(
                                notes.errorMessage!,
                                style: TextStyle(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                              TextButton(
                                onPressed: notes.isSaving
                                    ? null
                                    : notes.getNotesFromLocalStorage,
                                child: const Text('Reload notes'),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
                if (visible.isEmpty)
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              notes.hasSearchQuery
                                  ? Icons.search_off_rounded
                                  : Icons.edit_note_rounded,
                              size: 48,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              notes.hasSearchQuery
                                  ? 'No notes found'
                                  : 'Create your first note!',
                              style: theme.textTheme.titleLarge,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              notes.hasSearchQuery
                                  ? 'Try another search. Locked content stays private.'
                                  : 'Capture a thought, make a list, or start something new.',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                            if (notes.hasSearchQuery)
                              TextButton(
                                onPressed: notes.searchController.clear,
                                child: const Text('Clear search'),
                              ),
                            const SizedBox(height: 80),
                          ],
                        ),
                      ),
                    ),
                  )
                else
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(22, 0, 22, 100),
                    sliver: SliverList.builder(
                      itemCount: visible.length,
                      itemBuilder: (_, index) => _card(visible[index], notes),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
