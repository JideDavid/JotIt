import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../view-model/note_view_model.dart';
import '../../../../shared/widgets/quiet_chrome.dart';
import '../../../../core/theme/theme.dart';
import '../../../auth/services/note_pin_recovery.dart';
import '../../../auth/view/note_pin_recovery_page.dart';

Future<bool> showNotePinPrompt(
  BuildContext context, {
  required String title,
  required String submitLabel,
  required Future<bool> Function(String) onSubmit,
}) async {
  return await showDialog<bool>(
        context: context,
        useRootNavigator: false,
        barrierDismissible: false,
        builder: (dialogContext) => NotePinPrompt(
          title: title,
          submitLabel: submitLabel,
          onSubmit: onSubmit,
          onSuccess: () => Navigator.pop(dialogContext, true),
          onCancel: () => Navigator.pop(dialogContext, false),
        ),
      ) ??
      false;
}

class NotePinPrompt extends StatefulWidget {
  const NotePinPrompt({
    super.key,
    required this.title,
    required this.submitLabel,
    required this.onSubmit,
    required this.onSuccess,
    this.onCancel,
    this.fullPage = false,
  });

  final String title;
  final String submitLabel;
  final Future<bool> Function(String) onSubmit;
  final VoidCallback onSuccess;
  final VoidCallback? onCancel;
  final bool fullPage;

  @override
  State<NotePinPrompt> createState() => _NotePinPromptState();
}

class _NotePinPromptState extends State<NotePinPrompt> {
  final _pin = TextEditingController();
  final _confirmation = TextEditingController();
  late final bool _settingPin;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _settingPin = !context.read<NoteViewModel>().hasNoteLockPin;
  }

  Future<void> _submit() async {
    if (_busy) return;
    if (!RegExp(r'^\d{4}$').hasMatch(_pin.text)) {
      setState(() => _error = 'Enter a four-digit PIN.');
      return;
    }
    if (_settingPin && _pin.text != _confirmation.text) {
      setState(() => _error = 'PINs do not match.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final notes = context.read<NoteViewModel>();
    try {
      final succeeded = await widget.onSubmit(_pin.text);
      if (!mounted) return;
      if (succeeded) {
        widget.onSuccess();
      } else {
        setState(() {
          _error =
              notes.noteLockError ?? notes.errorMessage ?? 'Please try again.';
          _pin.clear();
          _confirmation.clear();
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save changes. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      enabled: !_busy,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: InputDecoration(labelText: label),
      onChanged: (value) {
        if (widget.fullPage &&
            !_settingPin &&
            controller == _pin &&
            value.length == 4 &&
            !_busy) {
          _submit();
        }
      },
      onSubmitted: (_) => _submit(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final recovery = context.watch<NotePinRecovery?>();
    if (widget.fullPage) {
      final theme = Theme.of(context);
      return PopScope(
        canPop: !_busy,
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            key: const ValueKey('note-unlock-page'),
            padding: EdgeInsets.fromLTRB(
              24,
              24,
              24,
              MediaQuery.viewInsetsOf(context).bottom + 24,
            ),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      child: Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(22),
                        ),
                        child: Icon(
                          Icons.lock_outline,
                          color: theme.colorScheme.primary,
                          size: 32,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      _settingPin
                          ? 'Set shared note PIN'
                          : 'This note is locked',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineMedium,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _settingPin
                          ? 'One PIN protects all locked notes, independently of App Lock.'
                          : 'Enter your shared note PIN. Your note stays private until you unlock it.',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    _field(_pin, _settingPin ? 'New note PIN' : 'Note PIN'),
                    if (_settingPin) ...[
                      const SizedBox(height: 12),
                      _field(_confirmation, 'Confirm note PIN'),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ],
                    if (_settingPin) ...[
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: _busy ? null : _submit,
                        style: TextButton.styleFrom(
                          backgroundColor: LSTAppTheme.amber,
                          foregroundColor: LSTAppTheme.amberInk,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: Text(
                          _busy ? 'Please wait…' : widget.submitLabel,
                        ),
                      ),
                    ] else if (_busy)
                      const Padding(
                        padding: EdgeInsets.only(top: 16),
                        child: Center(
                          child: CircularProgressIndicator(
                            semanticsLabel: 'Unlocking note',
                          ),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (!_settingPin &&
                        recovery?.configured == true &&
                        recovery!.linked)
                      TextButton(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      NotePinRecoveryPage(recovery: recovery),
                                ),
                              ),
                        child: const Text('Forgot note PIN?'),
                      ),
                    const QuietMessage(
                      child: Text(
                        'Your shared note PIN is separate from App Lock. Recovery requires prior enrollment on this installation. If you have not linked recovery, keep your PIN safe.',
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(_settingPin ? 'Set shared note PIN' : widget.title),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                color: Theme.of(context).colorScheme.primary,
                size: 32,
              ),
              const SizedBox(height: 16),
              Text(
                _settingPin
                    ? 'This four-digit PIN protects all locked notes, independently of App Lock. After setting it, enroll in Recovery email in Settings if recovery is configured. Otherwise, keep it safe: a forgotten PIN cannot be recovered.'
                    : 'Enter your shared note PIN to continue.',
              ),
              const SizedBox(height: 20),
              _field(_pin, _settingPin ? 'New note PIN' : 'Note PIN'),
              if (_settingPin) ...[
                const SizedBox(height: 12),
                _field(_confirmation, 'Confirm note PIN'),
              ],
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 12),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
          ),
        ),
        actions: [
          if (widget.onCancel != null)
            TextButton(
              onPressed: _busy ? null : widget.onCancel,
              child: const Text('Cancel'),
            ),
          TextButton(
            onPressed: _busy ? null : _submit,
            child: Text(_busy ? 'Please wait…' : widget.submitLabel),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pin.dispose();
    _confirmation.dispose();
    super.dispose();
  }
}
