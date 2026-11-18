import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../auth/view/login_page.dart';
import '../../auth/view_model/auth_viewmodel.dart';
import '../services/note_cloud_sync.dart';

class NoteCloudPage extends StatefulWidget {
  const NoteCloudPage({super.key, this.cloud});
  final NoteCloudSync? cloud;
  @override
  State<NoteCloudPage> createState() => _NoteCloudPageState();
}

class _NoteCloudPageState extends State<NoteCloudPage> {
  @override
  void initState() {
    super.initState();
    widget.cloud?.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    widget.cloud?.removeListener(_changed);
    super.dispose();
  }

  Future<void> _connect() async {
    final user = context.read<AuthViewModel>().currentUser;
    final email = user?.email;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Connect cloud backup?'),
        content: SingleChildScrollView(
          child: Text(
            'All saved notes on this device, including locked notes, images and audio, will be uploaded to $email. Notes from this account will be downloaded here.\n\n'
            'Signing into this Google account gives other devices access to the cloud notes. Cloud storage uses provider-managed encryption, not end-to-end encryption. PINs stay on this device; they are not backed up.\n\n'
            'This local library will be linked to this account. Signing out pauses sync and keeps the downloaded notes on this device.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      await widget.cloud?.connect(expectedUid: user?.uid);
    }
  }

  Future<void> _restore(CloudBackup backup) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Restore backup copies?'),
        content: SingleChildScrollView(
          child: Text(
            'Recover up to ${backup.count} notes from ${_date(backup.createdAt)}. Existing notes stay unchanged. Different versions are added as restored copies; locked notes stay locked.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore copies'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) await widget.cloud?.restore(backup);
  }

  String _date(DateTime value) => value.toLocal().toString().substring(0, 16);

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthViewModel>(), cloud = widget.cloud;
    final configured = cloud?.configured ?? false, busy = cloud?.busy ?? false;
    final signedIn = auth.currentUser != null;
    final connected = cloud?.enabled ?? false;
    final matches = cloud?.matchesAccount ?? false;
    return PopScope(
      // Sync belongs to the service; users can leave this page while it runs.
      canPop: true,
      child: Scaffold(
        appBar: AppBar(title: const Text('Backup & sync')),
        body: SafeArea(
          top: false,
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 660),
              child: ListView(
                padding: const EdgeInsets.all(22),
                children: [
                  Text(
                    'Your notes, across devices',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Back up saved text, formatting, paper styles, stickers, images and audio. Conflicting edits keep both versions. Unsaved editor drafts stay on their device.',
                  ),
                  const SizedBox(height: 20),
                  if (!configured)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: Text(
                          'Cloud backup is not configured in this build. No notes have been uploaded. Your local notes still work.',
                        ),
                      ),
                    )
                  else if (!signedIn) ...[
                    const Text(
                      'Sign in with your verified Google account to connect backup and sync.',
                    ),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginPage()),
                      ),
                      child: const Text('Sign in to Google'),
                    ),
                  ] else if (connected && !matches)
                    const Text(
                      'This library is connected to a different account. Sign in to that account to resume sync. Local notes stay on this device.',
                    )
                  else ...[
                    Text(auth.currentUser!.email ?? 'Connected Google account'),
                    const SizedBox(height: 8),
                    Text(
                      connected
                          ? 'Automatic sync is on. Saved changes sync after you close the editor; other-device changes are checked while JotIt is open.'
                          : 'Sync is off. Connecting uploads this device’s saved notes and restores this account’s cloud library.',
                    ),
                    if (matches && cloud!.lastSync != null)
                      Text('Last synced ${_date(cloud.lastSync!)}'),
                    if (connected && cloud!.lastSync == null)
                      const Text(
                        'No successful backup yet. Keep this device’s local notes safe.',
                      ),
                    const SizedBox(height: 16),
                    if (!connected)
                      FilledButton.icon(
                        onPressed: busy ? null : _connect,
                        icon: const Icon(Icons.cloud_upload_outlined),
                        label: const Text('Connect backup & sync'),
                      ),
                    if (connected) ...[
                      FilledButton.icon(
                        onPressed: busy ? null : cloud!.sync,
                        icon: const Icon(Icons.sync),
                        label: const Text('Sync now'),
                      ),
                      TextButton(
                        onPressed: busy ? null : cloud!.pause,
                        child: const Text('Pause sync'),
                      ),
                    ],
                    if (matches) ...[
                      const SizedBox(height: 20),
                      Text(
                        'Restore a backup',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'The latest 20 cloud revisions are available. Restore adds copies and keeps current notes. Deletions sync across devices; older revisions can recover deleted notes while retained.',
                      ),
                      OutlinedButton(
                        onPressed: busy ? null : cloud!.loadBackups,
                        child: const Text('Browse backups'),
                      ),
                      for (final backup in cloud!.backups)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(_date(backup.createdAt)),
                          subtitle: Text(
                            '${backup.count} notes · revision ${backup.revision}',
                          ),
                          trailing: TextButton(
                            onPressed: busy ? null : () => _restore(backup),
                            child: const Text('Restore'),
                          ),
                        ),
                    ],
                  ],
                  if (busy)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (cloud?.error != null)
                    Semantics(
                      liveRegion: true,
                      child: Text(
                        cloud!.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  if (cloud?.notice != null && matches)
                    Semantics(liveRegion: true, child: Text(cloud!.notice!)),
                  const SizedBox(height: 24),
                  const Text(
                    'App Lock and note PINs remain local. On a new device, create a local shared note PIN before opening restored locked notes. Signing out keeps local notes and attachments. Backup supports up to 2,000 notes and 64 MiB per library; larger libraries report an error rather than skipping content.',
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
