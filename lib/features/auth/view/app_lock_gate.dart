import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../view_model/auth_viewmodel.dart';
import 'pin_login.dart';
import '../../notes/view-model/note_view_model.dart';
import '../../notes/view/widgets/note_pin_prompt.dart';

class AppLockGate extends StatefulWidget {
  const AppLockGate({super.key, required this.child});
  final Widget child;

  @override
  State<AppLockGate> createState() => _AppLockGateState();
}

class _AppLockGateState extends State<AppLockGate> with WidgetsBindingObserver {
  final _navigatorKey = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    context.read<AuthViewModel>().handleLifecycle(state);
    context.read<NoteViewModel>().handleLifecycle(state);
  }

  @override
  Widget build(BuildContext context) {
    final appLocked = context.watch<AuthViewModel>().isLocked;
    final notes = context.watch<NoteViewModel>();
    final locked = appLocked || notes.needsNoteUnlock;
    return PopScope(
      canPop: !locked,
      child: NavigatorPopHandler<Object?>(
        enabled: !locked,
        onPopWithResult: (result) {
          if (!locked) _navigatorKey.currentState?.maybePop(result);
        },
        child: Stack(
          fit: StackFit.expand,
          children: [
            Offstage(
              offstage: locked,
              child: TickerMode(
                enabled: !locked,
                child: ExcludeFocus(
                  excluding: locked,
                  child: Navigator(
                    key: _navigatorKey,
                    onGenerateRoute: (_) =>
                        MaterialPageRoute<void>(builder: (_) => widget.child),
                  ),
                ),
              ),
            ),
            if (appLocked) const PinLogin(),
            if (!appLocked && notes.needsNoteUnlock)
              Scaffold(
                resizeToAvoidBottomInset: false,
                appBar: AppBar(
                  automaticallyImplyLeading: false,
                  title: const Text('Private note'),
                  leading:
                      notes.hasUnsavedChanges ||
                          notes.isSaving ||
                          notes.changingNoteLock
                      ? null
                      : IconButton(
                          tooltip: 'Back to notes',
                          onPressed: () => _navigatorKey.currentState?.pop(),
                          icon: const Icon(Icons.arrow_back),
                        ),
                ),
                body: Center(
                  child: NotePinPrompt(
                    fullPage: true,
                    title: 'Unlock note',
                    submitLabel: 'Unlock note',
                    onSubmit: notes.unlockOpenedNote,
                    onSuccess: () {},
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
