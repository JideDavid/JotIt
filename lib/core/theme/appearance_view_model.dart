import 'package:flutter/material.dart';
import '../services/local_storage_service.dart';
import 'appearance_bridge.dart';

class AppearanceViewModel extends ChangeNotifier {
  AppearanceViewModel(this._storage) {
    final stored = _storage.getAppearance();
    _mode = ThemeMode.values.firstWhere(
      (mode) => mode.name == stored,
      orElse: () =>
          _storage.hasExistingData() ? ThemeMode.dark : ThemeMode.system,
    );
  }

  final LocalStorageService _storage;
  late ThemeMode _mode;
  bool _saving = false;
  bool _disposed = false;
  String? _error;

  ThemeMode get mode => _mode;
  bool get saving => _saving;
  String? get error => _error;

  Future<void> initialize() async {
    try {
      await _storage.saveAppearance(_mode.name);
      mirrorAppearance(_mode.name);
    } catch (_) {
      _error = 'Could not save appearance. Please try again.';
    }
  }

  Future<bool> setMode(ThemeMode mode) async {
    if (_saving) return false;
    if (_mode == mode && _error == null) return true;
    _saving = true;
    _error = null;
    notifyListeners();
    try {
      await _storage.saveAppearance(mode.name);
      _mode = mode;
      mirrorAppearance(mode.name);
      return true;
    } catch (_) {
      _error = 'Could not save appearance. Please try again.';
      return false;
    } finally {
      _saving = false;
      if (!_disposed) notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
