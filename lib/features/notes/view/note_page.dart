import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/sizes.dart';
import '../model/note_link.dart';
import '../view-model/note_view_model.dart';
import 'widgets/rich_text_toolbar.dart';
import 'widgets/note_history_controls.dart';
import 'widgets/distressed_highlight.dart';
import 'widgets/note_pin_prompt.dart';
import 'widgets/note_paper_picker.dart';
import 'widgets/note_paper_surface.dart';
import '../../../core/theme/quiet_palette.dart';
import '../../auth/view_model/auth_viewmodel.dart';
import '../model/note_attachment.dart';
import '../services/note_attachment_picker.dart';
import '../services/note_media_controller.dart';
import 'widgets/note_attachment_embed.dart';
import 'widgets/note_attachment_drag.dart';
import 'widgets/note_recorder_sheet.dart';
import 'widgets/note_color_picker.dart';
import 'widgets/note_style_library.dart';
import 'widgets/note_stickers.dart';
import 'widgets/note_ai_workspace.dart';

class NotePage extends StatefulWidget {
  const NotePage({super.key});

  @override
  State<NotePage> createState() => _NotePageState();
}

class _NotePageState extends State<NotePage> {
  static const _historyClearance = 80.0;
  final _bodyFocus = FocusNode();
  final _bodyScroll = ScrollController();
  final _bodyEditorKey = GlobalKey<EditorState>();
  bool _handlingPop = false;
  final _media = NoteMediaController();
  AuthViewModel? _auth;
  NoteViewModel? _notes;
  NoteAttachment? _pendingAttachment;
  TextSelection? _attachmentSelection;
  bool _pickingAttachment = false;
  String? _editorTool;
  TextSelection _toolSelection = const TextSelection.collapsed(offset: 0);

  void _openEditorTool(String tool) {
    final notes = context.read<NoteViewModel>();
    if (!notes.canMoveAttachments) return;
    if (_editorTool == null || _bodyFocus.hasFocus) {
      _toolSelection = notes.bodyController.selection;
    }
    _bodyFocus.unfocus();
    setState(() => _editorTool = _editorTool == tool ? null : tool);
  }

  void _chooseStyle(NoteStyleChoice choice) {
    final notes = context.read<NoteViewModel>();
    if (notes.applyTextStyle(
      choice.style,
      _toolSelection,
      write: choice.write,
    )) {
      setState(() => _editorTool = null);
      _bodyFocus.requestFocus();
    }
  }

  Future<void> _browseTextStyles() async {
    final notes = context.read<NoteViewModel>();
    final document = notes.bodyController.document;
    final choice = await Navigator.push<NoteStyleChoice>(
      context,
      MaterialPageRoute(
        builder: (_) => NoteStyleLibrary(
          notes: notes,
          hasSelection: !_toolSelection.isCollapsed,
        ),
      ),
    );
    if (mounted &&
        choice != null &&
        identical(document, notes.bodyController.document)) {
      _chooseStyle(choice);
    }
  }

