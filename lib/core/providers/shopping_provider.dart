import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shopping_hero/core/models/product_model.dart';
import 'package:shopping_hero/core/services/user_repository.dart';

enum ShoppingSyncStatus { offline, syncing, synced, error }

class ShoppingProvider extends ChangeNotifier {
  ShoppingProvider({UserRepository? userRepository})
      : _userRepository = userRepository ?? UserRepository();

  // Cajas dinámicas según el entorno
  static const String _guestBoxName = 'shopping_lists_guest';
  static const String _onlineCacheBoxName = 'shopping_lists_online_cache';

  final UserRepository _userRepository;
  String? _currentUid;
  String _currentBoxName = _guestBoxName;
  Box? _box;
  bool _isOfflineMode = true;
  final Map<String, DateTime> _listUpdatedAt = {};
  final Map<String, String> _listIds = {};
  final Map<String, String> _sharedListIds = {};
  final Map<String, String> _sharedListOwners = {};
  final Map<String, DateTime> _deletedLists = {};
  ShoppingSyncStatus _syncStatus = ShoppingSyncStatus.offline;
  DateTime? _lastSyncedAt;

  final Map<String, Map<String, List<Product>>> _shoppingLists = {
    // 'Lista 1': {
    //   'active': <Product>[],
    //   'frequent': <Product>[],
    // },
  };

  String _selectedListName = 'Lista 1';

  // Getter de conveniencia
  bool get isOfflineMode => _isOfflineMode;
  ShoppingSyncStatus get syncStatus => _syncStatus;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool isSharedList(String listName) => _sharedListIds.containsKey(listName);
  bool canManageList(String listName) =>
      !isSharedList(listName) || _sharedListOwners[listName] == _currentUid;

  Future<void> shareSelectedListWithEmail(String email) async {
    if (_currentUid == null || _isOfflineMode) {
      throw Exception('Necesitas iniciar sesión para compartir una lista');
    }

    final listName = _selectedListName;
    if (isSharedList(listName)) {
      throw Exception('Esta lista ya está compartida');
    }

    final listId = await _userRepository.shareShoppingList(
      ownerUid: _currentUid!,
      listName: listName,
      recipientEmail: email,
    );
    _sharedListIds[listName] = listId;
    _sharedListOwners[listName] = _currentUid!;
    _listIds.remove(listName);
    _touchList(listName);
    notifyListeners();
    await saveToStorage(mergeCloud: false);
  }

  void _setSyncStatus(ShoppingSyncStatus status, {DateTime? syncedAt}) {
    _syncStatus = status;
    if (syncedAt != null) {
      _lastSyncedAt = syncedAt;
    }
    notifyListeners();
  }

  static List<Product> _mergeProductLists(List<Product> local, List<Product> cloud) {
    final byName = <String, Product>{};

    for (final product in [...local, ...cloud]) {
      final key = product.name.trim().toLowerCase();
      final existing = byName[key];

      if (existing == null) {
        byName[key] = product;
        continue;
      }

      final existingTimestamp = existing.lastAdded;
      final candidateTimestamp = product.lastAdded;

      final shouldReplace = candidateTimestamp.isAfter(existingTimestamp) ||
          (candidateTimestamp.isAtSameMomentAs(existingTimestamp) &&
              product.frequency > existing.frequency);

      if (shouldReplace) {
        byName[key] = product;
      }
    }

    final merged = byName.values.toList();
    merged.sort((a, b) => b.lastAdded.compareTo(a.lastAdded));
    return merged;
  }

  static Map<String, List<Product>> _mergeListCategories(
    Map<String, List<Product>> winnerList,
    Map<String, List<Product>> otherList,
  ) {
    final winnerActive = winnerList['active'] ?? <Product>[];
    final winnerFrequent = winnerList['frequent'] ?? <Product>[];
    final winnerActiveNames = winnerActive
        .map((product) => product.name.trim().toLowerCase())
        .toSet();
    final winnerFrequentNames = winnerFrequent
        .map((product) => product.name.trim().toLowerCase())
        .toSet();
    final winnerActiveIds = winnerActive.map((product) => product.id).toSet();
    final winnerFrequentIds = winnerFrequent.map((product) => product.id).toSet();

    final otherActive = (otherList['active'] ?? <Product>[])
      .where((product) =>
        !winnerFrequentNames.contains(product.name.trim().toLowerCase()) &&
        !winnerActiveIds.contains(product.id))
        .toList();
    final otherFrequent = (otherList['frequent'] ?? <Product>[])
      .where((product) =>
        !winnerActiveNames.contains(product.name.trim().toLowerCase()) &&
        !winnerFrequentIds.contains(product.id))
        .toList();

    return {
      'active': _mergeProductLists(winnerActive, otherActive),
      'frequent': _mergeProductLists(winnerFrequent, otherFrequent),
    };
  }

