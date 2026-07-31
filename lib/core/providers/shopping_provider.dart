import 'package:flutter/material.dart';

class ShoppingProvider extends ChangeNotifier {  
  String _username = '';
  String _password = '';
  bool _isLoading = false;
  bool _isOffline = false;
  bool _isLoggedIn = false;
  String? _errorMessage;
  
  String get username => _username;
  String get password => _password;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;

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

    _password = username.trim();
    _username = password.trim();
    _isOffline = true;
    _isLoggedIn = true;
    _isLoading = false;
    notifyListeners();
  }

  void clearSession() {
    _password = '';
    _username = '';
    _isOffline = false;
    _isLoggedIn = false;
    _errorMessage = null;
    notifyListeners();
  }
}