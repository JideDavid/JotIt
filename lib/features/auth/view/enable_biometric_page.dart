import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/quiet_chrome.dart';
import '../view_model/auth_viewmodel.dart';

class EnableBiometricPage extends StatelessWidget {
  const EnableBiometricPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Biometrics')),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.fingerprint,
                    size: 64,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Unlock with\na touch',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Use your device’s fingerprint or face authentication to unlock JotIt.',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  const QuietMessage(
                    child: Text(
                      'Your device handles biometric authentication. Enable App Lock first and keep your app PIN as a fallback.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: auth.changingLock || !auth.isAppLock
                        ? null
                        : () async {
                            final enabled = !auth.isBiometricEnabled;
                            await auth.saveBiometricEnabled(enabled, context);
                            if (context.mounted &&
                                auth.isBiometricEnabled == enabled) {
                              Navigator.pop(context);
                            }
                          },
                    child: Text(
                      auth.changingLock
                          ? 'Please wait…'
                          : auth.isBiometricEnabled
                          ? 'Disable biometrics'
                          : 'Enable biometrics',
                    ),
                  ),
                  TextButton(
                    onPressed: auth.changingLock
                        ? null
                        : () => Navigator.pop(context),
                    child: const Text('Not now'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
