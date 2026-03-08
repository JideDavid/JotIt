import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

import '../utils/l_printer.dart';

class LocalBiometricService{
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<bool> isBiometricAvailable() async {
    try {
      final bool canCheckBiometrics = await _localAuth.canCheckBiometrics;
      final bool isDeviceSupported = await _localAuth.isDeviceSupported();

      return canCheckBiometrics && isDeviceSupported;
    } catch (e) {
      ZPrint(e.toString());
      return false;
    }
  }


  Future<bool> authenticate() async {
    try {
      return await _localAuth.authenticate(
        localizedReason: 'Authenticate to continue',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
        ),
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: '  ',
            cancelButton: 'Cancel',
          ),
        ],
      );
    } catch (e) {
      ZPrint(e.toString());
      return false;
    }
  }
}
