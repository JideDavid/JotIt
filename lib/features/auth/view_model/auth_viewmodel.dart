import 'dart:async';

import 'package:flutter/material.dart';
import '../../../core/services/internet_checker_service.dart';
import '../../../core/services/local_biometric_service.dart';
import '../../../core/utils/l_printer.dart';
import '../../../shared/widgets/z_snack_bar.dart';
import '../../notes/view/homepage.dart';
import '../model/user_model.dart';
import '../repository/auth_repository.dart';
import '../view/email_login.dart';
import '../view/pin_login.dart';

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

  final emailController = TextEditingController(text: "user@test.com");
  final pinController = TextEditingController(text: "123456");
  final formKey = GlobalKey<FormState>();

  String _pin = '';
  String get pin => _pin;
  final int pinMaxLength = 4;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _obscurePin = true;
  bool get obscurePin => _obscurePin;

  UserModel? _currentUser;
  UserModel? get currentUser => _currentUser;

  bool _isBiometricEnabled = false;
  bool get isBiometricEnabled => _isBiometricEnabled;


  void togglePinVisibility() {
    _obscurePin = !_obscurePin;
    notifyListeners();
  }

  void backspacePin(){
    if (_pin.isNotEmpty){
      _pin = _pin.substring(0, _pin.length - 1);
      notifyListeners();
    }
  }

  void routeRetuningUser(BuildContext context){
    String? token = authRepository.getToken();
    if(token != null){
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PinLogin()));
    }
    else{
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const EmailLogin()));
    }
  }

  Future<void> loginWithEmail(BuildContext context) async {
    // validate form
    if (!formKey.currentState!.validate()) {
      return;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final resp = await authRepository.login(
        email: emailController.text.trim(),
        pin: pinController.text.trim(),
      );

      if (!resp) {
        _isLoading = false;
        notifyListeners();
        // ignore: use_build_context_synchronously
        ZSnackBar().error(context, "Login failed");
        return;
      }

      getCurrentUser();
      // Navigate after success
      // ignore: use_build_context_synchronously
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const Homepage()));

      // ignore: use_build_context_synchronously
      ZSnackBar().success(context, "Login successful");
    } catch (e) {
      // ignore: use_build_context_synchronously
      ZSnackBar().error(context, e.toString());
      ZPrint(e.toString());
    }

    _isLoading = false;
    notifyListeners();
  }

  void loginWithPin(BuildContext context, String input){

    if (_pin.length == pinMaxLength){
      return;
    }

    if (_pin.length < pinMaxLength){
     _pin += input;
      notifyListeners();
    }

    if (pin.length == pinMaxLength){
      if (pin == "1234"){
        ZSnackBar().success(context, "Login successful");
        getCurrentUser();
        Future.delayed(const Duration(seconds: 1), (){
          // ignore: use_build_context_synchronously
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const Homepage()));
        });
      }
      else{
        Future.delayed(const Duration(seconds: 1), () {
          _pin = "";
          notifyListeners();
          // ignore: use_build_context_synchronously
          ZSnackBar().error(context, "Incorrect pin");
        });
      }
    }
  }

  void loginWithBiometrics(BuildContext context) async {
    bool resp = await authenticateWithBiometric();
    if(resp){
      getCurrentUser();
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
    // ignore: use_build_context_synchronously
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const EmailLogin()));
  }

  void getCurrentUser() {
    _currentUser = authRepository.getCurrentUser();
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



  @override
  void dispose() {
    emailController.dispose();
    pinController.dispose();
    super.dispose();
  }
}
