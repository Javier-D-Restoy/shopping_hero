import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class SessionProvider extends ChangeNotifier {
  static const String _boxName = 'session_box'; // Box de Hive CE para sesión
  Box? _box;

  String _username = 'Shopping Hero';
  String _password = '';
  bool _isLoading = false;
  bool _isOffline = true;
  bool _isLoggedIn = false;
  String? _errorMessage;

  // Getters
  String get username => _username;
  String get password => _password;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;

  // ---------------------------------------------- ][ ALMACENAMIENTO EN HIVE CE ][ ---------------------------------------------- //

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      }
    } catch (_) {
      _box = null;
    }

    if (_box == null) return;

    // Restaurar datos guardados de la sesión local
    _username = _box!.get('username', defaultValue: 'Shopping Hero') as String;
    _password = _box!.get('password', defaultValue: '') as String;
    _isOffline = _box!.get('isOffline', defaultValue: true) as bool;
    _isLoggedIn = _box!.get('isLoggedIn', defaultValue: false) as bool;

    notifyListeners();
  }

  Future<void> _ensureInitialized() async {
    if (_box == null) {
      await init();
    }
  }

  Future<void> saveToStorage() async {
    await _ensureInitialized();
    if (_box != null) {
      await _box!.put('username', _username);
      await _box!.put('password', _password);
      await _box!.put('isOffline', _isOffline);
      await _box!.put('isLoggedIn', _isLoggedIn);
    }
  }

  // ---------------------------------------------- ][ GESTIÓN DE SESIÓN ][ ---------------------------------------------- //

  Future<void> continueWithProfile({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      _errorMessage = 'Introduce tu nombre y usuario.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));

    _username = username.trim();
    _password = password.trim();
    _isOffline = false;
    _isLoggedIn = true;
    _isLoading = false;
    
    notifyListeners();
    unawaited(saveToStorage());
  }

  Future<void> continueOffline({
    required String username,
    required String password,
  }) async {
    if (username.trim().isEmpty || password.trim().isEmpty) {
      _errorMessage = 'Introduce tu nombre y usuario para usar modo local.';
      notifyListeners();
      return;
    }

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    await Future.delayed(const Duration(milliseconds: 400));

    // Guardado de credenciales del perfil local
    _username = username.trim();
    _password = password.trim();
    _isOffline = true;
    _isLoggedIn = false;
    _isLoading = false;

    notifyListeners();
    unawaited(saveToStorage());
  }

  Future<void> clearSession() async {
    _username = 'Shopping Hero';
    _password = '';
    _isOffline = true;
    _isLoggedIn = false;
    _errorMessage = null;

    notifyListeners();

    await _ensureInitialized();
    if (_box != null) {
      await _box!.clear(); // Limpia los datos de sesión en Hive
    }
  }

  void changeUsername(String newName) {
    if (newName.trim().isEmpty) return;
    _username = newName.trim();
    notifyListeners();
    unawaited(saveToStorage());
  }
}