  Future<void> _openAi() async {
    final notes = context.read<NoteViewModel>();
    if (!notes.canMoveAttachments) return;
    final selection = _editorTool == null || _bodyFocus.hasFocus
        ? notes.bodyController.selection
        : _toolSelection;
    _bodyFocus.unfocus();
    setState(() => _editorTool = null);
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => NoteAiWorkspace(notes: notes, selection: selection),
      ),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthViewModel>();
    final notes = context.read<NoteViewModel>();
    if (_auth != auth || _notes != notes) {
      _auth?.removeListener(_checkMediaPrivacy);
      _notes?.removeListener(_checkMediaPrivacy);
      _auth = auth;
      _notes = notes;
      auth.addListener(_checkMediaPrivacy);
      notes.addListener(_checkMediaPrivacy);
    }
    _checkMediaPrivacy();
  }

  void _checkMediaPrivacy() => _media.setPrivacyAllowed(
    !(_auth?.isLocked ?? true) && !(_notes?.needsNoteUnlock ?? true),
  );

  Future<void> _attachMedia() async {
    if (_pickingAttachment) return;
    final notes = context.read<NoteViewModel>();
    _attachmentSelection = notes.bodyController.selection;
    _bodyFocus.unfocus();
    final choice = await showModalBottomSheet<String>(
      context: context,
      useRootNavigator: false,
      useSafeArea: true,
      isScrollControlled: true,
      constraints: const BoxConstraints(maxWidth: 640),
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Attach to note',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              for (final option in [
                (
                  'image',
                  Icons.image_outlined,
                  'Photos & images',
                  'Choose from your device',
                ),
                (
                  'audio',
                  Icons.audio_file_outlined,
                  'Audio file',
                  'Attach an existing recording',
                ),
                (
                  'record',
                  Icons.mic_none,
                  'Record voice note',
                  'Capture a thought in your own words',
                ),
              ])
                ListTile(
                  leading: Icon(option.$2),
                  title: Text(option.$3),
                  subtitle: Text(option.$4),
                  onTap: () => Navigator.pop(context, option.$1),
                ),
              const SizedBox(height: 12),
              const Text(
                'Stored on this device. Save the note to keep your media. Up to 5 MB per file, 20 MB and 12 attachments per note.',
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || choice == null) return;
    setState(() => _pickingAttachment = true);
    final document = notes.bodyController.document;
    try {
      final attachment = choice == 'record'
          ? await showNoteRecorder(context, _media)
          : await NoteAttachmentPicker().pick(
              choice == 'image'
                  ? NoteAttachmentKind.image
                  : NoteAttachmentKind.audio,
            );
      if (!mounted ||
          document != notes.bodyController.document ||
          attachment == null) {
        return;
      }
      _pendingAttachment = attachment;
      if (!(_auth?.isLocked ?? true) && !notes.needsNoteUnlock) {
        _insertPendingAttachment();
      }
    } on FormatException catch (error) {
      if (mounted) _attachmentError(error.message);
    } catch (_) {
      if (mounted) {
        _attachmentError(
          'Could not attach this file. Choose a supported file and try again.',
        );
      }
    } finally {
      if (choice == 'record') await _media.discardRecording();
      if (mounted) setState(() => _pickingAttachment = false);
    }
  }

  void _attachmentError(String message) => ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(message)));

  void _insertPendingAttachment() {
    final pending = _pendingAttachment;
    if (pending == null) return;
    final notes = context.read<NoteViewModel>();
    if (notes.attachMedia(pending, selection: _attachmentSelection)) {
      setState(() => _pendingAttachment = null);
      _bodyFocus.requestFocus();
    } else {
      _attachmentError(
        notes.errorMessage ?? 'Unlock the note before attaching media.',
      );
    }
  }

  Future<bool> _saveNote() async {
    final noteVM = context.read<NoteViewModel>();
    if (_pendingAttachment != null) {
      _insertPendingAttachment();
      if (_pendingAttachment != null) return false;
    }
    final saved = await noteVM.saveNote();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            saved ? 'Note saved' : noteVM.errorMessage ?? 'Save in progress.',
          ),
        ),
      );
    }
    return saved;
  }

  Future<void> _handlePagePop() async {
    final noteVM = context.read<NoteViewModel>();
    if (_handlingPop || noteVM.isSaving) return;
    if (!noteVM.hasUnsavedChanges && _pendingAttachment == null) {
      Navigator.pop(context);
      return;
    }
    _handlingPop = true;
    final action = await showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Save changes?'),
        content: const Text('Your note has unsaved changes.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Keep editing'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'discard'),
            child: const Text('Discard'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    final shouldLeave =
        action == 'discard' ||
        (action == 'save' && await _saveNote() && !noteVM.hasUnsavedChanges);
    _handlingPop = false;
    if (mounted && shouldLeave) Navigator.pop(context);
  }

  Future<void> _changeLock() async {
    final notes = context.read<NoteViewModel>();
    final locked = !(notes.openedNote?.isLocked ?? false);
    await showNotePinPrompt(
      context,
      title: locked ? 'Lock note' : 'Remove note lock',
      submitLabel: locked ? 'Save and lock' : 'Remove lock',
      onSubmit: (pin) => notes.changeOpenedNoteLock(pin, locked: locked),
    );
  }

  Future<void> _changePaper() async {
    final notes = context.read<NoteViewModel>();
    _bodyFocus.unfocus();
    final paper = await showNotePaperPicker(context, notes.paper);
    if (mounted && paper != null) notes.selectPaper(paper);
  }

  Future<void> _changeCardColor() async {
    final notes = context.read<NoteViewModel>();
    _bodyFocus.unfocus();
    final color = await showNoteColorPicker(context, notes);
    if (mounted && color != null) notes.selectColor(color);
  }

  Future<void> _openLink(String value) async {
    final uri = parseNoteLink(value);
    var opened = false;
    if (uri != null) {
      try {
        opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        opened = false;
      }
    }
    if (mounted && !opened) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this link.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final noteVM = context.watch<NoteViewModel>();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _handlePagePop();
      },
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 820),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: ZSizes.paddingSpaceSm,
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          tooltip: 'Back',
                          onPressed: _handlePagePop,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const Spacer(),
                        IconButton(
                          tooltip: 'Attach image or audio',
                          onPressed:
                              noteVM.isSaving ||
                                  _pickingAttachment ||
                                  _pendingAttachment != null
                              ? null
                              : _attachMedia,
                          icon: const Icon(Icons.attach_file),
                        ),
                        IconButton(
                          tooltip: 'Paper style',
                          onPressed: noteVM.isSaving || noteVM.changingNoteLock
                              ? null
                              : _changePaper,
                          icon: const Icon(Icons.texture),
                        ),
                        Tooltip(
                          message: 'Save note',
                          child: FilledButton(
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            onPressed: noteVM.isSaving ? null : _saveNote,
                            child: noteVM.isSaving
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text('Save'),
                          ),
                        ),
                        PopupMenuButton<String>(
                          tooltip: 'Note actions',
                          useRootNavigator: false,
                          enabled: !noteVM.isSaving && !noteVM.changingNoteLock,
                          icon: const Icon(Icons.more_horiz),
                          onSelected: (action) {
                            if (action == 'lock') _changeLock();
                            if (action == 'color') _changeCardColor();
                            if (action == 'paper') _changePaper();
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                              value: 'lock',
                              child: Text(
                                (noteVM.openedNote?.isLocked ?? false)
                                    ? 'Remove note lock'
                                    : 'Lock note',
                              ),
                            ),
                            const PopupMenuItem(
                              value: 'color',
                              child: Text('Note card color'),
                            ),
                            const PopupMenuItem(
                              value: 'paper',
                              child: Text('Paper style'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                    child: TextField(
                      controller: noteVM.titleController,
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                      ),
                      minLines: 1,
                      maxLines: MediaQuery.viewInsetsOf(context).bottom > 0
                          ? 1
                          : 2,
                      maxLength: 100,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        hintText: 'Title',
                        counterText: '',
                        filled: false,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                      ),
                    ),
                  ),
                  if (_pendingAttachment != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          const Text('Your selected media is ready.'),
                          TextButton(
                            onPressed: _insertPendingAttachment,
                            child: const Text('Attach now'),
                          ),
                          TextButton(
                            onPressed: () =>
                                setState(() => _pendingAttachment = null),
                            child: const Text('Discard media'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        NoteStickerLayer(
                          notes: noteVM,
                          editorKey: _bodyEditorKey,
                          scrollController: _bodyScroll,
                          child: NoteAttachmentDragLayer(
                            notes: noteVM,
                            editorKey: _bodyEditorKey,
                            scrollController: _bodyScroll,
                            child: NotePaperSurface(
                              paper: noteVM.paper,
                              scrollController: _bodyScroll,
                              child: DistressedHighlightLayer(
                                repaint: Listenable.merge([
                                  noteVM.bodyController,
                                  _bodyScroll,
                                ]),
                                child: QuillEditor.basic(
                                  key: const ValueKey('note-body-editor'),
                                  controller: noteVM.bodyController,
                                  focusNode: _bodyFocus,
                                  scrollController: _bodyScroll,
                                  config: QuillEditorConfig(
                                    editorKey: _bodyEditorKey,
                                    textSpanBuilder:
                                        distressedHighlightSpanBuilder,
                                    expands: true,
                                    padding: const EdgeInsets.fromLTRB(
                                      24,
                                      16,
                                      24,
                                      _historyClearance,
                                    ),
                                    scrollBottomInset: _historyClearance,
                                    placeholder: 'Write your note…',
                                    onLaunchUrl: _openLink,
                                    embedBuilders: [
                                      NoteStickerEmbedBuilder(noteVM),
                                      NoteAttachmentEmbedBuilder(
                                        notes: noteVM,
                                        media: _media,
                                      ),
                                    ],
                                    customStyles: DefaultStyles(
                                      paragraph: DefaultTextBlockStyle(
                                        TextStyle(
                                          fontSize: 18,
                                          height: 1.5,
                                          color: NotePaperSurface.foregroundFor(
                                            noteVM.paper.tone,
                                            Theme.of(context),
                                          ),
                                        ),
                                        const HorizontalSpacing(0, 0),
                                        const VerticalSpacing(0, 0),
                                        const VerticalSpacing(0, 0),
                                        null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          end: 16,
                          bottom: 12,
                          child: NoteHistoryControls(
                            controller: noteVM.bodyController,
                            focusNode: _bodyFocus,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_editorTool != null &&
                      _editorTool != 'ai' &&
                      noteVM.canMoveAttachments)
                    ConstrainedBox(
                      constraints: BoxConstraints(
                        maxHeight: MediaQuery.sizeOf(context).height * .44,
                      ),
                      child: SingleChildScrollView(
                        child: _editorTool == 'styles'
                            ? NoteStylePalette(
                                notes: noteVM,
                                hasSelection: !_toolSelection.isCollapsed,
                                onChoose: _chooseStyle,
                                onBrowse: _browseTextStyles,
                                onClose: () =>
                                    setState(() => _editorTool = null),
                              )
                            : NoteStickerTray(
                                notes: noteVM,
                                selection: _toolSelection,
                                onClose: () =>
                                    setState(() => _editorTool = null),
                              ),
                      ),
                    ),
                  Padding(
                    key: const ValueKey('bottom-style-rail'),
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: RichTextToolbar(
                        controller: noteVM.bodyController,
                        focusNode: _bodyFocus,
                        onStyles: () => _openEditorTool('styles'),
                        onStickers: () => _openEditorTool('stickers'),
                        onAi: _openAi,
                      ),
                    ),
                  ),
                  ListenableBuilder(
                    listenable: Listenable.merge([
                      noteVM.titleController,
                      noteVM.bodyController,
                    ]),
                    builder: (context, _) => Padding(
                      padding: const EdgeInsets.fromLTRB(24, 0, 24, 10),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          noteVM.isSaving
                              ? 'Saving…'
                              : noteVM.errorMessage != null
                              ? 'Not saved · ${noteVM.errorMessage}'
                              : noteVM.hasUnsavedChanges
                              ? 'Unsaved changes · save when you’re ready'
                              : 'Saved on this device',
                          key: const ValueKey('note-save-status'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: noteVM.errorMessage != null
                                    ? Theme.of(context).colorScheme.error
                                    : noteVM.hasUnsavedChanges
                                    ? Theme.of(
                                        context,
                                      ).colorScheme.onSurfaceVariant
                                    : QuietPalette.of(context).success,
                              ),
                        ),
                      ),
                    ),
                  ),
                  if (noteVM.isSaving) const LinearProgressIndicator(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _auth?.removeListener(_checkMediaPrivacy);
    _notes?.removeListener(_checkMediaPrivacy);
    _media.dispose();
    _bodyFocus.dispose();
    _bodyScroll.dispose();
    super.dispose();
  }
}
