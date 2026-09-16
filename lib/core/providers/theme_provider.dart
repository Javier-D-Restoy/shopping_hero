import 'dart:async';

// import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _boxName = 'settings';

  Box? _box;
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

  // Getters de colores centralizados
  Color get primaryColor =>
      _isDarkMode ? const Color(0xFF9DD388) : const Color(0xFF5E9C4C);
  Color get navPrimaryColor =>
      _isDarkMode ? const Color(0xFF9DD388) : const Color(0xFF1D1D1D);
  Color get primarySoftColor =>
      _isDarkMode ? const Color(0xFF7DBB74) : const Color(0xFF89CE80);
  Color get navPrimarySoftColor =>
      _isDarkMode ? const Color(0xFF7DBB74) : const Color(0xFF89CE80);
  Color get surface => _isDarkMode ? const Color(0xFF1F2A1E) : Colors.white;
  Color get navSurface => _isDarkMode ? const Color(0xFF1F2A1E) : const Color(0xFF9DD388);
  Color get surfaceSoft => _isDarkMode
        ? const Color(0xFF2C3A2D) : const Color(0xFFF4F8EE);
  Color get borderColor =>
      _isDarkMode ? const Color(0xFF4A6448) : const Color(0xFF9FC090);
  Color get navBorderColor =>
      _isDarkMode ? const Color(0xFF4A6448) : const Color(0xFF9FC090);
  Color get borderOwnerColor =>
      _isDarkMode ? const Color(0xFFD48E32) : const Color(0xFFD48E32);
  Color get borderSharedColor =>
      _isDarkMode ? const Color(0xFF954D97) : const Color(0xFF954D97);
  Color get textStrongColor =>
      _isDarkMode ? Colors.white : const Color(0xFF234B2A);
  // Color get textStrongColor =>
  //     _isDarkMode ? Colors.white : const Color(0xFF2F4064);
  Color get textMutedColor =>
      _isDarkMode ? const Color(0xFFD9E9D2) : const Color(0xFF55755E);
  // Color get textMutedColor =>
  //     _isDarkMode ? const Color(0xFFD9E9D2) : const Color(0xFF55755E);
  Color get dangerColor => const Color(0xFFB35C5C);
  Color get cardShadowColor => _isDarkMode
      ? Colors.black.withValues(alpha: 0.35)
      : Colors.black.withValues(alpha: 0.2);

  List<Color> get gradientColors => _isDarkMode
      ? [
          const Color(0xFF1D2D1F).withValues(alpha: 0.50),
          const Color(0xFF243928).withValues(alpha: 0.50),
        ]
      : [
          const Color(0xFFF6F8E8).withValues(alpha: 0.50),
          const Color(0xFFE7F4E1).withValues(alpha: 0.50),
        ];

  List<Color> get gradientColors2 => _isDarkMode
      ? [
          const Color(0xFF1D2D1F).withValues(alpha: 0.85),
          const Color(0xFF243928).withValues(alpha: 0.85)
        ]
      : [
          const Color(0xFFF6F8E8).withValues(alpha: 0.95),
          const Color(0xFFE7F4E1).withValues(alpha: 0.95),
        ];

  String get backgroundImagePath => _isDarkMode
      ? 'assets/images/background/Background_Dark_Image_1.jpg'
      : 'assets/images/background/Background_Image_1.jpg';

  Future<void> init() async {
    try {
      if (!Hive.isBoxOpen(_boxName)) {
        _box = await Hive.openBox(_boxName);
      }
    } catch (_) {
      _box = null;
      return;
    }

    final storedValue = _box!.get('isDarkMode');
    if (storedValue is bool) {
      _isDarkMode = storedValue;
    }
  }

  Future<void> _ensureInitialized() async {
    if (_box == null) {
      await init();
    }
  }

  Future<void> saveToStorage() async {
    if (_box == null) {
      return;
    }

    await _ensureInitialized();
    if (_box != null) {
      await _box!.put('isDarkMode', _isDarkMode);
    }
  }

  void setDarkMode(bool value) {
    if (_isDarkMode == value) return;

    _isDarkMode = value;
    notifyListeners();
    unawaited(saveToStorage());
  }
}
