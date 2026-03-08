import 'package:hive/hive.dart';
import 'package:jot_it/features/notes/repository/notes_repo.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import '../../features/auth/repository/auth_repository.dart';
import '../../features/auth/view_model/auth_viewmodel.dart';
import '../../features/notes/view-model/note_view_model.dart';
import '../services/hive_local_storage_service.dart';
import '../services/internet_checker_service.dart';
import '../services/local_biometric_service.dart';
import '../services/mock_auth_service.dart';

class AppProviders {

  List<SingleChildWidget> get(Box<dynamic> authBox, Box<dynamic> noteBox){

    final localStorage = HiveLocalStorageService(authBox, noteBox);
    return [
      // core providers --------------------------------------------------
      Provider(create: (_) => MockAuthService()),
      Provider<HiveLocalStorageService>.value(value: localStorage),
      Provider(create: (_) => LocalBiometricService()),
      ChangeNotifierProvider(create: (_) => InternetCheckerService()),


      // feature provider
      // auth providers --------------------------------------------------
      Provider(
        create: (context) =>
            AuthRepository(authService: context.read<MockAuthService>(),
                localStorageService: context.read<HiveLocalStorageService>()),
      ),

      ChangeNotifierProvider(
        create: (context) => AuthViewModel(
            authRepository: context.read<AuthRepository>(),
            localBiometricService: context.read<LocalBiometricService>(),
            internetCheckerService: context.read<InternetCheckerService>(),
        ),
      ),

      // note providers --------------------------------------------------
      Provider(create: (context) => NotesRepo(localStorageService: context.read<HiveLocalStorageService>())),
    
      ChangeNotifierProvider(
        create: (context) => NoteViewModel(notesRepo: context.read<NotesRepo>()),
      ),

    ];
  }
}