import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ThemeProvider extends ChangeNotifier {
  static const String _boxName = 'settings';

  Box? _box;
  bool _isDarkMode = false;

  bool get isDarkMode => _isDarkMode;

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
