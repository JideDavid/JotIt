import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../services/note_pin_recovery.dart';
import '../view_model/auth_viewmodel.dart';
import 'login_page.dart';

class NotePinRecoveryPage extends StatefulWidget {
  const NotePinRecoveryPage({super.key, required this.recovery});
  final NotePinRecovery? recovery;
  @override
  State<NotePinRecoveryPage> createState() => _NotePinRecoveryPageState();
}

class _NotePinRecoveryPageState extends State<NotePinRecoveryPage> {
  final _current = TextEditingController(), _link = TextEditingController();
  final _new = TextEditingController(), _confirm = TextEditingController();
  @override
  void initState() {
    super.initState();
    widget.recovery?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  Widget _pin(TextEditingController controller, String label) => TextField(
    controller: controller,
    enabled: !(widget.recovery?.busy ?? false),
    obscureText: true,
    autocorrect: false,
    enableSuggestions: false,
    keyboardType: TextInputType.number,
    inputFormatters: [
      FilteringTextInputFormatter.digitsOnly,
      LengthLimitingTextInputFormatter(4),
    ],
    decoration: InputDecoration(labelText: label),
  );
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>(), r = widget.recovery;
    final ready = r?.configured ?? false, busy = r?.busy ?? false;
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(title: const Text('Recovery email')),
        body: SafeArea(
          top: false,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.all(20),
                children: [
                  Text(
                    'Shared note PIN recovery',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Recovery works only after you link your verified Google account on this installation. It resets the shared note PIN; App Lock has a separate PIN. Your notes stay on this device.',
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Linking recovery stores your verified email and an installation identifier on the recovery service. PINs and note contents stay on your device.',
                  ),
                  const SizedBox(height: 20),
                  if (!ready)
                    const Text(
                      'Recovery is not configured in this build. No recovery email can be sent yet. Keep your current PIN safe.',
                    )
                  else if (auth.currentUser == null ||
                      !auth.currentUser!.emailVerified) ...[
                    const Text(
                      'Sign in with a verified Google account before linking or using recovery.',
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            ),
                      child: const Text('Open account'),
                    ),
                  ] else if (!r!.hasPin)
                    const Text(
                      'Set your shared note PIN by locking a note before enrolling in recovery.',
                    )
                  else if (!r.linked) ...[
                    Text('Link ${auth.currentUser!.email}'),
                    const SizedBox(height: 12),
                    _pin(_current, 'Current shared note PIN'),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (await r.enroll(_current.text)) {
                                _current.clear();
                              }
                            },
                      child: const Text('Link recovery'),
                    ),
                    const Text(
                      'Linking requires your current note PIN and a recent Google sign-in. If asked, sign out and sign in again first.',
                    ),
                  ] else if (!r.matchesAccount) ...[
                    const Text(
                      'Sign in with the Google account originally enrolled for this installation. Another account cannot recover its note PIN.',
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const LoginPage(),
                              ),
                            ),
                      child: const Text('Open account'),
                    ),
                  ] else ...[
                    Text('Linked · ${r.maskedEmail}'),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      onPressed: busy || r.resendCoolingDown
                          ? null
                          : r.requestLink,
                      child: Text(
                        r.resendCoolingDown
                            ? 'Wait one minute to resend'
                            : 'Send recovery link',
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _link,
                      inputFormatters: [LengthLimitingTextInputFormatter(2048)],
                      enabled: !busy,
                      autocorrect: false,
                      enableSuggestions: false,
                      maxLines: 3,
                      decoration: const InputDecoration(
                        labelText: 'Recovery link from your email',
                      ),
                    ),
                    const SizedBox(height: 12),
                    _pin(_new, 'New shared note PIN'),
                    const SizedBox(height: 12),
                    _pin(_confirm, 'Confirm new note PIN'),
                    if (r.pendingReset)
                      const Padding(
                        padding: EdgeInsets.only(top: 12),
                        child: Text(
                          'An interrupted reset is saved. Use the same link and new PIN to finish it, or request a fresh link.',
                        ),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (await r.reset(
                                _link.text,
                                _new.text,
                                _confirm.text,
                              )) {
                                _link.clear();
                                _new.clear();
                                _confirm.clear();
                              }
                            },
                      child: const Text('Reset note PIN'),
                    ),
                    const Text(
                      'The link expires after 15 minutes. Resetting keeps all protected notes locked and closes existing note-unlock sessions.',
                    ),
                    const SizedBox(height: 24),
                    const Divider(),
                    _pin(_current, 'Current note PIN to manage recovery'),
                    if (!r.matchesEmail(auth.currentUser!.email ?? '')) ...[
                      const Text(
                        'Your account email changed. Verify your current note PIN and use a recent Google sign-in to update recovery.',
                      ),
                      TextButton(
                        onPressed: busy
                            ? null
                            : () async {
                                if (await r.enroll(_current.text)) {
                                  _current.clear();
                                }
                              },
                        child: const Text('Update recovery email'),
                      ),
                    ],
                    TextButton(
                      onPressed: busy
                          ? null
                          : () async {
                              if (await r.disable(_current.text)) {
                                _current.clear();
                              }
                            },
                      child: const Text('Unlink recovery'),
                    ),
                  ],
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (r?.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          r!.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  if (r?.notice != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(r!.notice!),
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

  @override
  void dispose() {
    widget.recovery?.removeListener(_changed);
    _current.dispose();
    _link.dispose();
    _new.dispose();
    _confirm.dispose();
    super.dispose();
  }
}
