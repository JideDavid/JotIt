import 'package:flutter/material.dart';
import 'dart:async';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';

import '../utils/l_printer.dart';

class InternetCheckerService extends ChangeNotifier {
  bool _isConnected = true;
  bool get isConnected => _isConnected;

  late StreamSubscription _subscription;

  final StreamController<bool> _connectionStatusController = StreamController<bool>.broadcast();
  Stream<bool> get connectionStatusStream => _connectionStatusController.stream;



  InternetCheckerService() {
    _subscription = InternetConnection().onStatusChange.listen((status) {
      final connected = status == InternetStatus.connected;

      if (_isConnected != connected) {
        _isConnected = connected;
        notifyListeners();

        _connectionStatusController.add(connected);
        ZPrint("Connection Status: ${connected ? "Online" : "Offline"}");
      }
    });
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
