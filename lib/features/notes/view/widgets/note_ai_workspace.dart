import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_quill/quill_delta.dart';
import 'package:provider/provider.dart';
import '../../../auth/view_model/auth_viewmodel.dart';
import '../../model/note_sticker.dart';
import '../../model/note_ai_context.dart';
import '../../model/note_ai_appearance.dart';
import '../../services/note_ai_service.dart';
import '../../view-model/note_view_model.dart';
import 'distressed_highlight.dart';
import 'note_stickers.dart';

/// Drafts stay separate from the live editor until the user applies them.
class NoteAiWorkspace extends StatefulWidget {
  const NoteAiWorkspace({
    super.key,
    required this.notes,
    required this.selection,
    this.service,
  });
  final NoteViewModel notes;
  final TextSelection selection;
  final NoteAiService? service;
  @override
  State<NoteAiWorkspace> createState() => _NoteAiWorkspaceState();
}

class _NoteAiWorkspaceState extends State<NoteAiWorkspace> {
  final _prompt = TextEditingController();
  late final Document _document;
  late final Delta _original;
  late final NoteAiService _service;
  AuthViewModel? _auth;
  String _mode = 'Format', _scope = 'Whole note';
  String? _error, _summary;
  List<String> _warnings = const [], _changes = const [];
  String _design = '';
  String _title = '';
  bool _busy = false, _showOriginal = false;
  int _generation = 0;
  Delta? _proposed;
  QuillController? _preview;
  int _start = 0, _length = 0;

