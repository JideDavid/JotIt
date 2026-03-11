import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:jot_it/features/auth/view/login_page.dart';
import '../../../core/services/internet_checker_service.dart';
import '../../../core/services/local_biometric_service.dart';
import '../../../shared/widgets/z_snack_bar.dart';
import '../../notes/view/homepage.dart';
import '../repository/auth_repository.dart';

class AuthViewModel extends ChangeNotifier {
  final AuthRepository authRepository;
  final LocalBiometricService localBiometricService;
  final InternetCheckerService internetCheckerService;

  bool _isConnected = true;
  bool get isConnected => _isConnected;

  AuthViewModel({required this.authRepository,
      required this.localBiometricService,
      required this.internetCheckerService}){
    internetCheckerService.connectionStatusStream.listen((status) {
      _isConnected = status;
      notifyListeners();
    });
  }

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  User? _currentUser;
  User? get currentUser => _currentUser;

  bool _isBiometricEnabled = false;
  bool get isBiometricEnabled => _isBiometricEnabled;

  void routeRetuningUser(BuildContext context){
    _currentUser = authRepository.getCurrentUser();
    notifyListeners();

    checkBiometricEnabled();
    if(_currentUser != null && !_isBiometricEnabled){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const Homepage()));
    }
    else{
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const LoginPage()));
    }
  }

  void loginWithGoogle(BuildContext context) async {
    _isLoading = true;
    notifyListeners();
    User? user = await authRepository.signInWithGoogle();
    if (user != null) {
      _currentUser = user;
      notifyListeners();
      Navigator.pushReplacement(
        // ignore: use_build_context_synchronously
          context, MaterialPageRoute(builder: (context) => const Homepage()));
    }
    _isLoading = false;
    notifyListeners();
  }

  void loginWithBiometrics(BuildContext context) async {
    bool resp = await authenticateWithBiometric();
    if(resp){
      // ignore: use_build_context_synchronously
      ZSnackBar().success(context, "Login successful");
      Future.delayed(const Duration(seconds: 1), (){
        // ignore: use_build_context_synchronously
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const Homepage()));
      });
    }
  }

  Future<bool> authenticateWithBiometric() async{
    final available = await localBiometricService.isBiometricAvailable();
    if (!available) return false;
    bool resp = await localBiometricService.authenticate();
    return resp;
  }

  void logout(BuildContext context){
    // log user out
    authRepository.signOut();
    // ignore: use_build_context_synchronously
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const LoginPage()));
  }

  void getCurrentUser() {
    User? user = authRepository.getCurrentUser();
    _currentUser = user;
    notifyListeners();
  }

  void clearLocalStorage() async {
    await authRepository.localStorageService.clearAll();
  }

  void checkBiometricEnabled(){
    _isBiometricEnabled = authRepository.getBiometricEnabled();
    notifyListeners();
  }

  void saveBiometricEnabled(bool enabled, BuildContext context)async{
    // check if device has biometric option
    if(!enabled){
      bool biometricAvailable = await localBiometricService.isBiometricAvailable();
      if(!biometricAvailable){
        // ignore: use_build_context_synchronously
        ZSnackBar().error(context, "Biometric not available");
        return;
      }
    }
    final resp = await authenticateWithBiometric();
    if(resp){
      await authRepository.saveBiometricEnabled(enabled);
      checkBiometricEnabled();
    }
  }

}
