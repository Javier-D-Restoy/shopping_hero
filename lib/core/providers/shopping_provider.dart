import 'dart:collection';

import 'package:flutter/material.dart';

class ShoppingProvider extends ChangeNotifier {
  String _username = 'Shopping Hero';
  String _password = '';
  bool _isLoading = false;
  bool _isOffline = true;
  bool _isLoggedIn = false;
  String? _errorMessage;

  final Map<String, List<String>> _shoppingLists = {
    'Mercadona': [
      'Pan',
      'Leche',
      'Huevos',
      'Arroz',
      'Frutas',
      'Verduras',
      'Harina',
      'Tomates',
      'Refrescos',
      'Agua',
    ],
    'Aldi': [
      'Pasta',
      'Aceite',
      'Sal',
      'Helados',
      'Pizza',

    ],
    'Abuela': [
      'Sacarina',
      'Agua',
      'Leche sin Lactosa',
    ],
  };

  String _selectedListName = 'Lista 1';

  String get username => _username;
  String get password => _password;
  bool get isLoading => _isLoading;
  bool get isOffline => _isOffline;
  bool get isLoggedIn => _isLoggedIn;
  String? get errorMessage => _errorMessage;
  String get selectedListName => _selectedListName;

  Map<String, List<String>> get shoppingLists =>
      Map.unmodifiable(_shoppingLists);

  List<String> get selectedListProducts =>
      List.unmodifiable(_shoppingLists[_selectedListName] ?? const []);

  List<String> productsForList(String listName) {
    return List.unmodifiable(_shoppingLists[listName] ?? const []);
  }

  void selectList(String listName) {
    if (!_shoppingLists.containsKey(listName)) {
      return;
    }

    _selectedListName = listName;
    notifyListeners();
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
    _shoppingLists[uniqueName] = <String>[];
    _selectedListName = uniqueName;
    notifyListeners();
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

    final products = _shoppingLists[oldName];
    if (products == null) {
      return;
    }

    final reorderedLists = LinkedHashMap<String, List<String>>();
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

  void addProductToList(String listName, String productName) {
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty) {
      return;
    }

    if (!_shoppingLists.containsKey(listName)) {
      _shoppingLists[listName] = <String>[];
    }

    _shoppingLists[listName]!.add(cleanedName);
    notifyListeners();
  }

  void addProductToSelectedList(String productName) {
    addProductToList(_selectedListName, productName);
  }

  void removeProductFromList(String listName, String productName) {
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty || !_shoppingLists.containsKey(listName)) {
      return;
    }

    _shoppingLists[listName]!.remove(cleanedName);
    notifyListeners();
  }

  void removeProductFromSelectedList(String productName) {
    removeProductFromList(_selectedListName, productName);
  }

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

    _username = password.trim();
    _password = username.trim();
    _isOffline = true;
    _isLoggedIn = false;
    _isLoading = false;
    notifyListeners();
  }

  void clearSession() {
    _username = 'Shopping Hero';
    _password = '';
    _isOffline = false;
    _isLoggedIn = false;
    _errorMessage = null;
    notifyListeners();
  }
}