  @override
  void initState() {
    super.initState();
    _document = widget.notes.bodyController.document;
    _original = _document.toDelta();
    if (!widget.selection.isCollapsed) _scope = 'Selected text';
    _service =
        widget.service ??
        NoteAiService(token: () async => _auth?.currentUser?.getIdToken());
    widget.notes.addListener(_privacyChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.read<AuthViewModel>();
    if (_auth != auth) {
      _auth?.removeListener(_privacyChanged);
      _auth = auth;
      auth.addListener(_privacyChanged);
    }
  }

  bool get _allowed =>
      !(_auth?.isLocked ?? true) &&
      widget.notes.canMoveAttachments &&
      identical(_document, widget.notes.bodyController.document);
  void _privacyChanged() {
    if (!_allowed) {
      _generation++;
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Unlock the note and reopen AI assistance to continue.';
        });
      }
    }
  }

  void _resetDraft() {
    _proposed = null;
    _summary = null;
    _warnings = const [];
    _changes = const [];
    _design = '';
    _error = null;
    final previous = _preview;
    _preview = null;
    WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
  }

  Future<void> _generate() async {
    if (_busy || !_allowed || _prompt.text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    final generation = ++_generation;
    final newNote = _scope == 'New note';
    final base = _proposed ?? (newNote ? (Delta()..insert('\n')) : _original);
    final source = Document.fromDelta(base);
    final all = source.toPlainText();
    source.close();
    if (_proposed == null) {
      _start = _scope == 'Selected text'
          ? widget.selection.start.clamp(0, all.length - 1)
          : 0;
      _length = _scope == 'Selected text'
          ? (widget.selection.end.clamp(_start, all.length - 1) - _start)
          : all.length - 1;
    }
    final text = all.substring(_start, _start + _length);
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final theme = Theme.of(context);
      final appearance = NoteAiAppearance(
        background: theme.scaffoldBackgroundColor,
        foreground: theme.colorScheme.onSurface,
      );
      final plan = await _service.generate(
        mode: _mode,
        prompt: _prompt.text.trim(),
        text: text,
        structure: NoteAiContext.describe(base, _start, _length),
        appearance: appearance,
        scope: ({
          'Whole note': 'whole',
          'Selected text': 'selection',
          'Add to note': 'append',
          'New note': 'new',
        })[_scope]!,
      );
      if (!mounted || generation != _generation || !_allowed) return;
      if (_scope == 'Add to note' &&
          plan.edits.any(
            (e) => e['kind'] != 'insert' || e['start'] != text.length,
          )) {
        throw const FormatException(
          'Choose Create and ask to add content at the end of the note, or choose Whole note to edit existing text.',
        );
      }
      final proposed = plan.propose(
        base,
        start: _start,
        length: _length,
        mode: _mode,
        appearance: appearance,
      );
      final previous = _preview;
      setState(() {
        final proposedDoc = Document.fromDelta(proposed);
        _length += proposedDoc.length - all.length;
        proposedDoc.close();
        _proposed = proposed;
        _summary = plan.summary;
        _warnings = plan.warnings;
        _changes = plan.changes;
        _design = plan.design;
        _title = plan.title.isEmpty ? _title : plan.title;
        _showOriginal = false;
        _preview = QuillController(
          document: Document.fromDelta(proposed),
          selection: const TextSelection.collapsed(offset: 0),
          readOnly: true,
        );
        _prompt.clear();
      });
      // Keep the old controller alive until its editor has left the tree.
      WidgetsBinding.instance.addPostFrameCallback((_) => previous?.dispose());
    } on FormatException catch (error) {
      if (mounted && generation == _generation) {
        setState(() => _error = error.message);
      }
    } catch (_) {
      if (mounted && generation == _generation) {
        setState(
          () => _error =
              'Could not prepare this proposal. Your note is unchanged. Try again.',
        );
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _busy = false);
    }
  }

  Future<void> _apply() async {
    final proposed = _proposed;
    if (proposed == null || !_allowed || _busy) return;
    final newNote = _scope == 'New note';
    final applied = newNote
        ? await widget.notes.saveGeneratedNote(proposed, _title)
        : widget.notes.applyAiProposal(_document, _original, proposed);
    if (!mounted) return;
    if (!applied) {
      setState(
        () => _error = newNote
            ? widget.notes.errorMessage ??
                  'Could not save the new note. Try again.'
            : 'The note changed while this preview was open. Reopen AI assistance to review a fresh proposal.',
      );
      return;
    }
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          newNote
              ? 'New note saved to your notes'
              : 'AI changes applied · Undo is available in the editor',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Gemini assistance')),
      body: SafeArea(
        top: false,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                if (!_allowed)
                  const Expanded(
                    child: Center(child: Text('Unlock the note to continue.')),
                  )
                else ...[
                  if (_proposed == null)
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'What would you like to do?',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              children: [
                                for (final mode in [
                                  'Format',
                                  'Refine',
                                  'Create',
                                ])
                                  ChoiceChip(
                                    label: Text(mode),
                                    selected: _mode == mode,
                                    onSelected: _busy
                                        ? null
                                        : (_) => setState(() => _mode = mode),
                                  ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: _scope,
                              decoration: const InputDecoration(
                                labelText: 'Apply to',
                              ),
                              items: [
                                for (final scope in [
                                  'Selected text',
                                  'Whole note',
                                  'Add to note',
                                  'New note',
                                ])
                                  DropdownMenuItem(
                                    value: scope,
                                    enabled:
                                        scope != 'Selected text' ||
                                        !widget.selection.isCollapsed,
                                    child: Text(scope),
                                  ),
                              ],
                              onChanged: _busy
                                  ? null
                                  : (value) => setState(() {
                                      _scope = value!;
                                      if (_scope == 'New note' ||
                                          _scope == 'Add to note') {
                                        _mode = 'Create';
                                      }
                                    }),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              'Text styles, headers, checklists, stickers & doodles',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                            const SizedBox(height: 10),
                            Wrap(
                              spacing: 8,
                              runSpacing: 4,
                              children: [
                                for (final suggestion in [
                                  'Make it more colorful',
                                  'Refine the wording',
                                  'Add headers and a few doodles',
                                  'Add a step-by-step checklist for posting a tutorial video on YouTube',
                                ])
                                  ActionChip(
                                    label: Text(suggestion),
                                    onPressed: _busy
                                        ? null
                                        : () {
                                            _prompt.text = suggestion;
                                            if (suggestion.startsWith(
                                              'Refine',
                                            )) {
                                              setState(() => _mode = 'Refine');
                                            }
                                            if (suggestion.startsWith(
                                              'Add a step',
                                            )) {
                                              setState(() => _mode = 'Create');
                                            }
                                          },
                                  ),
                              ],
                            ),
                            const SizedBox(height: 20),
                            const Text(
                              'Only the chosen text scope and your prompt are sent to the AI service when you tap Preview. Attachments stay on your device. Changes wait for your approval.',
                            ),
                            const SizedBox(height: 8),
                            const Text(
                              'Google may use free-tier API content to improve its products. Avoid sending sensitive information.',
                              style: TextStyle(fontSize: 12),
                            ),
                            if (!_service.configured)
                              const Padding(
                                padding: EdgeInsets.only(top: 16),
                                child: Text(
                                  'Firebase AI is unavailable in this build. Your local notes are still available.',
                                ),
                              ),
                          ],
                        ),
                      ),
                    )
                  else ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _summary ?? '',
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          if (_changes.isNotEmpty ||
                              _design.isNotEmpty ||
                              _warnings.isNotEmpty)
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    _changes.join(' · '),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: Theme.of(
                                      context,
                                    ).textTheme.bodySmall,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => showDialog<void>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      title: const Text('Review AI changes'),
                                      content: SingleChildScrollView(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            if (_design.isNotEmpty) ...[
                                              Text(_design),
                                              const SizedBox(height: 12),
                                            ],
                                            for (final change in _changes)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  bottom: 4,
                                                ),
                                                child: Text('• $change'),
                                              ),
                                            if (_warnings.isNotEmpty) ...[
                                              const SizedBox(height: 12),
                                              const Text(
                                                'Content to review',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                              for (final warning in _warnings)
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.only(
                                                        top: 8,
                                                      ),
                                                  child: Text(warning),
                                                ),
                                            ],
                                            const SizedBox(height: 12),
                                            const Text(
                                              'Wording changes happen only in Refine or Create. Original and Proposed let you check the result before applying.',
                                            ),
                                          ],
                                        ),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () =>
                                              Navigator.pop(context),
                                          child: const Text('Close'),
                                        ),
                                      ],
                                    ),
                                  ),
                                  icon: Icon(
                                    _warnings.isEmpty
                                        ? Icons.fact_check_outlined
                                        : Icons.info_outline,
                                    size: 18,
                                  ),
                                  label: Text(
                                    _warnings.isEmpty
                                        ? 'Details'
                                        : '${_warnings.length} to review',
                                  ),
                                ),
                              ],
                            ),
                          SegmentedButton<bool>(
                            segments: const [
                              ButtonSegment(
                                value: true,
                                label: Text('Original'),
                              ),
                              ButtonSegment(
                                value: false,
                                label: Text('Proposed'),
                              ),
                            ],
                            selected: {_showOriginal},
                            onSelectionChanged: (s) =>
                                setState(() => _showOriginal = s.single),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: _showOriginal
                          ? _OriginalPreview(
                              delta: _scope == 'New note'
                                  ? (Delta()..insert('\n'))
                                  : _original,
                            )
                          : NoteAiDocumentPreview(controller: _preview!),
                    ),
                  ],
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (_busy) const LinearProgressIndicator(),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextField(
                          controller: _prompt,
                          enabled: !_busy,
                          minLines: 1,
                          maxLines: 3,
                          maxLength: 2000,
                          decoration: InputDecoration(
                            counterText: '',
                            hintText: _proposed == null
                                ? 'Describe your changes…'
                                : 'Request another change to this draft…',
                            border: const OutlineInputBorder(),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (_proposed != null)
                              TextButton(
                                onPressed: _busy
                                    ? null
                                    : () => setState(_resetDraft),
                                child: const Text('Discard draft'),
                              ),
                            FilledButton.tonalIcon(
                              onPressed: _busy ? null : _generate,
                              icon: const Icon(Icons.auto_awesome, size: 18),
                              label: Text(
                                _busy
                                    ? 'Preparing…'
                                    : _proposed == null
                                    ? 'Preview changes'
                                    : 'Update preview',
                              ),
                            ),
                            if (_proposed != null)
                              FilledButton(
                                onPressed: _busy ? null : _apply,
                                child: Text(
                                  _scope == 'New note'
                                      ? 'Save new note'
                                      : 'Apply',
                                ),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _generation++;
    widget.notes.removeListener(_privacyChanged);
    _auth?.removeListener(_privacyChanged);
    if (widget.service == null) _service.dispose();
    _prompt.dispose();
    _preview?.dispose();
    super.dispose();
  }
}

class _OriginalPreview extends StatefulWidget {
  const _OriginalPreview({required this.delta});
  final Delta delta;
  @override
  State<_OriginalPreview> createState() => _OriginalPreviewState();
}

class _OriginalPreviewState extends State<_OriginalPreview> {
  late final controller = QuillController(
    document: Document.fromDelta(widget.delta),
    selection: const TextSelection.collapsed(offset: 0),
    readOnly: true,
  );
  @override
  Widget build(BuildContext context) =>
      NoteAiDocumentPreview(controller: controller);
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }
}

