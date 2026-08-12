import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ShoppingProvider extends ChangeNotifier {
  // Cajas dinámicas según el entorno
  static const String _guestBoxName = 'shopping_lists_guest';
  static const String _onlineCacheBoxName = 'shopping_lists_online_cache';

  String _currentBoxName = _guestBoxName;
  Box? _box;
  bool _isOfflineMode = true;

  final Map<String, Map<String, List<String>>> _shoppingLists = {
    'Lista 1': {
      'active': [],
      'frequent': [],
    },
  };

  String _selectedListName = 'Lista 1';

  // Getter de conveniencia
  bool get isOfflineMode => _isOfflineMode;

  // ---------------------------------------------- ][ ALMACENAMIENTO EN HIVE CE ][ ---------------------------------------------- //

  /// Inicializa la box adecuada dependiendo de si el usuario arranca en modo Offline (guest) u Online.
  Future<void> init({bool isOffline = true}) async {
    _isOfflineMode = isOffline;
    _currentBoxName = isOffline ? _guestBoxName : _onlineCacheBoxName;

    try {
      if (!Hive.isBoxOpen(_currentBoxName)) {
        _box = await Hive.openBox(_currentBoxName);
      } else {
        _box = Hive.box(_currentBoxName);
      }
    } catch (_) {
      _box = null;
    }

    if (_box == null) return;

    final storedData = _box!.get('shopping_lists');

    if (storedData is Map) {
      final restoredLists = <String, Map<String, List<String>>>{};

      for (final entry in storedData.entries) {
        if (entry.key is! String) continue;
        final key = entry.key as String;
        final val = entry.value;

        if (val is Map) {
          final categoryMap = <String, List<String>>{};
          for (final catEntry in val.entries) {
            if (catEntry.key is String && catEntry.value is List) {
              categoryMap[catEntry.key as String] = (catEntry.value as List)
                  .map((item) => item.toString())
                  .toList();
            }
          }
          restoredLists[key] = categoryMap;
        } else if (val is List) {
          final items = val.map((item) => item.toString()).toList();
          restoredLists[key] = {'General': items};
        }
      }

      if (restoredLists.isNotEmpty) {
        _shoppingLists
          ..clear()
          ..addAll(restoredLists);

        await _box!.put('shopping_lists', _shoppingLists);
      }
    }

    final storedSelectedList = _box!.get('selected_list_name');
    if (storedSelectedList is String &&
        _shoppingLists.containsKey(storedSelectedList)) {
      _selectedListName = storedSelectedList;
    } else if (_shoppingLists.isNotEmpty) {
      _selectedListName = _shoppingLists.keys.first;
    }

    notifyListeners();
  }

  /// Cambia el entorno de datos entre invitado local y caché online.
  /// Se ejecuta al iniciar o cerrar sesión en SessionProvider.
  Future<void> switchUserEnvironment({required bool isOffline}) async {
    // Si ya estamos en la caja correspondiente, no rehacemos nada
    if (_isOfflineMode == isOffline && _box != null && _box!.isOpen) return;

    // Si pasamos a Online o cambiamos de cuenta online, vaciamos la caché online previa
    if (!isOffline && Hive.isBoxOpen(_onlineCacheBoxName)) {
      final cacheBox = Hive.box(_onlineCacheBoxName);
      await cacheBox.clear();
    }

    // Reiniciamos las listas locales en memoria antes de abrir la nueva caja
    _shoppingLists
      ..clear()
      ..addAll({
        'Lista 1': {'active': [], 'frequent': []}
      });
    _selectedListName = 'Lista 1';

    await init(isOffline: isOffline);

    // FUTURO CON FIREBASE:
    // Si (!isOffline), aquí descargaremos la información fresca del usuario desde Firebase Firestore
    // y poblaremos la caché local (`_onlineCacheBoxName`).
  }

  Future<void> _ensureInitialized() async {
    if (_box == null || !_box!.isOpen) {
      await init(isOffline: _isOfflineMode);
    }
  }

  Future<void> saveToStorage() async {
    await _ensureInitialized();
    if (_box != null) {
      await _box!.put(
        'shopping_lists',
        Map<String, Map<String, List<String>>>.from(_shoppingLists),
      );
      await _box!.put('selected_list_name', _selectedListName);
    }

    // FUTURO CON FIREBASE:
    // Si !_isOfflineMode, intentaremos enviar los cambios pendientes a Firestore.
    // Si falla por falta de red, la caché local ya tendrá los cambios guardados para sincronizar después.
  }

  Future<void> resetGuestData() async { // Limpiar caché de las Listas de Compra. El método de la sesión es "resetLocalProfile()"
    if (Hive.isBoxOpen(_guestBoxName)) {
      final guestBox = Hive.box(_guestBoxName);
      await guestBox.clear();
    }

    // Reseteamos el estado en memoria
    _shoppingLists
      ..clear()
      ..addAll({
        'Lista 1': {'active': [], 'frequent': []}
      });
    _selectedListName = 'Lista 1';

    notifyListeners();
  }

  // ---------------------------------------------- ][ GESTION DE LISTAS Y PRODUCTOS ][ ---------------------------------------------- //

  // ------------------------------------------------- ][ Getters ][ ------------------------------------------------- //

  String get selectedListName => _selectedListName;

  Map<String, Map<String, List<String>>> get shoppingLists => _shoppingLists;

  Map<String, List<String>>? getListAdd(String listName) {
    final listMap = _shoppingLists[listName];
    if (listMap == null) return null;

    return listMap;
  }

  List<String> activeProductsForList(String listName) =>
      getListAdd(listName)?['active'] ?? <String>[];

  List<String> frequentProductsForList(String listName) =>
      getListAdd(listName)?['frequent'] ?? <String>[];

  // -------------------------------------------- ][ Selección/gestión de Listas ][ -------------------------------------------- //

  void selectList(String listName) {
    if (!_shoppingLists.containsKey(listName)) {
      return;
    }

    _selectedListName = listName;
    notifyListeners();
    unawaited(saveToStorage());
  }

  void createList({String? name}) {
    final cleanedName = name?.trim() ?? '';
    final String finalName;

    if (cleanedName.isEmpty) {
      finalName = 'Lista ${_shoppingLists.length + 1}';
    } else {
      finalName = cleanedName;
    }

    final String uniqueName = _getUniqueListName(finalName);
    _shoppingLists[uniqueName] = <String, List<String>>{
      'active': <String>[],
      'frequent': <String>[],
    };

    _selectedListName = uniqueName;
    notifyListeners();
    unawaited(saveToStorage());
  }

  void renameList(String oldName, String newName) {
    final cleanedName = newName.trim();
    if (cleanedName.isEmpty || !_shoppingLists.containsKey(oldName)) {
      return;
    }

    if (oldName == cleanedName) {
      return;
    }

    if (_shoppingLists.containsKey(cleanedName)) {
      return;
    }

    final products = getListAdd(oldName);

    if (products == null) {
      return;
    }

    final reorderedLists = <String, Map<String, List<String>>>{};
    var inserted = false;

    for (final entry in _shoppingLists.entries) {
      if (entry.key == oldName) {
        reorderedLists[cleanedName] = products;
        inserted = true;
        continue;
      }

      reorderedLists[entry.key] = entry.value;
    }

    if (!inserted) {
      reorderedLists[cleanedName] = products;
    }

    _shoppingLists
      ..clear()
      ..addAll(reorderedLists);

    if (_selectedListName == oldName) {
      _selectedListName = cleanedName;
    }

    notifyListeners();
    unawaited(saveToStorage());
  }

  String _getUniqueListName(String baseName) {
    if (!_shoppingLists.containsKey(baseName)) {
      return baseName;
    }

    var counter = 2;
    while (_shoppingLists.containsKey('$baseName ($counter)')) {
      counter++;
    }

    return '$baseName ($counter)';
  }

  // -------------------------------------------- ][ Añadir/Quitar Productos ][ --------------------------------------------- //

  void _addActiveProductToList(String listName, String productName) {
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty) return;

    if (!_shoppingLists.containsKey(listName)) {
      _shoppingLists[listName] = <String, List<String>>{
        'active': <String>[],
        'frequent': <String>[],
      };
    }

    _shoppingLists[listName]!['active'] ??= <String>[];

    final activeList = _shoppingLists[listName]!['active']!;

    if (activeList.contains(cleanedName)) return;

    activeProductsForList(listName).add(cleanedName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void _addFrequentProductToList(String listName, String productName) {
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty) return;

    if (!_shoppingLists.containsKey(listName)) {
      _shoppingLists[listName] = <String, List<String>>{
        'active': <String>[],
        'frequent': <String>[],
      };
    }

    _shoppingLists[listName]!['frequent'] ??= <String>[];

    final frequentList = _shoppingLists[listName]!['frequent']!;

    if (frequentList.contains(cleanedName)) return;

    frequentProductsForList(listName).add(cleanedName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void addActiveProductToSelectedList(String productName) {
    _addActiveProductToList(_selectedListName, productName);
  }

  void addFrequentProductToSelectedList(String productName) {
    _addFrequentProductToList(_selectedListName, productName);
  }

  void _removeActiveProductFromList(String listName, String productName) {
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty || !_shoppingLists.containsKey(listName)) {
      return;
    }

    activeProductsForList(listName).remove(cleanedName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void _removeFrequentProductFromList(String listName, String productName) {
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty || !_shoppingLists.containsKey(listName)) {
      return;
    }

    frequentProductsForList(listName).remove(cleanedName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void removeActiveProductFromSelectedList(String productName) {
    _removeActiveProductFromList(_selectedListName, productName);
  }

  void removeFrequentProductFromSelectedList(String productName) {
    _removeFrequentProductFromList(_selectedListName, productName);
  }

  void removeList(String listName) {
    final cleanedName = listName.trim();
    if (cleanedName.isEmpty || !_shoppingLists.containsKey(cleanedName)) {
      return;
    }

    _shoppingLists.remove(cleanedName);

    if (_selectedListName == cleanedName) {
      _selectedListName = _shoppingLists.keys.isNotEmpty
          ? _shoppingLists.keys.first
          : 'Lista 1';
    }

    notifyListeners();
    unawaited(saveToStorage());
  }
}