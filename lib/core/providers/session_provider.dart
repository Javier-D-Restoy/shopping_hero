import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shopping_hero/core/services/auth_service.dart';
import 'package:shopping_hero/core/services/user_repository.dart';

class SessionProvider extends ChangeNotifier {
  static const String _sessionBoxName = 'session_box';
  Box? _box;

  // Firebase & Auth
  late final AuthService _authService;
  late final UserRepository _userRepository;

  // Estado de sesión
  String? _uid;
  String _email = '';
  String _displayName = 'Shopping Hero';
  bool _isLoading = false;
  bool _isOffline = true;
  bool _isLoggedIn = false;
  bool _hasActiveSession = false;
  String _lastRoute = 'login';
  String? _lastListName;
  String? _errorMessage;

  // Getters
  String? get uid => _uid;
  String get email => _email;
  String get displayName => _displayName;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  bool get isLoggedIn => _isLoggedIn;
  bool get hasActiveSession => _hasActiveSession;
  String get lastRoute => _lastRoute;
  String? get lastListName => _lastListName;
  String? get errorMessage => _errorMessage;

  SessionProvider({AuthService? authService, UserRepository? userRepository}) {
    _authService = authService ?? AuthService();
    _userRepository = userRepository ?? UserRepository();
  }

  // ---------------------------------------------- ][ ALMACENAMIENTO EN HIVE ][ ---------------------------------------------- //

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_sessionBoxName)) {
        _box = await Hive.openBox(_sessionBoxName);
      }
    } catch (_) {
      _box = null;
    }

    if (_box == null) return;

    // Restaurar estado de sesión local
    _uid = _box!.get('uid') as String?;
    _email = _box!.get('email', defaultValue: '') as String;
    _isOffline = _box!.get('isOffline', defaultValue: true) as bool;
    _isLoggedIn = _box!.get('isLoggedIn', defaultValue: false) as bool;
    _hasActiveSession = _box!.get('hasActiveSession', defaultValue: false) as bool;
    _lastRoute = _box!.get('lastRoute', defaultValue: 'login') as String;
    _lastListName = _box!.get('lastListName') as String?;

    // Cargar nombre dependiendo de si es Online u Offline
    if (_isOffline) {
      _displayName = _box!.get('offlineDisplayName', defaultValue: 'Shopping Hero') as String;
    } else {
      _displayName = _box!.get('displayName', defaultValue: 'Shopping Hero') as String;
    }

    notifyListeners();
  }

  Future<void> _ensureInitialized() async {
    if (_box == null) {
      await init();
    }
  }

  Future<void> _saveSessionToStorage() async {
    await _ensureInitialized();
    if (_box != null) {
      await _box!.put('uid', _uid);
      await _box!.put('email', _email);
      await _box!.put('isOffline', _isOffline);
      await _box!.put('isLoggedIn', _isLoggedIn);
      await _box!.put('hasActiveSession', _hasActiveSession);
      await _box!.put('lastRoute', _lastRoute);
      await _box!.put('lastListName', _lastListName);

      // Guardamos en claves separadas para evitar contaminación entre perfiles
      if (_isOffline) {
        await _box!.put('offlineDisplayName', _displayName);
      } else {
        await _box!.put('displayName', _displayName);
      }
    }
  }

  /// Recuerda la última pantalla visitada para restaurarla al reabrir la app
  Future<void> setLastRoute({required String route, String? listName}) async {
    _lastRoute = route;
    _lastListName = listName;
    await _saveSessionToStorage();
  }

  // ---------------------------------------------- ][ GESTIÓN DE AUTENTICACIÓN ][ ---------------------------------------------- //

  /// Registra un nuevo usuario con email, contraseña y nombre
  Future<bool> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.register(
        email: email,
        password: password,
        displayName: displayName,
      );

      if (user != null) {
        _uid = user.uid;
        _email = user.email;
        _displayName = user.displayName ?? 'Shopping Hero';
        _isOffline = false;
        _isLoggedIn = true;
        _hasActiveSession = true;
        _isLoading = false;
        _errorMessage = null;

        await _saveSessionToStorage();
        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = 'No se pudo crear la cuenta';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  /// Inicia sesión con email y contraseña
  Future<bool> login({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final user = await _authService.login(
        email: email,
        password: password,
      );

      if (user != null) {
        _uid = user.uid;
        _email = user.email;
        _displayName = user.displayName ?? 'Shopping Hero';
        _isOffline = false;
        _isLoggedIn = true;
        _hasActiveSession = true;
        _isLoading = false;
        _errorMessage = null;

        await _saveSessionToStorage();
        notifyListeners();
        return true;
      }

      _isLoading = false;
      _errorMessage = 'Login fallido';
      notifyListeners();
      return false;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  Future<bool> continueOffline({
    required String displayName,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _ensureInitialized();

      _uid = null;
      _email = '';
      _isOffline = true;
      _isLoggedIn = false;
      _hasActiveSession = true;

      // Recuperamos la clave dedicada para offline
      final savedOfflineName = _box?.get('offlineDisplayName') as String?;
      if (savedOfflineName != null && savedOfflineName.trim().isNotEmpty) {
        _displayName = savedOfflineName;
      } else if (displayName.trim().isNotEmpty) {
        _displayName = displayName.trim();
      } else {
        _displayName = 'Shopping Hero';
      }

      _isLoading = false;
      _errorMessage = null;

      await _saveSessionToStorage();
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error: $e';
      notifyListeners();
      return false;
    }
  }

  /// Cierra sesión y restablece el perfil al usuario Offline
  Future<void> logout() async {
    _isLoading = true;
    notifyListeners();

    try {
      if (!_isOffline) {
        await _authService.logout();
      }

      _uid = null;
      _email = '';
      _isOffline = true;
      _isLoggedIn = false;
      _hasActiveSession = false;
      _lastRoute = 'login';
      _lastListName = null;
      _errorMessage = null;
      _isLoading = false;

      // Al hacer logout recuperamos el nombre asignado al modo offline
      await _ensureInitialized();
      _displayName = _box?.get('offlineDisplayName', defaultValue: 'Shopping Hero') as String;

      await _saveSessionToStorage();

      notifyListeners();
    } catch (e) {
      _isLoading = false;
      _errorMessage = 'Error al cerrar sesión: $e';
      notifyListeners();
    }
  }

  /// Limpia todos los datos locales del usuario invitado
  Future<void> resetLocalProfile() async {
    await _ensureInitialized();

    _uid = null;
    _email = '';
    _displayName = 'Shopping Hero';
    _isOffline = true;
    _isLoggedIn = false;
    _hasActiveSession = false;
    _lastRoute = 'login';
    _lastListName = null;
    _errorMessage = null;

    if (_box != null) {
      await _box!.clear();
    }

    notifyListeners();
  }

  /// Cambia el nombre visible del usuario, actualizándolo localmente o en Firestore
  Future<bool> updateDisplayName(String newDisplayName) async {
    final trimmed = newDisplayName.trim();

    if (trimmed.isEmpty) {
      _errorMessage = 'El nombre no puede estar vacío';
      notifyListeners();
      return false;
    }

    try {
      if (!_isOffline && _uid != null) {
        await _userRepository.updateUserProfile(uid: _uid!, displayName: trimmed);
      }

      _displayName = trimmed;
      _errorMessage = null;
      await _saveSessionToStorage(); // Guarda automáticamente en 'offlineDisplayName' o 'displayName' según _isOffline
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'No se pudo actualizar el nombre: $e';
      notifyListeners();
      return false;
    }
  }

  /// Borra la cuenta por completo y regresa al modo offline por defecto
  Future<bool> deleteAccount() async {
    if (_isOffline || _uid == null) {
      _errorMessage = 'No hay ninguna cuenta online activa';
      notifyListeners();
      return false;
    }

    _isLoading = true;
    notifyListeners();

    try {
      final uid = _uid!;

      await _userRepository.deleteUserAccountData(uid);
      await _authService.deleteAccount();

      _uid = null;
      _email = '';
      _isOffline = true;
      _isLoggedIn = false;
      _hasActiveSession = false;
      _lastRoute = 'login';
      _lastListName = null;
      _errorMessage = null;
      _isLoading = false;

      await _ensureInitialized();
      // Restauramos nombre de offline
      _displayName = _box?.get('offlineDisplayName', defaultValue: 'Shopping Hero') as String;

      await _saveSessionToStorage();

      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
      return false;
    }
  }

  // ---------------------------------------------- ][ INTEGRACIÓN CON FIRESTORE ][ ---------------------------------------------- //

  Future<void> syncShoppingListsFromFirestore() async {
    if (_uid == null || _isOffline) return;

    try {
      await _userRepository.getShoppingLists(_uid!);
    } catch (e) {
      _errorMessage = 'Error sincronizando listas: $e';
      notifyListeners();
    }
  }

  Future<void> saveShoppingListsToFirestore(
    Map<String, Map<String, dynamic>> shoppingLists,
  ) async {
    if (_uid == null || _isOffline) return;

    try {
      // Se maneja desde ShoppingProvider
    } catch (e) {
      _errorMessage = 'Error guardando listas: $e';
      notifyListeners();
    }
  }
}