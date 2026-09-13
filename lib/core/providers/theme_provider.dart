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
  Color get borderColor =>
      _isDarkMode ? const Color(0xFF4A6448) : const Color(0xFFBFE0B0);
  Color get textStrongColor =>
      _isDarkMode ? Colors.white : const Color(0xFF234B2A);
  Color get textMutedColor =>
      _isDarkMode ? const Color(0xFFD9E9D2) : const Color(0xFF55755E);
  Color get cardShadowColor => _isDarkMode
      ? Colors.black.withValues(alpha: 0.35)
      : Colors.black.withValues(alpha: 0.08);

  List<Color> get gradientColors => _isDarkMode
      ? [
          const Color(0xFF1D2D1F).withValues(alpha: 0.50),
          const Color(0xFF243928).withValues(alpha: 0.50),
        ]
      : [
          const Color(0xFFF6F8E8).withValues(alpha: 0.50),
          const Color(0xFFE7F4E1).withValues(alpha: 0.50),
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