class NoteAiDocumentPreview extends StatefulWidget {
  const NoteAiDocumentPreview({super.key, required this.controller});
  final QuillController controller;
  @override
  State<NoteAiDocumentPreview> createState() => _NoteAiDocumentPreviewState();
}

class _NoteAiDocumentPreviewState extends State<NoteAiDocumentPreview> {
  final _scroll = ScrollController();
  final _focus = FocusNode();
  @override
  Widget build(BuildContext context) => DistressedHighlightLayer(
    repaint: Listenable.merge([widget.controller, _scroll]),
    child: QuillEditor.basic(
      controller: widget.controller,
      scrollController: _scroll,
      focusNode: _focus,
      config: QuillEditorConfig(
        padding: const EdgeInsets.all(20),
        expands: true,
        enableInteractiveSelection: false,
        textSpanBuilder: distressedHighlightSpanBuilder,
        onLaunchUrl: (_) {},
        embedBuilders: [
          _PreviewEmbed(NoteSticker.embedType),
          _PreviewEmbed('jot-media'),
        ],
        unknownEmbedBuilder: _PreviewEmbed('unknown'),
      ),
    ),
  );

  @override
  void dispose() {
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }
}

class _PreviewEmbed extends EmbedBuilder {
  _PreviewEmbed(this.key);
  @override
  final String key;
  @override
  bool get expanded => false;
  @override
  Widget build(BuildContext context, EmbedContext embedContext) {
    final sticker = NoteSticker.decode(embedContext.node.value.data);
    if (key == NoteSticker.embedType && sticker != null) {
      return Padding(
        padding: const EdgeInsets.all(8),
        child: NoteStickerVisual(
          sticker: sticker.copyWith(
            width: sticker.width.clamp(
              48,
              MediaQuery.sizeOf(context).width - 72,
            ),
          ),
        ),
      );
    }
    return const Chip(
      avatar: Icon(Icons.attachment, size: 16),
      label: Text('Existing attachment · kept'),
    );
  }
}
