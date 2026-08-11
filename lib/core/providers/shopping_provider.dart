import 'dart:async';

import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';

class ShoppingProvider extends ChangeNotifier {
  static const String _boxName =
      'shopping_lists'; // Hive CE. Box para Shopping Provider

  Box? _box;
  String _username = 'Shopping Hero';
  String _password = '';
  bool _isLoading = false;
  bool _isOffline = true;
  bool _isLoggedIn = false;
  String? _errorMessage;

  // final Map<String, Map<String, List<String>>> _shoppingLists = {
  //   'Mercadona': {
  //     'active' : ['Pan', 'Leche', 'Huevos', 'Arroz', 'Frutas', 'Verduras', 'Harina', 'Tomates', 'Refrescos', 'Agua',],
  //     'frequent' : ['Patatas',],
  //   },
  //   'Aldi' : {
  //     'active' : ['Pasta', 'Aceite', 'Sal', 'Helados', 'Pizza'],
  //     'frequent' : [],
  //   }
  // };

  final Map<String, Map<String, List<String>>> _shoppingLists = {
    'Lista 1': {
      'active': [],
      'frequent': [],
    },
  };

  // final Map<String, Map<String, List<String>>> _shoppingLists = {};

  String _selectedListName = 'Lista 1';

  String get username => _username;
  String get password => _password;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;
  String get selectedListName => _selectedListName;

  // ---------------------------------------------- ][ ALMACENAMIENTO EN HIVE CE ][ ---------------------------------------------- //

  // Future<void> init() async {
  //   try {
  //     if (!Hive.isBoxOpen(_boxName)) {
  //       _box = await Hive.openBox(_boxName);
  //     }
  //   } catch (_) {
  //     _box = null;
  //   }

  //   final storedLists = _box!.get('shopping_lists');
  //   if (storedLists is Map) {
  //     final restoredLists = <String, List<String>>{};
  //     for (final entry in storedLists.entries) {
  //       if (entry.key is String && entry.value is List) {
  //         restoredLists[entry.key as String] = (entry.value as List)
  //             .map((item) => item.toString())
  //             .toList();
  //       }
  //     }
  //     if (restoredLists.isNotEmpty) {
  //       _shoppingLists
  //         ..clear()
  //         ..addAll(restoredLists);
  //     }
  //   }

  //   final storedSelectedList = _box!.get('selected_list_name');
  //   if (storedSelectedList is String &&
  //       _shoppingLists.containsKey(storedSelectedList)) {
  //     _selectedListName = storedSelectedList;
  //   } else if (_shoppingLists.isNotEmpty) {
  //     _selectedListName = _shoppingLists.keys.first;
  //   }
  // }

  Future<void> init() async {
  try {
    if (!Hive.isBoxOpen(_boxName)) {
      _box = await Hive.openBox(_boxName);
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
        // --- NUEVA ESTRUCTURA: Map<String, Map<String, List<String>>> --- //
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
        // === MIGRACIÓN / COMPATIBILIDAD CON ESTRUCTURA ANTIGUA: Map<String, List<String>> ===
        // Convierte la lista previa asignándole una categoría por defecto (ej. "General")
        final items = val.map((item) => item.toString()).toList();
        restoredLists[key] = {'General': items};
      }
    }

    if (restoredLists.isNotEmpty) {
      _shoppingLists
        ..clear()
        ..addAll(restoredLists);

      // Opcional: guarda de inmediato la migración para sobreescribir la estructura antigua en Hive
      await _box!.put('shopping_lists', _shoppingLists);
    }
  }

