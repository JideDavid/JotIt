import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/quiet_chrome.dart';
import '../view_model/auth_viewmodel.dart';

class PinLogin extends StatelessWidget {
  const PinLogin({super.key});

  @override
  Widget build(BuildContext context) {
    final authVM = context.watch<AuthViewModel>();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxHeight < 700;
            final spacing = compact ? 12.0 : 24.0;
            final width = (constraints.maxWidth - 32).clamp(0.0, 340.0);
            final keyHeight = (constraints.maxHeight * .105).clamp(48.0, 76.0);
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: SizedBox(
                    width: width,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const JotWordmark(),
                        SizedBox(height: spacing),
                        Text(
                          'Unlock JotIt',
                          style: theme.textTheme.headlineLarge,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enter your app PIN to continue.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        SizedBox(height: spacing),
                        Semantics(
                          label:
                              '${authVM.pin.length} of four app PIN digits entered',
                          excludeSemantics: true,
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(4, (index) {
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                child: Icon(
                                  Icons.circle,
                                  size: 20,
                                  color: authVM.pin.length > index
                                      ? scheme.primary
                                      : scheme.outline,
                                ),
                              );
                            }),
                          ),
                        ),
                        const SizedBox(height: 8),
                        if (authVM.lockError != null)
                          Text(
                            authVM.lockError!,
                            textAlign: TextAlign.center,
                            style: TextStyle(color: scheme.error),
                          ),
                        if (authVM.isAuthenticating)
                          const Padding(
                            padding: EdgeInsets.all(8),
                            child: CircularProgressIndicator(),
                          ),
                        SizedBox(height: spacing),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 3,
                                mainAxisExtent: keyHeight,
                                mainAxisSpacing: compact ? 8 : 12,
                                crossAxisSpacing: 12,
                              ),
                          itemCount: 12,
                          itemBuilder: (context, index) {
                            if (index == 9) {
                              return IconButton(
                                tooltip: 'Unlock with biometrics',
                                onPressed:
                                    authVM.isBiometricEnabled &&
                                        !authVM.isAuthenticating
                                    ? authVM.loginWithBiometrics
                                    : null,
                                icon: const Icon(Icons.fingerprint, size: 40),
                              );
                            }
                            if (index == 11) {
                              return IconButton(
                                tooltip: 'Delete PIN digit',
                                onPressed: authVM.isAuthenticating
                                    ? null
                                    : authVM.backspacePin,
                                icon: const Icon(Icons.backspace),
                              );
                            }
                            final digit = index == 10 ? '0' : '${index + 1}';
                            return TextButton(
                              onPressed: authVM.isAuthenticating
                                  ? null
                                  : () => authVM.unlockWithPin(digit),
                              style: TextButton.styleFrom(
                                backgroundColor: scheme.surface,
                                shape: const CircleBorder(),
                                side: BorderSide(color: scheme.outlineVariant),
                              ),
                              child: Text(
                                digit,
                                style: TextStyle(
                                  fontSize: 30,
                                  color: scheme.onSurface,
                                ),
                              ),
                            );
                          },
                        ),
                        SizedBox(height: spacing),
                        Text(
                          'Your app PIN is separate from your shared note PIN.',
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
