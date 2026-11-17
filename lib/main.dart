import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../core/utils/size_config.dart';
import '../features/auth/model/user_model.dart';
import 'core/base/app_providers.dart';
import 'core/constants/z_strings.dart';
import 'core/theme/theme.dart';
import 'core/theme/appearance_view_model.dart';
import 'core/services/hive_local_storage_service.dart';
import 'core/services/google_auth_service.dart';
import 'features/auth/view/splash_screen.dart';
import 'features/auth/view/app_lock_gate.dart';
import 'features/notes/model/note.dart';
import 'features/notes/model/note_font.dart';
import 'features/notes/services/firebase_note_ai.dart';
import 'core/services/firebase_web_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  NoteFonts.registerLicenses();
  final accountService = await GoogleAuthService.initialize(
    options: kIsWeb ? firebaseWebOptions : null,
  );
  // App Check failures must not prevent access to local notes. AI retries
  // activation and reports verification failures when the user generates.
  try {
    await FirebaseNoteAi.initialize();
  } catch (_) {}

  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  // Hive initialization
  await Hive.initFlutter();

  // Register Hive adapters ----------------------------------------------------
  Hive.registerAdapter(UserModelAdapter());
  Hive.registerAdapter(NoteAdapter());

  // Open Boxes here -----------------------------------------------------------
  final authBox = await Hive.openBox(ZStrings.authBox);
  final noteBox = await Hive.openBox(ZStrings.noteBox);
  final appearance = AppearanceViewModel(
    HiveLocalStorageService(authBox, noteBox),
  );
  await appearance.initialize();

  runApp(
    MultiProvider(
      providers: AppProviders().get(
        authBox,
        noteBox,
        appearance: appearance,
        accountService: accountService,
      ),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    SizeConfig().init(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'JotIt',
      theme: LSTAppTheme.lightTheme,
      darkTheme: LSTAppTheme.darkTheme,
      themeMode: context.watch<AppearanceViewModel>().mode,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        FlutterQuillLocalizations.delegate,
      ],
      home: const AppLockGate(child: SplashScreen()),
    );
  }
}
