import 'package:hive/hive.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:jot_it/core/services/google_auth_service.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../../features/auth/repository/auth_repository.dart';
import '../../features/auth/view_model/auth_viewmodel.dart';
import '../../features/auth/services/note_pin_recovery.dart';
import '../../features/notes/view-model/note_view_model.dart';
import '../../features/notes/services/note_cloud_sync.dart';
import '../services/hive_local_storage_service.dart';
import '../services/internet_checker_service.dart';
import '../services/local_biometric_service.dart';
import '../theme/appearance_view_model.dart';

class AppProviders {
  List<SingleChildWidget> get(
    Box<dynamic> authBox,
    Box<dynamic> noteBox, {
    required AppearanceViewModel appearance,
    required GoogleAuthService accountService,
  }) {
    final localStorage = HiveLocalStorageService(authBox, noteBox);
    return [
      ChangeNotifierProvider.value(value: appearance),
      // core providers --------------------------------------------------
      Provider<GoogleAuthService>.value(value: accountService),
      Provider<HiveLocalStorageService>.value(value: localStorage),
      Provider(create: (_) => LocalBiometricService()),
      ChangeNotifierProvider(create: (_) => InternetCheckerService()),

      // feature provider
      // auth providers --------------------------------------------------
      Provider(
        create: (context) => AuthRepository(
          authService: context.read<GoogleAuthService>(),
          localStorageService: context.read<HiveLocalStorageService>(),
        ),
      ),

      ChangeNotifierProvider(
        create: (context) => AuthViewModel(
          authRepository: context.read<AuthRepository>(),
          localBiometricService: context.read<LocalBiometricService>(),
          internetCheckerService: context.read<InternetCheckerService>(),
        ),
      ),

      // note providers --------------------------------------------------
      Provider(
        create: (context) => NotesRepo(
          localStorageService: context.read<HiveLocalStorageService>(),
        ),
      ),

      ChangeNotifierProvider(
        create: (context) =>
            NoteViewModel(notesRepo: context.read<NotesRepo>()),
      ),
      ChangeNotifierProvider(
        create: (context) => NotePinRecovery(
          box: authBox,
          currentUid: () => accountService.currentUser?.uid,
          account: () async {
            final user = accountService.currentUser;
            if (user == null) return null;
            final token = await user.getIdToken(true);
            if (accountService.currentUser?.uid != user.uid) return null;
            return RecoveryAccount(
              user.uid,
              user.email ?? '',
              user.emailVerified,
              token ?? '',
            );
          },
          confirmPin: context.read<NoteViewModel>().verifyNotePinForRecovery,
          appCheckToken: () => FirebaseAppCheck.instance.getToken(),
          onReset: context.read<NoteViewModel>().revokeNotePinSessions,
          allowed: () => !context.read<AuthViewModel>().isLocked,
        ),
      ),
      ChangeNotifierProvider(
        lazy: false,
        create: (context) {
          final notes = context.read<NoteViewModel>();
          final cloud = NoteCloudSync(
            storage: localStorage,
            currentUid: () => accountService.currentUser?.uid,
            identity: () async {
              final user = accountService.currentUser;
              if (user == null) return null;
              final token = await user.getIdToken();
              if (accountService.currentUser?.uid != user.uid) return null;
              return CloudIdentity(user.uid, token ?? '', user.emailVerified);
            },
            appCheckToken: () => FirebaseAppCheck.instance.getToken(),
            canSync: () =>
                !context.read<AuthViewModel>().isLocked && notes.cloudCanSync,
            onChanged: notes.getNotesFromLocalStorage,
          );
          localStorage.onNotesChanged = cloud.localChanged;
          return cloud;
        },
      ),
    ];
  }
}
