import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shopping_hero/core/models/user_model.dart';
import 'package:shopping_hero/core/services/user_repository.dart';

class AuthService {
  AuthService({
    FirebaseAuth? firebaseAuth,
    UserRepository? userRepository,
  })  : _auth = firebaseAuth ?? FirebaseAuth.instance,
        _userRepository = userRepository ?? UserRepository();

  final FirebaseAuth _auth;
  final UserRepository _userRepository;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Registra un nuevo usuario en Firebase Authentication y crea su perfil en Firestore
  Future<UserModel?> register({
    required String email,
    required String password,
    required String displayName,
  }) async {
    try {
      final emailTrimmed = email.trim();
      final passwordTrimmed = password.trim();
      final nameTrimmed = displayName.trim();

      if (emailTrimmed.isEmpty || passwordTrimmed.isEmpty || nameTrimmed.isEmpty) {
        throw Exception('Email, contraseña y nombre son requeridos');
      }

      if (passwordTrimmed.length < 6) {
        throw Exception('La contraseña debe tener al menos 6 caracteres');
      }

      // Crear usuario en Firebase Auth
      final userCredential = await _auth.createUserWithEmailAndPassword(
        email: emailTrimmed,
        password: passwordTrimmed,
      );

      final uid = userCredential.user!.uid;

      // Crear perfil en Firestore
      await _userRepository.createUserProfile(
        uid: uid,
        email: emailTrimmed,
        displayName: nameTrimmed,
      );

      // Retornar modelo de usuario
      return UserModel(
        uid: uid,
        email: emailTrimmed,
        displayName: nameTrimmed,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
    } on FirebaseAuthException catch (e) {
      debugPrint('FirebaseAuthException registro: code=${e.code} message=${e.message}');

      if (e.code == 'email-already-in-use') {
        throw Exception('Este email ya está registrado');
      } else if (e.code == 'weak-password') {
        throw Exception('Contraseña muy débil');
      } else if (e.code == 'invalid-email') {
        throw Exception('Email inválido');
      }
      throw Exception('Error en el registro: ${e.message}');
    } catch (e) {
      debugPrint('Error inesperado en registro: $e');
      throw Exception('Error inesperado: $e');
    }
  }

  /// Inicia sesión con email y contraseña
  Future<UserModel?> login({
    required String email,
    required String password,
  }) async {
    try {
      final emailTrimmed = email.trim();
      final passwordTrimmed = password.trim();

      if (emailTrimmed.isEmpty || passwordTrimmed.isEmpty) {
        throw Exception('Email y contraseña son requeridos');
      }

      // Autenticar en Firebase Auth
      final userCredential = await _auth.signInWithEmailAndPassword(
        email: emailTrimmed,
        password: passwordTrimmed,
      );

      final uid = userCredential.user!.uid;

      // Obtener perfil desde Firestore
      final user = await _userRepository.getUser(uid);

      if (user == null) {
        throw Exception('Perfil de usuario no encontrado');
      }

      return user;
    } on FirebaseAuthException catch (e) {
      if (e.code == 'user-not-found') {
        throw Exception('Usuario no encontrado');
      } else if (e.code == 'wrong-password') {
        throw Exception('Contraseña incorrecta');
      } else if (e.code == 'invalid-email') {
        throw Exception('Email inválido');
      } else if (e.code == 'user-disabled') {
        throw Exception('Usuario deshabilitado');
      }
      throw Exception('Error en el login: ${e.message}');
    } catch (e) {
      throw Exception('Error inesperado: $e');
    }
  }

  /// Cierra sesión
  Future<void> logout() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw Exception('Error al cerrar sesión: $e');
    }
  }

  /// Obtiene el perfil del usuario actualmente autenticado
  Future<UserModel?> getCurrentUserProfile() async {
    try {
      final user = currentUser;
      if (user == null) return null;

      return await _userRepository.getUser(user.uid);
    } catch (e) {
      throw Exception('Error al obtener perfil: $e');
    }
  }
}