  static Map<String, Map<String, List<Product>>> mergeShoppingListsForSync(
    Map<String, Map<String, List<Product>>> local,
    Map<String, Map<String, List<Product>>> cloud, {
    Map<String, DateTime>? localUpdatedAt,
    Map<String, DateTime>? cloudUpdatedAt,
    Map<String, String>? localListIds,
    Map<String, String>? cloudListIds,
    Map<String, DateTime>? deletedLists,
  }) {
    final result = <String, Map<String, List<Product>>>{};
    final tombstones = deletedLists ?? {};
    final localById = <String, MapEntry<String, Map<String, List<Product>>>>{};
    final cloudById = <String, MapEntry<String, Map<String, List<Product>>>>{};
    final seenIds = <String>{};

    String resolveListId(String name, Map<String, String>? listIds) {
      final value = listIds?[name] ?? name;
      return value.trim();
    }

    for (final entry in local.entries) {
      final id = resolveListId(entry.key, localListIds);
      if (id.isNotEmpty) {
        localById[id] = entry;
      }
    }

    for (final entry in cloud.entries) {
      final id = resolveListId(entry.key, cloudListIds);
      if (id.isNotEmpty) {
        cloudById[id] = entry;
      }
    }

    final allIds = <String>{...localById.keys, ...cloudById.keys};

    for (final id in allIds) {
      seenIds.add(id);
      final localEntry = localById[id];
      final cloudEntry = cloudById[id];
      final localList = localEntry?.value ?? {'active': <Product>[], 'frequent': <Product>[]};
      final cloudList = cloudEntry?.value ?? {'active': <Product>[], 'frequent': <Product>[]};

      final localTs = localUpdatedAt?[localEntry?.key ?? id] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final cloudTs = cloudUpdatedAt?[cloudEntry?.key ?? id] ?? DateTime.fromMillisecondsSinceEpoch(0);
      final tombstoneTs = tombstones[id];

      if (tombstoneTs != null && tombstoneTs.isAfter(localTs) && tombstoneTs.isAfter(cloudTs)) {
        continue;
      }

      final winnerList = cloudTs.isAfter(localTs) ? cloudList : localList;
      final otherList = identical(winnerList, localList) ? cloudList : localList;

      final mergedCategories = _mergeListCategories(winnerList, otherList);
      final mergedActive = mergedCategories['active']!;
      final mergedFrequent = mergedCategories['frequent']!;

      final preferredName = cloudTs.isAfter(localTs)
          ? (cloudEntry?.key ?? id)
          : (localEntry?.key ?? id);

      if (mergedActive.isNotEmpty || mergedFrequent.isNotEmpty) {
        result[preferredName] = {
          'active': mergedActive,
          'frequent': mergedFrequent,
        };
      }
    }

    final fallbackLocalNames = local.keys.where((name) {
      final id = resolveListId(name, localListIds);
      return !seenIds.contains(id);
    });

    for (final listName in fallbackLocalNames) {
      final listId = resolveListId(listName, localListIds);
      final tombstoneTs = tombstones[listId];
      final localList = local[listName] ?? {'active': <Product>[], 'frequent': <Product>[]};
      final localTs = localUpdatedAt?[listName] ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (tombstoneTs != null && tombstoneTs.isAfter(localTs)) {
        continue;
      }

      final mergedActive = _mergeProductLists(localList['active'] ?? <Product>[], <Product>[]);
      final mergedFrequent = _mergeProductLists(localList['frequent'] ?? <Product>[], <Product>[]);

      if (mergedActive.isNotEmpty || mergedFrequent.isNotEmpty) {
        result[listName] = {
          'active': mergedActive,
          'frequent': mergedFrequent,
        };
      }
    }

    final fallbackCloudNames = cloud.keys.where((name) {
      final id = resolveListId(name, cloudListIds);
      return !seenIds.contains(id);
    });

    for (final listName in fallbackCloudNames) {
      final listId = resolveListId(listName, cloudListIds);
      final tombstoneTs = tombstones[listId];
      final cloudList = cloud[listName] ?? {'active': <Product>[], 'frequent': <Product>[]};
      final cloudTs = cloudUpdatedAt?[listName] ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (tombstoneTs != null && tombstoneTs.isAfter(cloudTs)) {
        continue;
      }

      final mergedActive = _mergeProductLists(cloudList['active'] ?? <Product>[], <Product>[]);
      final mergedFrequent = _mergeProductLists(cloudList['frequent'] ?? <Product>[], <Product>[]);

      if (mergedActive.isNotEmpty || mergedFrequent.isNotEmpty) {
        result[listName] = {
          'active': mergedActive,
          'frequent': mergedFrequent,
        };
      }
    }

    return result;
  }

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
    final storedListIds = _box!.get('shopping_list_ids');
    final storedDeletedLists = _box!.get('deleted_lists');