  // Restaurar o inicializar el nombre de la lista seleccionada
  final storedSelectedList = _box!.get('selected_list_name');
  if (storedSelectedList is String &&
      _shoppingLists.containsKey(storedSelectedList)) {
    _selectedListName = storedSelectedList;
  } else if (_shoppingLists.isNotEmpty) {
    _selectedListName = _shoppingLists.keys.first;
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
      await _box!.put(
        'shopping_lists',
        Map<String, Map<String, List<String>>>.from(_shoppingLists),
      );
      await _box!.put('selected_list_name', _selectedListName);
    }
  }

  // ---------------------------------------------- ][ GESTION DE LISTAS Y PRODUCTOS ][ ---------------------------------------------- //

  // ------------------------------------------------- ][ Gettes ][  ------------------------------------------------- //

  // Map<String, List<String>> get shoppingLists =>
  //     Map.unmodifiable(_shoppingLists);
  
  Map<String, Map<String, List<String>>> get shoppingLists =>  // CONVERSION a Map de String + (Map de String + List de String)
      _shoppingLists; 

  Map<String, List<String>>? getListAdd(String listName) {  // OBTENER PRODUCTOS (ACTIVOS + FRECUENTES) DE UNA LISTA
    final listMap = _shoppingLists[listName];
    if (listMap == null) return null;
    
    return listMap;
  }

  // List<String> get selectedListProducts =>
  //     List.unmodifiable(_shoppingLists[_selectedListName] ?? const []);

  // List<String> productsForList(String listName) {
  //   return List.unmodifiable(_shoppingLists[listName] ?? const []);
  // }

  List<String> activeProductsForList(String listName) =>
      // List.unmodifiable(getListAdd(listName)?['active'] ?? const []); // OBTENER PRODUCTOS ACTIVOS DE UNA LISTA
      getListAdd(listName)?['active'] ?? <String>[];

  List<String> frequentProductsForList(String listName) =>
      // List.unmodifiable(getListAdd(listName)?['frequent'] ?? const []); // OBTENER PRODUCTOS FREQUENTES DE UNA LISTA
      getListAdd(listName)?['frequent'] ?? <String>[];


  // -------------------------------------------- ][ Seleccion/gestion de Listas ][ -------------------------------------------- //      

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
    // _shoppingLists[uniqueName] = <String>[];
    _shoppingLists[uniqueName] = <String, List<String>>{ // Lista Activos + Frecuentes Actualizada.
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

    final products =  getListAdd(oldName);

    if (products == null) { // <-- Lista Activos + Frecuentes.
      return;
    }

    final reorderedLists = <String, Map<String, List<String>>>{};  // Lista Activos + Frequentes Actualizada
    var inserted = false;

    for (final entry in _shoppingLists.entries) { // Lista Activos + Frequentes Actualizada
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

    _shoppingLists // Lista Activos + Frequentes Actualizada
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

  void _addActiveProductToList(String listName, String productName) {  // Lista Actualizada: Active + Frequent
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty) return;

    // Si no existe la tienda/lista, la crea con las categorías por defecto
    if (!_shoppingLists.containsKey(listName)) {
      _shoppingLists[listName] = <String, List<String>>{
        'active': <String>[],
        'frequent': <String>[],
      };
    }

    // Asegura que la subclave 'active' exista
    _shoppingLists[listName]!['active'] ??= <String>[];

    final activeList = _shoppingLists[listName]!['active']!;

    if (activeList.contains(cleanedName)) return;

    activeProductsForList(listName).add(cleanedName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void _addFrequentProductToList(String listName, String productName) {  // Lista Actualizada: Active + Frequent
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty) return;

    if (!_shoppingLists.containsKey(listName)) {
      _shoppingLists[listName] = <String, List<String>>{
        'active': <String>[],
        'frequent': <String>[],
      };
    }

    // Asegura que la subclave 'frequent' exista
    _shoppingLists[listName]!['frequent'] ??= <String>[];

    final frequentList = _shoppingLists[listName]!['frequent']!;

    if (frequentList.contains(cleanedName)) return;

    frequentProductsForList(listName).add(cleanedName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void addActiveProductToSelectedList(String productName) {  // Lista Actualizada: Active + Frequent
    _addActiveProductToList(_selectedListName, productName);
  }

  void addFrequentProductToSelectedList(String productName) {  // Lista Actualizada: Active + Frequent
    _addFrequentProductToList(_selectedListName, productName);
  }

  void _removeActiveProductFromList(String listName, String productName) { // Lista Actualizada: Active + Frequent
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty || !_shoppingLists.containsKey(listName)) {
      return;
    }

    activeProductsForList(listName).remove(cleanedName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void _removeFrequentProductFromList(String listName, String productName) { // Lista Actualizada: Active + Frequent
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty || !_shoppingLists.containsKey(listName)) {
      return;
    }

    frequentProductsForList(listName).remove(cleanedName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void removeActiveProductFromSelectedList(String productName) { // Lista Actualizada: Active + Frequent
    _removeActiveProductFromList(_selectedListName, productName);
  }

  void removeFrequentProductFromSelectedList(String productName) { // Lista Actualizada: Active + Frequent
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

  // ------------------------------------------------- ][ Sesion ][  ------------------------------------------------- //

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

    _username = password.trim();
    _password = username.trim();
    _isOffline = true;
    _isLoggedIn = false;
    _isLoading = false;
    notifyListeners();
    unawaited(saveToStorage());
  }

  void clearSession() {
    _username = 'Shopping Hero';
    _password = '';
    _isOffline = false;
    _isLoggedIn = false;
    _errorMessage = null;
    notifyListeners();
    unawaited(saveToStorage());
  }

  void changeUsername(String newName) {
    _username = newName;
    notifyListeners();
    unawaited(saveToStorage());
  }
}
