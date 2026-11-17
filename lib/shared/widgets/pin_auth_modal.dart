import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../features/auth/view_model/auth_viewmodel.dart';

class PinInputModal {
  static Future<String?> setPin(BuildContext context) {
    return showDialog<String>(
      context: context,
      useRootNavigator: false,
      builder: (_) => const _PinDialog(settingPin: true),
    );
  }

  static Future<bool> removePin(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          useRootNavigator: false,
          builder: (_) => const _PinDialog(settingPin: false),
        ) ??
        false;
  }
}

class _PinDialog extends StatefulWidget {
  const _PinDialog({required this.settingPin});
  final bool settingPin;

  @override
  State<_PinDialog> createState() => _PinDialogState();
}

class _PinDialogState extends State<_PinDialog> {
  final _pinController = TextEditingController();
  final _confirmationController = TextEditingController();
  bool _verifying = false;
  String? _error;

  Future<void> _submit() async {
    if (_verifying) return;
    final pin = _pinController.text;
    if (!RegExp(r'^\d{4}$').hasMatch(pin)) {
      setState(() => _error = 'Enter a four-digit PIN.');
      return;
    }
    if (widget.settingPin) {
      if (pin != _confirmationController.text) {
        setState(() => _error = 'PINs do not match.');
        return;
      }
      Navigator.pop(context, pin);
      return;
    }
    setState(() {
      _verifying = true;
      _error = null;
    });
    try {
      final authenticated = await context.read<AuthViewModel>().authenticatePin(
        pin,
      );
      if (!mounted) return;
      if (authenticated) {
        Navigator.pop(context, true);
      } else {
        setState(() => _error = 'Incorrect PIN. App Lock is still enabled.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not verify PIN. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  Widget _pinField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      enabled: !_verifying,
      obscureText: true,
      enableSuggestions: false,
      autocorrect: false,
      keyboardType: TextInputType.number,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(4),
      ],
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_verifying,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        title: Text(
          widget.settingPin ? 'Set App Lock PIN' : 'Disable App Lock',
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'App Lock protects the entire app. Its PIN is separate from the shared PIN for individual notes.',
              ),
              const SizedBox(height: 20),
              _pinField(
                _pinController,
                widget.settingPin ? 'New PIN' : 'Current PIN',
              ),
              if (widget.settingPin) const SizedBox(height: 12),
              if (widget.settingPin)
                _pinField(_confirmationController, 'Confirm PIN'),
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
          TextButton(
            onPressed: _verifying ? null : () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: _verifying ? null : _submit,
            child: Text(
              _verifying
                  ? 'Verifying…'
                  : widget.settingPin
                  ? 'Enable'
                  : 'Disable',
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _pinController.dispose();
    _confirmationController.dispose();
    super.dispose();
  }
}
