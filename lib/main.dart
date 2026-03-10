import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:provider/provider.dart';
import '../core/utils/size_config.dart';
import '../features/auth/model/user_model.dart';
import 'core/base/app_providers.dart';
import 'core/constants/z_strings.dart';
import 'core/theme/theme.dart';
import 'features/auth/view/splash_screen.dart';
import 'features/notes/model/note.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
  ]);

  // Hive initialization
  await Hive.initFlutter();

  // Register Hive adapters ----------------------------------------------------
  Hive.registerAdapter(UserModelAdapter(),);
  Hive.registerAdapter(NoteAdapter());

  // Open Boxes here -----------------------------------------------------------
  final authBox = await Hive.openBox(ZStrings.authBox);
  final noteBox = await Hive.openBox(ZStrings.noteBox);

  runApp(
      MultiProvider(
          providers: AppProviders().get(authBox, noteBox),
      child: const MyApp())
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
      theme: LSTAppTheme.darkTheme,
      home: const SplashScreen(),
    );
  }
}