    if (storedListIds is Map) {
      for (final entry in storedListIds.entries) {
        if (entry.key is String && entry.value is String) {
          _listIds[entry.key as String] = entry.value as String;
        }
      }
    }

    if (storedDeletedLists is Map) {
      for (final entry in storedDeletedLists.entries) {
        if (entry.key is String && entry.value is int) {
          _deletedLists[entry.key as String] = DateTime.fromMillisecondsSinceEpoch(entry.value as int);
        }
      }
    }

    if (storedData is Map) {
      final restoredLists = <String, Map<String, List<Product>>>{};

      for (final entry in storedData.entries) {
        if (entry.key is! String) continue;
        final key = entry.key as String;
        final val = entry.value;

        if (val is Map) {
          final categoryMap = <String, List<Product>>{};
          for (final catEntry in val.entries) {
            if (catEntry.key is String && catEntry.value is List) {
              final productList = (catEntry.value as List)
                  .map((item) {
                    if (item is Map<String, dynamic>) {
                      return Product.fromMapHive(item);
                    }
                    return null;
                  })
                  .whereType<Product>()
                  .toList();
              categoryMap[catEntry.key as String] = productList;
            }
          }
          restoredLists[key] = categoryMap;
        }
      }

      if (restoredLists.isNotEmpty) {
        _shoppingLists
          ..clear()
          ..addAll(restoredLists);

        await _box!.put('shopping_lists', _shoppingLists);
      }

      if (_listIds.isEmpty) {
        for (final listName in _shoppingLists.keys) {
          _listIds[listName] = _listIds[listName] ?? 'list_${DateTime.now().millisecondsSinceEpoch}_${listName.hashCode}';
        }
      }

      await _box!.put('shopping_list_ids', _listIds);
      await _box!.put('deleted_lists', _deletedLists.map((key, value) => MapEntry(key, value.millisecondsSinceEpoch)));
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

  Future<void> setCurrentUser(String? uid, {required bool isOffline}) async {
    _currentUid = uid;
    _isOfflineMode = isOffline;
    _setSyncStatus(isOffline ? ShoppingSyncStatus.offline : ShoppingSyncStatus.syncing);

    if (!isOffline && uid == null) {
      _currentUid = null;
    }
  }

  Future<void> clearCurrentUser() async {
    _currentUid = null;
    _setSyncStatus(ShoppingSyncStatus.offline);
  }

  Map<String, Map<String, List<Product>>> _sanitizeForCloud(
    Map<String, Map<String, List<Product>>> source,
  ) {
    final result = <String, Map<String, List<Product>>>{};

    for (final entry in source.entries) {
      final active = entry.value['active'] ?? <Product>[];
      final frequent = entry.value['frequent'] ?? <Product>[];

      if (active.isEmpty && frequent.isEmpty) {
        continue;
      }

      result[entry.key] = {
        'active': List<Product>.from(active),
        'frequent': List<Product>.from(frequent),
      };
    }

    return result;
  }

  Future<void> _saveListsToFirestore(String uid) async {
    if (_isOfflineMode || uid.isEmpty) return;

    final ownedLists = Map<String, Map<String, List<Product>>>.fromEntries(
      _shoppingLists.entries.where((entry) => !isSharedList(entry.key)),
    );
    final sanitized = _sanitizeForCloud(ownedLists);
    await _userRepository.saveShoppingLists(
      uid: uid,
      shoppingLists: sanitized,
      listUpdatedAt: Map<String, DateTime>.from(_listUpdatedAt),
      listIds: Map<String, String>.from(_listIds),
      deletedLists: Map<String, DateTime>.from(_deletedLists),
    );

    for (final entry in _sharedListIds.entries) {
      final list = _shoppingLists[entry.key];
      if (list == null) continue;
      await _userRepository.saveSharedShoppingList(
        listId: entry.value,
        name: entry.key,
        active: list['active'] ?? <Product>[],
        frequent: list['frequent'] ?? <Product>[],
        updatedAt: _listUpdatedAt[entry.key] ?? DateTime.now(),
      );
    }
  }

  void _touchList(String listName) {
    _listUpdatedAt[listName] = DateTime.now();
  }

  Future<void> _loadListsFromFirestore(String uid) async {
    if (_isOfflineMode || uid.isEmpty) return;

    _setSyncStatus(ShoppingSyncStatus.syncing);

    try {
      final cloudLists = await _userRepository.getShoppingLists(uid);
      final sharedLists = await _userRepository.getSharedShoppingLists(uid);
      final cloudTs = await _userRepository.getShoppingListTimestamps(uid);
      final cloudListIds = await _userRepository.getShoppingListIds(uid);
      final deletedLists = await _userRepository.getDeletedShoppingListTimestamps(uid);
      final merged = mergeShoppingListsForSync(
        _shoppingLists,
        cloudLists,
        localUpdatedAt: _listUpdatedAt,
        cloudUpdatedAt: cloudTs,
        localListIds: _listIds,
        cloudListIds: cloudListIds,
        deletedLists: deletedLists,
      );

      if (merged.isNotEmpty) {
        _shoppingLists
          ..clear()
          ..addAll(merged);
      } else {
        _shoppingLists
          ..clear()
          ..addAll({
            'Lista 1': {'active': <Product>[], 'frequent': <Product>[]},
          });
      }

      for (final sharedEntry in sharedLists.entries) {
        final data = sharedEntry.value;
        final name = (data['name'] ?? sharedEntry.key).toString();
        final active = _productsFromFirestore(name, data['active']);
        final frequent = _productsFromFirestore(name, data['frequent']);
        _shoppingLists[name] = {
          'active': active,
          'frequent': frequent,
        };
        _sharedListIds[name] = sharedEntry.key;
        _sharedListOwners[name] = (data['ownerUid'] ?? '').toString();
        final updatedAt = data['updatedAt'];
        if (updatedAt is Timestamp) {
          _listUpdatedAt[name] = updatedAt.toDate();
        }
      }

      for (final entry in _shoppingLists.entries) {
        _listUpdatedAt[entry.key] = _listUpdatedAt[entry.key] ?? DateTime.now();
        _listIds[entry.key] = _listIds[entry.key] ?? 'list_${DateTime.now().millisecondsSinceEpoch}_${entry.key.hashCode}';
      }

      await _box!.put('shopping_list_ids', _listIds);
      await _box!.put('deleted_lists', _deletedLists.map((key, value) => MapEntry(key, value.millisecondsSinceEpoch)));

      _selectedListName = _shoppingLists.keys.isNotEmpty ? _shoppingLists.keys.first : 'Lista 1';
      notifyListeners();
      await saveToStorage();
    } catch (_) {
      _setSyncStatus(ShoppingSyncStatus.error);
    }
  }

  List<Product> _productsFromFirestore(String listName, dynamic rawProducts) {
    if (rawProducts is! List) return <Product>[];
    return rawProducts
        .whereType<Map<String, dynamic>>()
        .toList()
        .asMap()
        .entries
        .map((entry) => Product.fromMap('${listName}_${entry.key}', entry.value))
        .toList();
  }

  /// Cambia el entorno de datos entre invitado local y caché online.
  /// Se ejecuta al iniciar o cerrar sesión en SessionProvider.
  Future<void> switchUserEnvironment({required bool isOffline}) async {
    _isOfflineMode = isOffline;
    _setSyncStatus(isOffline ? ShoppingSyncStatus.offline : ShoppingSyncStatus.syncing);
    _currentBoxName = isOffline ? _guestBoxName : _onlineCacheBoxName;

    if (!isOffline && Hive.isBoxOpen(_onlineCacheBoxName)) {
      final cacheBox = Hive.box(_onlineCacheBoxName);
      await cacheBox.clear();
    }

    _shoppingLists
      ..clear()
      ..addAll({
        'Lista 1': {'active': <Product>[], 'frequent': <Product>[]}
      });
    _sharedListIds.clear();
    _sharedListOwners.clear();
    _listIds.clear();
    _sharedListIds.clear();
    _sharedListOwners.clear();
    _listIds['Lista 1'] = 'list_default_1';
    _deletedLists.clear();
    _selectedListName = 'Lista 1';

    await init(isOffline: isOffline);

    if (!isOffline && _currentUid != null) {
      await _loadListsFromFirestore(_currentUid!);
    }
  }

  Future<void> _ensureInitialized() async {
    if (_box == null || !_box!.isOpen) {
      await init(isOffline: _isOfflineMode);
    }
  }

  Future<void> saveToStorage({bool mergeCloud = true}) async {
    await _ensureInitialized();

    if (!_isOfflineMode && _currentUid != null && _currentUid!.isNotEmpty) {
      _setSyncStatus(ShoppingSyncStatus.syncing);
    }

    try {
      if (mergeCloud && !_isOfflineMode && _currentUid != null && _currentUid!.isNotEmpty) {
      final cloudLists = await _userRepository.getShoppingLists(_currentUid!);
      final cloudTs = await _userRepository.getShoppingListTimestamps(_currentUid!);
      final cloudListIds = await _userRepository.getShoppingListIds(_currentUid!);
      final deletedLists = await _userRepository.getDeletedShoppingListTimestamps(_currentUid!);
      final merged = mergeShoppingListsForSync(
        _shoppingLists,
        cloudLists,
        localUpdatedAt: _listUpdatedAt,
        cloudUpdatedAt: cloudTs,
        localListIds: _listIds,
        cloudListIds: cloudListIds,
        deletedLists: deletedLists,
      );
      if (merged.isNotEmpty) {
        _shoppingLists
          ..clear()
          ..addAll(merged);
      }
      }

      if (_box != null) {
      final dataToSave = <String, Map<String, List<Map<String, dynamic>>>>{};

      for (final entry in _shoppingLists.entries) {
        final listName = entry.key;
        final categories = entry.value;

        dataToSave[listName] = {};

        for (final catEntry in categories.entries) {
          final categoryName = catEntry.key;
          final products = catEntry.value;

          dataToSave[listName]![categoryName] =
              products.map((p) => p.toMapHive()).toList();
        }
      }

      await _box!.put('shopping_lists', dataToSave);
      await _box!.put('selected_list_name', _selectedListName);
      }

      if (!_isOfflineMode && _currentUid != null && _currentUid!.isNotEmpty) {
      for (final entry in _shoppingLists.entries) {
        _listUpdatedAt[entry.key] = _listUpdatedAt[entry.key] ?? DateTime.now();
        _listIds[entry.key] = _listIds[entry.key] ?? 'list_${DateTime.now().millisecondsSinceEpoch}_${entry.key.hashCode}';
      }

      await _box!.put('shopping_list_ids', _listIds);
      await _box!.put('deleted_lists', _deletedLists.map((key, value) => MapEntry(key, value.millisecondsSinceEpoch)));
      await _saveListsToFirestore(_currentUid!);
      _setSyncStatus(ShoppingSyncStatus.synced, syncedAt: DateTime.now());
      } else if (_isOfflineMode) {
        _setSyncStatus(ShoppingSyncStatus.offline);
      }
    } catch (_) {
      if (!_isOfflineMode) {
        _setSyncStatus(ShoppingSyncStatus.error);
      }
    }
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
        'Lista 1': {'active': <Product>[], 'frequent': <Product>[]}
      });
    _listIds.clear();
    _listIds['Lista 1'] = 'list_default_1';
    _deletedLists.clear();
    _selectedListName = 'Lista 1';

