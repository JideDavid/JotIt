import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../core/theme/appearance_view_model.dart';
import '../features/auth/view/login_page.dart';
import '../features/auth/view_model/auth_viewmodel.dart';
import '../features/notes/view-model/note_view_model.dart';
import '../shared/widgets/quiet_chrome.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _showNoteLockInfo(BuildContext context) {
    showDialog<void>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Shared note PIN'),
        content: const Text(
          'Open a note and choose Lock note to protect it. One shared PIN protects all locked notes and is separate from App Lock.\n\nVerified-email PIN recovery is planned, but is not available yet. Keep your PIN safe.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Got it'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final appearance = context.watch<AppearanceViewModel>();
    final notes = context.watch<NoteViewModel>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        top: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 660),
            child: ListView(
              padding: const EdgeInsets.all(22),
              children: [
                const QuietSectionLabel('Appearance'),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final choices = ThemeMode.values
                        .map(
                          (mode) => Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 3,
                              ),
                              child: Semantics(
                                selected: appearance.mode == mode,
                                child: OutlinedButton(
                                  key: ValueKey('appearance-${mode.name}'),
                                  onPressed: appearance.saving
                                      ? null
                                      : () => appearance.setMode(mode),
                                  style: OutlinedButton.styleFrom(
                                    backgroundColor: appearance.mode == mode
                                        ? theme.colorScheme.primaryContainer
                                        : theme.colorScheme.surface,
                                    side: BorderSide(
                                      color: appearance.mode == mode
                                          ? theme.colorScheme.primary
                                          : theme.colorScheme.outlineVariant,
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 16,
                                      horizontal: 6,
                                    ),
                                  ),
                                  child: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(switch (mode) {
                                        ThemeMode.system =>
                                          Icons.desktop_windows_outlined,
                                        ThemeMode.light =>
                                          Icons.light_mode_outlined,
                                        ThemeMode.dark =>
                                          Icons.dark_mode_outlined,
                                      }),
                                      const SizedBox(height: 8),
                                      Text(switch (mode) {
                                        ThemeMode.system => 'System',
                                        ThemeMode.light => 'Light',
                                        ThemeMode.dark => 'Dark',
                                      }, textAlign: TextAlign.center),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        )
                        .toList();
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: choices,
                    );
                  },
                ),
                if (appearance.saving) const LinearProgressIndicator(),
                if (appearance.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      appearance.error!,
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                const SizedBox(height: 28),
                const QuietSectionLabel('Security'),
                Card(
                  child: Column(
                    children: [
                      SwitchListTile(
                        secondary: const Icon(Icons.shield_outlined),
                        title: const Text('App Lock'),
                        subtitle: const Text('Protect the entire app'),
                        value: auth.isAppLock,
                        onChanged: auth.changingLock
                            ? null
                            : (_) => auth.toggleAppLockChoice(context),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      SwitchListTile(
                        secondary: const Icon(Icons.fingerprint),
                        title: const Text('Biometric Login'),
                        subtitle: Text(
                          auth.isAppLock
                              ? 'Use device authentication; app PIN remains your fallback'
                              : 'Enable App Lock first',
                        ),
                        value: auth.isBiometricEnabled,
                        onChanged: auth.changingLock || !auth.isAppLock
                            ? null
                            : (enabled) =>
                                  auth.saveBiometricEnabled(enabled, context),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.lock_outline),
                        title: const Text('Shared note PIN'),
                        subtitle: Text(
                          notes.hasNoteLockPin
                              ? 'Protects individual notes'
                              : 'Set when you lock your first note',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _showNoteLockInfo(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const QuietSectionLabel('Account & recovery'),
                Card(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.mail_outline),
                        title: const Text('Recovery email'),
                        subtitle: const Text('Planned · not linked'),
                        onTap: () => _showNoteLockInfo(context),
                      ),
                      const Divider(height: 1, indent: 16, endIndent: 16),
                      ListTile(
                        leading: const Icon(Icons.account_circle_outlined),
                        title: const Text('Account'),
                        subtitle: Text(
                          auth.currentUser?.email ??
                              (auth.isAccountAvailable
                                  ? 'Optional · local notes work without an account'
                                  : 'Not configured · local notes still work'),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const LoginPage()),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                const QuietMessage(
                  child: Text(
                    'Notes are currently stored on this device. Cloud backup, cross-device sync, and verified-email PIN recovery are planned. No recovery email is sent by this version.',
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
