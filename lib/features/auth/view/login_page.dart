import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../shared/widgets/quiet_chrome.dart';
import '../view_model/auth_viewmodel.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  void _openNotes(BuildContext context) {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      context.read<AuthViewModel>().routeToHomepage(context);
    }
  }

  Future<void> _confirmSignOut(BuildContext context) async {
    final auth = context.read<AuthViewModel>();
    final userId = auth.currentUser?.uid;
    final confirmed = await showDialog<bool>(
      context: context,
      useRootNavigator: false,
      builder: (context) => AlertDialog(
        title: const Text('Sign out of JotIt?'),
        content: const SingleChildScrollView(
          child: Text(
            'Cloud sync will pause. Your notes and attachments will stay on this device. App Lock and your shared note PIN will stay unchanged. Signing out does not delete local data or hide it from another account on this device.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Sign out'),
          ),
        ],
      ),
    );
    if (confirmed == true &&
        context.mounted &&
        !auth.isLocked &&
        auth.currentUser?.uid == userId) {
      await auth.logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>();
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Account')),
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
                  const JotWordmark(),
                  const SizedBox(height: 36),
                  Text(
                    auth.currentUser == null
                        ? 'A little more\npeace of mind.'
                        : 'Your account,\nconnected.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineLarge,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    auth.currentUser == null
                        ? 'Your notes work without an account. Connect Google when you’re ready.'
                        : 'Signed in as ${auth.currentUser!.email ?? 'your Google account'}.',
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  if (auth.currentUser != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Chip(
                        avatar: Icon(
                          auth.currentUser!.emailVerified
                              ? Icons.verified_outlined
                              : Icons.mail_outline,
                        ),
                        label: Text(
                          auth.currentUser!.emailVerified
                              ? 'Google email verified'
                              : 'Email not verified',
                        ),
                      ),
                    ),
                  if (!auth.isAccountAvailable)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: QuietMessage(
                        child: Text(
                          auth.accountUnavailableReason ??
                              'Account sign-in is unavailable in this build.',
                        ),
                      ),
                    ),
                  if (!auth.isConnected)
                    const Padding(
                      padding: EdgeInsets.only(bottom: 16),
                      child: Text(
                        'You appear to be offline. Local notes still work; signing in needs an internet connection.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  if (auth.accountNotice != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          auth.accountNotice!,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  if (auth.accountError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          auth.accountError!,
                          textAlign: TextAlign.center,
                          style: TextStyle(color: theme.colorScheme.error),
                        ),
                      ),
                    ),
                  if (auth.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: CircularProgressIndicator(),
                    ),
                  if (auth.currentUser == null)
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: auth.isLoading || !auth.isAccountAvailable
                            ? null
                            : auth.loginWithGoogle,
                        icon: const Icon(Icons.login),
                        label: const Text('Continue with Google'),
                      ),
                    ),
                  if (auth.currentUser != null)
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: auth.isLoading
                            ? null
                            : () => _confirmSignOut(context),
                        icon: const Icon(Icons.logout),
                        label: const Text('Sign out'),
                      ),
                    ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => _openNotes(context),
                    child: const Text('Continue with local notes'),
                  ),
                  const SizedBox(height: 24),
                  const QuietMessage(
                    child: Text(
                      'Signing in alone does not connect cloud backup. PIN recovery is not enabled automatically; it requires separate enrollment and a configured service. Backup & sync also needs a configured service and explicit connection in Settings. Signing in to an already connected account lets sync resume; signing out pauses sync and keeps local notes on this device.',
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
}