    notifyListeners();
  }

  // ---------------------------------------------- ][ GESTION DE LISTAS Y PRODUCTOS ][ ---------------------------------------------- //

  // ------------------------------------------------- ][ Getters ][ ------------------------------------------------- //

  String get selectedListName => _selectedListName;

  Map<String, Map<String, List<Product>>> get shoppingLists => _shoppingLists;

  Map<String, List<Product>>? getListAdd(String listName) {
    final listMap = _shoppingLists[listName];
    if (listMap == null) return null;

    return listMap;
  }

  List<Product> activeProductsForList(String listName) {
    final products = getListAdd(listName)?['active'] ?? <Product>[];
    final sorted = List<Product>.from(products);
    sorted.sort((a, b) => b.lastAdded.compareTo(a.lastAdded));
    return sorted;
  }

  List<Product> frequentProductsForList(String listName) {
    final products = getListAdd(listName)?['frequent'] ?? <Product>[];
    // Ordenar por frecuencia descendente
    final sorted = List<Product>.from(products);
    sorted.sort((a, b) => b.frequency.compareTo(a.frequency));
    return sorted;
  }

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
    _shoppingLists[uniqueName] = <String, List<Product>>{
      'active': <Product>[],
      'frequent': <Product>[],
    };
    _listIds[uniqueName] = _listIds[uniqueName] ?? 'list_${DateTime.now().millisecondsSinceEpoch}_${uniqueName.hashCode}';
    _touchList(uniqueName);

    _selectedListName = uniqueName;
    notifyListeners();
    unawaited(saveToStorage());
  }

  void renameList(String oldName, String newName) {
    if (isSharedList(oldName)) return;
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

    final reorderedLists = <String, Map<String, List<Product>>>{};
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

    final currentId = _listIds.remove(oldName);
    if (currentId != null) {
      _listIds[cleanedName] = currentId;
    }

    _touchList(cleanedName);
    _listUpdatedAt.remove(oldName);

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

  void _addActiveProductToList(String listName, String productName,
      {double? price, String? imageUrl}) {
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty) return;

    if (!_shoppingLists.containsKey(listName)) {
      _shoppingLists[listName] = <String, List<Product>>{
        'active': <Product>[],
        'frequent': <Product>[],
      };
    }

    _shoppingLists[listName]!['active'] ??= <Product>[];
    _touchList(listName);

    final activeList = _shoppingLists[listName]!['active']!;
    final existingIndex =
        activeList.indexWhere((p) => p.name.toLowerCase() == cleanedName.toLowerCase());

    if (existingIndex >= 0) {
      // Si ya existe, incrementar frecuencia
      final existing = activeList[existingIndex];
      activeList[existingIndex] = existing.copyWith(
        frequency: existing.frequency + 1,
        lastAdded: DateTime.now(),
      );
    } else {
      // Si no existe, crear nuevo
      final product = Product(
        id: '${listName}_active_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanedName,
        frequency: 1,
        price: price,
        imageUrl: imageUrl,
        lastAdded: DateTime.now(),
      );
      activeList.add(product);
    }

    notifyListeners();
    unawaited(saveToStorage());
  }

  void _addFrequentProductToList(String listName, String productName,
      {double? price, String? imageUrl}) {
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty) return;

    if (!_shoppingLists.containsKey(listName)) {
      _shoppingLists[listName] = <String, List<Product>>{
        'active': <Product>[],
        'frequent': <Product>[],
      };
    }

    _shoppingLists[listName]!['frequent'] ??= <Product>[];
    _touchList(listName);

    final frequentList = _shoppingLists[listName]!['frequent']!;
    final existingIndex =
        frequentList.indexWhere((p) => p.name.toLowerCase() == cleanedName.toLowerCase());

    if (existingIndex >= 0) {
      // Si ya existe, incrementar frecuencia
      final existing = frequentList[existingIndex];
      frequentList[existingIndex] = existing.copyWith(
        frequency: existing.frequency + 1,
        lastAdded: DateTime.now(),
      );
    } else {
      // Si no existe, crear nuevo
      final product = Product(
        id: '${listName}_frequent_${DateTime.now().millisecondsSinceEpoch}',
        name: cleanedName,
        frequency: 1,
        price: price,
        imageUrl: imageUrl,
        lastAdded: DateTime.now(),
      );
      frequentList.add(product);
    }

    notifyListeners();
    unawaited(saveToStorage());
  }

  void addActiveProductToSelectedList(String productName,
      {double? price, String? imageUrl}) {
    _addActiveProductToList(_selectedListName, productName,
        price: price, imageUrl: imageUrl);
  }

  void addFrequentProductToSelectedList(String productName,
      {double? price, String? imageUrl}) {
    _addFrequentProductToList(_selectedListName, productName,
        price: price, imageUrl: imageUrl);
  }

  void _removeActiveProductFromList(String listName, String productId) {
    if (!_shoppingLists.containsKey(listName)) {
      return;
    }

    _shoppingLists[listName]!['active']!.removeWhere((p) => p.id == productId);
    _touchList(listName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void _removeFrequentProductFromList(String listName, String productId) {
    if (!_shoppingLists.containsKey(listName)) {
      return;
    }

    _shoppingLists[listName]!['frequent']!.removeWhere((p) => p.id == productId);
    _touchList(listName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void removeActiveProductFromSelectedList(String productId) {
    _removeActiveProductFromList(_selectedListName, productId);
  }

  void moveActiveProductToFrequent(String listName, String productId) {
    final list = _shoppingLists[listName];
    if (list == null) return;

    final activeList = list['active'];
    final frequentList = list['frequent'] ??= <Product>[];
    if (activeList == null) return;

    final activeIndex = activeList.indexWhere((product) => product.id == productId);
    if (activeIndex < 0) return;

    final product = activeList.removeAt(activeIndex);
    frequentList.removeWhere((frequentProduct) => frequentProduct.id == product.id);
    frequentList.add(product);
    _touchList(listName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void moveActiveProductToFrequentSelectedList(String productId) {
    moveActiveProductToFrequent(_selectedListName, productId);
  }

  void moveFrequentProductToActive(String listName, String productId) {
    final list = _shoppingLists[listName];
    if (list == null) return;

    final frequentList = list['frequent'];
    final activeList = list['active'] ??= <Product>[];
    if (frequentList == null) return;

    final frequentIndex = frequentList.indexWhere((product) => product.id == productId);
    if (frequentIndex < 0) return;

    final product = frequentList.removeAt(frequentIndex);
    activeList.removeWhere((activeProduct) => activeProduct.id == product.id);
    activeList.add(product.copyWith(frequency: product.frequency + 1));
    _touchList(listName);
    notifyListeners();
    unawaited(saveToStorage());
  }

  void moveFrequentProductToActiveSelectedList(String productId) {
    moveFrequentProductToActive(_selectedListName, productId);
  }

  void updateProduct(
    String listName,
    String productId, {
    required String name,
    required int frequency,
    required int amount,
    double? price,
    String? imageUrl,
  }) {
    final list = _shoppingLists[listName];
    if (list == null) return;

    for (final category in ['active', 'frequent']) {
      final products = list[category];
      if (products == null) continue;

      final index = products.indexWhere((product) => product.id == productId);
      if (index < 0) continue;

      products[index] = products[index].copyWith(
        name: name,
        frequency: frequency,
        amount: amount,
        price: price,
        imageUrl: imageUrl,
      );
      _touchList(listName);
      notifyListeners();
      unawaited(saveToStorage());
      return;
    }
  }

  void deleteProduct(String listName, String productId) {
    final list = _shoppingLists[listName];
    if (list == null) return;

    var removed = false;
    for (final category in ['active', 'frequent']) {
      final products = list[category];
      if (products == null) continue;
      final previousLength = products.length;
      products.removeWhere((product) => product.id == productId);
      removed = products.length < previousLength || removed;
    }

    if (!removed) return;

    _touchList(listName);
    notifyListeners();
    unawaited(saveToStorage(mergeCloud: false));
  }

  void removeFrequentProductFromSelectedList(String productId) {
    _removeFrequentProductFromList(_selectedListName, productId);
  }

  void removeList(String listName) {
    final cleanedName = listName.trim();
    if (cleanedName.isEmpty || !_shoppingLists.containsKey(cleanedName)) {
      return;
    }

    if (!canManageList(cleanedName)) return;

    final sharedListId = _sharedListIds[cleanedName];

    final deletedId = _listIds[cleanedName];

    _shoppingLists.remove(cleanedName);

    if (sharedListId != null && _currentUid != null) {
      _sharedListIds.remove(cleanedName);
      _sharedListOwners.remove(cleanedName);
      unawaited(_userRepository.deleteSharedShoppingList(sharedListId));
    }

    if (deletedId != null) {
      _deletedLists[deletedId] = DateTime.now();
      _listIds.remove(cleanedName);
    }

    if (_selectedListName == cleanedName) {
      _selectedListName = _shoppingLists.keys.isNotEmpty
          ? _shoppingLists.keys.first
          : 'Lista 1';
    }

    _listUpdatedAt.remove(cleanedName);

    notifyListeners();
    unawaited(saveToStorage());
  }
}