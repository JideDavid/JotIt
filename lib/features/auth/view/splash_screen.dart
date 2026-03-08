import 'package:flutter/material.dart';
import 'package:jot_it/features/notes/view/homepage.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/z_strings.dart';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      _checkAuth();
    });
  }

  void _checkAuth() async{
    await Future.delayed(const Duration(seconds: 2));
    // ignore: use_build_context_synchronously
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const Homepage()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: SizedBox(
          width: double.infinity,
          height: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.max,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // logo circle
              Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: ZColors.darkGrey,
                ),
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 8),
                      Text(
                        ZStrings.appName,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: ZColors.primary,
                          fontSize: 30
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
  }
}
