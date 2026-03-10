import 'package:flutter/material.dart';
import '../../../core/services/google_auth_service.dart';
import '../../../shared/widgets/z_snack_bar.dart';
import '../../notes/view/homepage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  _LoginPageState createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final GoogleAuthService _authService = GoogleAuthService();
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: _loading
            ? CircularProgressIndicator()
            : ElevatedButton.icon(
          icon: Icon(Icons.login),
          label: Text("Sign in with Google"),
          onPressed: () async {
            setState(() {
              _loading = true;
            });
            final user = await _authService.signInWithGoogle();
            setState(() {
              _loading = false;
            });

            if (user != null) {

              // ignore: use_build_context_synchronously
              ZSnackBar().success(context, 'Signed in as ${user.displayName}');
              // ignore: use_build_context_synchronously
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const Homepage()));
            }
          },
        ),
      ),
    );
  }
}