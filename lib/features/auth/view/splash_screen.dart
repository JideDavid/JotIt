import 'package:flutter/material.dart';
import 'package:jot_it/features/auth/view/login_page.dart';
import 'package:jot_it/features/auth/view_model/auth_viewmodel.dart';
import 'package:jot_it/features/notes/view/homepage.dart';
import 'package:provider/provider.dart';
import '../../../core/constants/colors.dart';
import '../../../core/constants/z_strings.dart';
import '../../../core/services/google_auth_service.dart';
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final GoogleAuthService _authService = GoogleAuthService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_){
      Provider.of<AuthViewModel>(context, listen: false).routeRetuningUser(context);
    });
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
