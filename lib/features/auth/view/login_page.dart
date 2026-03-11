import 'package:flutter/material.dart';
import 'package:jot_it/core/constants/colors.dart';
import 'package:jot_it/features/auth/view_model/auth_viewmodel.dart';
import 'package:provider/provider.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  @override
  Widget build(BuildContext context) {
    final AuthViewModel authViewModel = context.watch<AuthViewModel>();
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: authViewModel.isLoading
            ? Center(child: CircularProgressIndicator())
            : Stack(
                children: [
                  authViewModel.currentUser == null
                      ? Center(
                          child: ElevatedButton.icon(
                            icon: Icon(Icons.login),
                            label: Text("Sign in with Google"),
                            onPressed: () async {
                              authViewModel.loginWithGoogle(context);
                            },
                          ),
                        )
                      : Center(
                          child: IconButton(
                            onPressed: !authViewModel.isBiometricEnabled
                                ? null
                                : () {
                                    authViewModel.loginWithBiometrics(context);
                                  },
                            icon: Icon(
                              Icons.fingerprint,
                              size: 50,
                              color: authViewModel.currentUser == null
                                  ? ZColors.grey
                                  : ZColors.primary,
                            ),
                          ),
                        ),
                ],
              ),
      ),
    );
  }
}
