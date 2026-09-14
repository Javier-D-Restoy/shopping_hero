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
  final Map<String, Map<String, DateTime>> _deletedSharedProducts = {};
  final Map<String, DateTime> _deletedLists = {};
  final Map<String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>
      _sharedListSubscriptions = {};
  DateTime? _lastAutomaticSharedSync;
  Timer? _automaticSharedSyncTimer;
  bool _automaticSharedSyncInProgress = false;
  final Map<String, Map<String, dynamic>> _pendingSharedSnapshots = {};
  ShoppingSyncStatus _syncStatus = ShoppingSyncStatus.offline;
  DateTime? _lastSyncedAt;

  final Map<String, Map<String, List<Product>>> _shoppingLists = {};

  String _selectedListName = '';

  // Getter de conveniencia
  bool get isOfflineMode => _isOfflineMode;
  ShoppingSyncStatus get syncStatus => _syncStatus;
  DateTime? get lastSyncedAt => _lastSyncedAt;
  bool isSharedList(String listName) => _sharedListIds.containsKey(listName);
  String? sharedListIdFor(String listName) => _sharedListIds[listName];
  bool canManageList(String listName) =>
      !isSharedList(listName) || _sharedListOwners[listName] == _currentUid;

  @override
  void dispose() {
    _automaticSharedSyncTimer?.cancel();
    for (final subscription in _sharedListSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _sharedListSubscriptions.clear();
    super.dispose();
  }

  Future<void> leaveSharedList(String listName) async {
    if (_currentUid == null) {
      throw Exception(
        'Necesitas iniciar sesión para desvincularte de la lista',
      );
    }

    final cleanedName = listName.trim();
    final sharedListId = _sharedListIds[cleanedName];

    if (sharedListId == null) {
      return;
    }

    if (_sharedListOwners[cleanedName] == _currentUid) {
      throw Exception('El propietario no puede desvincularse de la lista');
    }

    await _userRepository.removeMemberFromSharedList(
      listId: sharedListId,
      uid: _currentUid!,
    );

    _shoppingLists.remove(cleanedName);
    _sharedListIds.remove(cleanedName);
    _sharedListOwners.remove(cleanedName);
    _deletedSharedProducts.remove(sharedListId);
    _listUpdatedAt.remove(cleanedName);
    _listIds.remove(cleanedName);

    if (_selectedListName == cleanedName) {
      _selectedListName = _shoppingLists.keys.isNotEmpty
          ? _shoppingLists.keys.first
          : '';
    }

    notifyListeners();
    await saveToStorage(mergeCloud: false);
  }

  Future<void> shareSelectedListWithEmail(String email) async {
    if (_currentUid == null || _isOfflineMode) {
      throw Exception('Necesitas iniciar sesión para compartir una lista');
    }

    final listName = _selectedListName;
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
    await _syncSharedListListeners();
  }

  void _setSyncStatus(ShoppingSyncStatus status, {DateTime? syncedAt}) {
    _syncStatus = status;
    if (syncedAt != null) {
      _lastSyncedAt = syncedAt;
    }
    notifyListeners();
  }

  static List<Product> _mergeProductLists(
    List<Product> local,
    List<Product> cloud,
  ) {
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

      final shouldReplace =
          candidateTimestamp.isAfter(existingTimestamp) ||
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
    final winnerFrequentIds = winnerFrequent
        .map((product) => product.id)
        .toSet();

    final otherActive = (otherList['active'] ?? <Product>[])
        .where(
          (product) =>
              !winnerFrequentNames.contains(
                product.name.trim().toLowerCase(),
              ) &&
              !winnerActiveIds.contains(product.id),
        )
        .toList();
    final otherFrequent = (otherList['frequent'] ?? <Product>[])
        .where(
          (product) =>
              !winnerActiveNames.contains(product.name.trim().toLowerCase()) &&
              !winnerFrequentIds.contains(product.id),
        )
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
      final localList =
          localEntry?.value ?? {'active': <Product>[], 'frequent': <Product>[]};
      final cloudList =
          cloudEntry?.value ?? {'active': <Product>[], 'frequent': <Product>[]};

      final localTs =
          localUpdatedAt?[localEntry?.key ?? id] ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final cloudTs =
          cloudUpdatedAt?[cloudEntry?.key ?? id] ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final tombstoneTs = tombstones[id];

      if (tombstoneTs != null &&
          tombstoneTs.isAfter(localTs) &&
          tombstoneTs.isAfter(cloudTs)) {
        continue;
      }

      final Map<String, List<Product>> chosenList;
      final String preferredName;

      if (cloudTs.isAfter(localTs)) {
        chosenList = cloudList;
        preferredName = cloudEntry?.key ?? id;
      } else if (localTs.isAfter(cloudTs)) {
        chosenList = localList;
        preferredName = localEntry?.key ?? id;
      } else {
        chosenList = _mergeListCategories(localList, cloudList);
        preferredName = cloudEntry?.key ?? (localEntry?.key ?? id);
      }

      // Se conserva la lista aunque esté vacía, para que exista en ambos repositorios desde su creación.
      result[preferredName] = {
        'active': List<Product>.from(chosenList['active'] ?? <Product>[]),
        'frequent': List<Product>.from(chosenList['frequent'] ?? <Product>[]),
      };
    }

    final fallbackLocalNames = local.keys.where((name) {
      final id = resolveListId(name, localListIds);
      return !seenIds.contains(id);
    });

    for (final listName in fallbackLocalNames) {
      final listId = resolveListId(listName, localListIds);
      final tombstoneTs = tombstones[listId];
      final localList =
          local[listName] ?? {'active': <Product>[], 'frequent': <Product>[]};
      final localTs =
          localUpdatedAt?[listName] ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (tombstoneTs != null && tombstoneTs.isAfter(localTs)) {
        continue;
      }

      final mergedActive = _mergeProductLists(
        localList['active'] ?? <Product>[],
        <Product>[],
      );
      final mergedFrequent = _mergeProductLists(
        localList['frequent'] ?? <Product>[],
        <Product>[],
      );

      result[listName] = {'active': mergedActive, 'frequent': mergedFrequent};
    }

    final fallbackCloudNames = cloud.keys.where((name) {
      final id = resolveListId(name, cloudListIds);
      return !seenIds.contains(id);
    });

    for (final listName in fallbackCloudNames) {
      final listId = resolveListId(listName, cloudListIds);
      final tombstoneTs = tombstones[listId];
      final cloudList =
          cloud[listName] ?? {'active': <Product>[], 'frequent': <Product>[]};
      final cloudTs =
          cloudUpdatedAt?[listName] ?? DateTime.fromMillisecondsSinceEpoch(0);

      if (tombstoneTs != null && tombstoneTs.isAfter(cloudTs)) {
        continue;
      }

      final mergedActive = _mergeProductLists(
        cloudList['active'] ?? <Product>[],
        <Product>[],
      );
      final mergedFrequent = _mergeProductLists(
        cloudList['frequent'] ?? <Product>[],
        <Product>[],
      );

      result[listName] = {'active': mergedActive, 'frequent': mergedFrequent};
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
    final storedSharedListIds = _box!.get('shared_list_ids');
    final storedSharedListOwners = _box!.get('shared_list_owners');
    final storedDeletedSharedProducts = _box!.get('deleted_shared_products');

    if (storedSharedListIds is Map) {
      for (final entry in storedSharedListIds.entries) {
        if (entry.key is String && entry.value is String) {
          _sharedListIds[entry.key as String] = entry.value as String;
        }
      }
    }

    if (storedSharedListOwners is Map) {
      for (final entry in storedSharedListOwners.entries) {
        if (entry.key is String && entry.value is String) {
          _sharedListOwners[entry.key as String] = entry.value as String;
        }
      }
    }

    if (storedDeletedSharedProducts is Map) {
      for (final entry in storedDeletedSharedProducts.entries) {
        if (entry.key is! String || entry.value is! Map) continue;
        final deletedProducts = <String, DateTime>{};
        for (final productEntry in (entry.value as Map).entries) {
          final value = productEntry.value;
          DateTime? deletedAt;
          if (value is int) {
            deletedAt = DateTime.fromMillisecondsSinceEpoch(value);
          } else if (value is Timestamp) {
            deletedAt = value.toDate();
          }
          if (productEntry.key is String && deletedAt != null) {
            deletedProducts[productEntry.key as String] = deletedAt;
          }
        }
        _deletedSharedProducts[entry.key as String] = deletedProducts;
      }
    }

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
          _deletedLists[entry.key as String] =
              DateTime.fromMillisecondsSinceEpoch(entry.value as int);
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
                    if (item is Map) {
                      final map = item.map((k, v) => MapEntry(k.toString(), v));
                      return Product.fromMapHive(map);
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

        final dataToSave = <String, Map<String, List<Map<String, dynamic>>>>{};
        for (final entry in _shoppingLists.entries) {
          dataToSave[entry.key] = {
            for (final catEntry in entry.value.entries)
              catEntry.key: catEntry.value.map((p) => p.toMapHive()).toList(),
          };
        }

        await _box!.put('shopping_lists', dataToSave);
      }

      if (_listIds.isEmpty) {
        for (final listName in _shoppingLists.keys) {
          _listIds[listName] =
              _listIds[listName] ??
              'list_${DateTime.now().millisecondsSinceEpoch}_${listName.hashCode}';
        }
      }

      await _box!.put('shopping_list_ids', _listIds);
      await _box!.put(
        'deleted_lists',
        _deletedLists.map(
          (key, value) => MapEntry(key, value.millisecondsSinceEpoch),
        ),
      );
    }

    final storedSelectedList = _box!.get('selected_list_name');
    if (storedSelectedList is String &&
        _shoppingLists.containsKey(storedSelectedList)) {
      _selectedListName = storedSelectedList;
    } else if (_shoppingLists.isNotEmpty) {
      _selectedListName = _shoppingLists.keys.first;
    } else {
      _selectedListName = '';
    }

    notifyListeners();
  }

  Future<void> setCurrentUser(String? uid, {required bool isOffline}) async {
    _currentUid = uid;
    _isOfflineMode = isOffline;
    _setSyncStatus(
      isOffline ? ShoppingSyncStatus.offline : ShoppingSyncStatus.syncing,
    );

    if (!isOffline && uid == null) {
      _currentUid = null;
    }
  }

  Future<void> clearCurrentUser() async {
    await _cancelSharedListListeners();
    _pendingSharedSnapshots.clear();
    _currentUid = null;
    _setSyncStatus(ShoppingSyncStatus.offline);
  }

  // Se conservan también las listas vacías: deben sincronizarse en cuanto se crean, no solo al añadir productos.
  Map<String, Map<String, List<Product>>> _sanitizeForCloud(
    Map<String, Map<String, List<Product>>> source,
  ) {
    final result = <String, Map<String, List<Product>>>{};

    for (final entry in source.entries) {
      final active = entry.value['active'] ?? <Product>[];
      final frequent = entry.value['frequent'] ?? <Product>[];

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
        deletedProductTimestamps: _deletedSharedProducts[entry.value],
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
      await saveToStorage(mergeCloud: true);

      if (_shoppingLists.isNotEmpty) {
        if (!_shoppingLists.containsKey(_selectedListName)) {
          _selectedListName = _shoppingLists.keys.first;
        }
      } else {
        _selectedListName = '';
      }

      await _syncSharedListListeners();
      notifyListeners();
    } catch (_) {
      _setSyncStatus(ShoppingSyncStatus.error);
    }
  }

  Future<void> refreshFromCloud() async {
    if (_isOfflineMode || _currentUid == null || _currentUid!.isEmpty) {
      return;
    }

    await _loadListsFromFirestore(_currentUid!);
  }

  Future<void> _syncSharedListListeners() async {
    if (_isOfflineMode || _currentUid == null) {
      await _cancelSharedListListeners();
      return;
    }

    final activeIds = _sharedListIds.values.toSet();
    for (final entry in _sharedListSubscriptions.entries.toList()) {
      if (!activeIds.contains(entry.key)) {
        await entry.value.cancel();
        _sharedListSubscriptions.remove(entry.key);
      }
    }

    for (final listId in activeIds) {
      if (_sharedListSubscriptions.containsKey(listId)) continue;

      try {
        final subscription = FirebaseFirestore.instance
            .collection('sharedShoppingLists')
            .doc(listId)
            .snapshots()
            .listen(_onSharedListSnapshot);
        _sharedListSubscriptions[listId] = subscription;
      } catch (_) {
        // El listener se reintentará en el siguiente refresco o cambio de entorno.
      }
    }
  }

  Future<void> _cancelSharedListListeners() async {
    _automaticSharedSyncTimer?.cancel();
    _automaticSharedSyncTimer = null;
    for (final subscription in _sharedListSubscriptions.values) {
      await subscription.cancel();
    }
    _sharedListSubscriptions.clear();
  }

  void _onSharedListSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    if (!snapshot.exists || snapshot.data() == null || _isOfflineMode) return;

    _pendingSharedSnapshots[snapshot.id] = snapshot.data()!;

    final now = DateTime.now();
    final lastSync = _lastAutomaticSharedSync;
    if (lastSync != null && now.difference(lastSync) < const Duration(seconds: 5)) {
      _automaticSharedSyncTimer ??= Timer(
        const Duration(seconds: 5),
        _runAutomaticSharedSync,
      );
      return;
    }

    unawaited(_runAutomaticSharedSync());
  }

  Future<void> _runAutomaticSharedSync() async {
    _automaticSharedSyncTimer = null;
    if (_automaticSharedSyncInProgress || _isOfflineMode) return;

    final now = DateTime.now();
    final lastSync = _lastAutomaticSharedSync;
    if (lastSync != null && now.difference(lastSync) < const Duration(seconds: 5)) {
      _automaticSharedSyncTimer = Timer(
        const Duration(seconds: 5),
        _runAutomaticSharedSync,
      );
      return;
    }

    _automaticSharedSyncInProgress = true;
    _lastAutomaticSharedSync = now;
    try {
      final snapshots = Map<String, Map<String, dynamic>>.from(
        _pendingSharedSnapshots,
      );
      _pendingSharedSnapshots.clear();
      for (final entry in snapshots.entries) {
        _applySharedListSnapshot(entry.key, entry.value);
      }
      await _persistHiveCache();
      notifyListeners();
    } finally {
      _automaticSharedSyncInProgress = false;
    }
  }

  void _applySharedListSnapshot(String listId, Map<String, dynamic> data) {
    final cloudName = (data['name'] ?? listId).toString();
    String? localName;
    for (final entry in _sharedListIds.entries) {
      if (entry.value == listId) {
        localName = entry.key;
        break;
      }
    }
    final name = localName ?? cloudName;
    final cloudActive = _productsFromFirestore(name, data['active']);
    final cloudFrequent = _productsFromFirestore(name, data['frequent']);
    final deletedProducts = _deletedProductsFromFirestore(
      data['deletedProductTimestamps'],
    );
    final knownDeletedProducts = <String, DateTime>{
      ...?_deletedSharedProducts[listId],
    };
    for (final entry in deletedProducts.entries) {
      final current = knownDeletedProducts[entry.key];
      if (current == null || entry.value.isAfter(current)) {
        knownDeletedProducts[entry.key] = entry.value;
      }
    }

    _deletedSharedProducts[listId] = knownDeletedProducts;
    _sharedListIds[name] = listId;
    _sharedListOwners[name] = (data['ownerUid'] ?? '').toString();
    final localList = _shoppingLists[name] ?? {
      'active': <Product>[],
      'frequent': <Product>[],
    };
    _shoppingLists[name] = _mergeSharedListProducts(
      localList,
      {'active': cloudActive, 'frequent': cloudFrequent},
      knownDeletedProducts,
    );
    final updatedAt = data['updatedAt'];
    if (updatedAt is Timestamp) {
      _listUpdatedAt[name] = updatedAt.toDate();
    }
  }

  Future<void> _persistHiveCache() async {
    if (_box == null) return;

    final dataToSave = <String, Map<String, List<Map<String, dynamic>>>>{};
    for (final entry in _shoppingLists.entries) {
      dataToSave[entry.key] = {
        for (final category in entry.value.entries)
          category.key: category.value.map((product) => product.toMapHive()).toList(),
      };
    }

    await _box!.put('shopping_lists', dataToSave);
    await _box!.put('selected_list_name', _selectedListName);
    await _box!.put('shared_list_ids', _sharedListIds);
    await _box!.put('shared_list_owners', _sharedListOwners);
    await _box!.put(
      'deleted_shared_products',
      _deletedSharedProducts.map(
        (listId, products) => MapEntry(
          listId,
          products.map(
            (productId, deletedAt) =>
                MapEntry(productId, deletedAt.millisecondsSinceEpoch),
          ),
        ),
      ),
    );
  }

  List<Product> _productsFromFirestore(String listName, dynamic rawProducts) {
    if (rawProducts is! List) return <Product>[];
    final result = <Product>[];
    for (var i = 0; i < rawProducts.length; i++) {
      final item = rawProducts[i];
      if (item is Map) {
        final Map<String, dynamic> map = item.map(
          (k, v) => MapEntry(k.toString(), v),
        );
        result.add(Product.fromMap('${listName}_$i', map));
      }
    }
    return result;
  }

  Map<String, DateTime> _deletedProductsFromFirestore(dynamic rawDeletes) {
    if (rawDeletes is! Map) return <String, DateTime>{};

    final result = <String, DateTime>{};
    for (final entry in rawDeletes.entries) {
      final value = entry.value;
      DateTime? deletedAt;
      if (value is Timestamp) {
        deletedAt = value.toDate();
      } else if (value is DateTime) {
        deletedAt = value;
      }
      if (entry.key is String && deletedAt != null) {
        result[entry.key as String] = deletedAt;
      }
    }
    return result;
  }

  static Map<String, List<Product>> _mergeSharedListProducts(
    Map<String, List<Product>> local,
    Map<String, List<Product>> cloud,
    Map<String, DateTime> deletedProducts,
  ) {
    final productsByKey = <String, Product>{};
    final categoryByKey = <String, String>{};

    void addProducts(List<Product> products, String category) {
      for (final product in products) {
        final key = product.id.isNotEmpty
            ? 'id:${product.id}'
            : 'name:${product.name.trim().toLowerCase()}';
        final existing = productsByKey[key];
        final shouldReplace = existing == null ||
            product.lastAdded.isAfter(existing.lastAdded) ||
            (product.lastAdded.isAtSameMomentAs(existing.lastAdded) &&
                product.frequency >= existing.frequency);
        if (shouldReplace) {
          productsByKey[key] = product;
          categoryByKey[key] = category;
        }
      }
    }

    addProducts(cloud['active'] ?? <Product>[], 'active');
    addProducts(cloud['frequent'] ?? <Product>[], 'frequent');
    addProducts(local['active'] ?? <Product>[], 'active');
    addProducts(local['frequent'] ?? <Product>[], 'frequent');

    bool wasDeleted(Product product) {
      final deletedAt = deletedProducts[product.id];
      return deletedAt != null && !product.lastAdded.isAfter(deletedAt);
    }

    return {
      'active': productsByKey.entries
          .where((entry) => categoryByKey[entry.key] == 'active')
          .map((entry) => entry.value)
          .where((product) => !wasDeleted(product))
          .toList()
        ..sort((a, b) => b.lastAdded.compareTo(a.lastAdded)),
      'frequent': productsByKey.entries
          .where((entry) => categoryByKey[entry.key] == 'frequent')
          .map((entry) => entry.value)
          .where((product) => !wasDeleted(product))
          .toList()
        ..sort((a, b) => b.lastAdded.compareTo(a.lastAdded)),
    };
  }

  /// Cambia el entorno de datos entre invitado local y caché online.
  /// Se ejecuta al iniciar o cerrar sesión en SessionProvider.
  Future<void> switchUserEnvironment({required bool isOffline}) async {
    await _cancelSharedListListeners();
    _pendingSharedSnapshots.clear();
    _isOfflineMode = isOffline;
    _setSyncStatus(
      isOffline ? ShoppingSyncStatus.offline : ShoppingSyncStatus.syncing,
    );
    _currentBoxName = isOffline ? _guestBoxName : _onlineCacheBoxName;

    if (!isOffline && Hive.isBoxOpen(_onlineCacheBoxName)) {
      final cacheBox = Hive.box(_onlineCacheBoxName);
      await cacheBox.clear();
    }

    _shoppingLists.clear();
    _sharedListIds.clear();
    _sharedListOwners.clear();
    _deletedSharedProducts.clear();
    _listIds.clear();
    _deletedLists.clear();
    _selectedListName = '';

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
      if (mergeCloud &&
          !_isOfflineMode &&
          _currentUid != null &&
          _currentUid!.isNotEmpty) {
        // 1. Obtener y fusionar listas personales
        final cloudLists = await _userRepository.getShoppingLists(_currentUid!);
        final cloudTs = await _userRepository.getShoppingListTimestamps(
          _currentUid!,
        );
        final cloudListIds = await _userRepository.getShoppingListIds(
          _currentUid!,
        );
        final cloudDeletedLists = await _userRepository
            .getDeletedShoppingListTimestamps(_currentUid!);
        // Los tombstones locales aún no subidos deben prevalecer para no resucitar una lista recién borrada.
        final deletedLists = <String, DateTime>{...cloudDeletedLists};
        for (final entry in _deletedLists.entries) {
          final existing = deletedLists[entry.key];
          if (existing == null || entry.value.isAfter(existing)) {
            deletedLists[entry.key] = entry.value;
          }
        }

        final mergedPersonal = mergeShoppingListsForSync(
          _shoppingLists,
          cloudLists,
          localUpdatedAt: _listUpdatedAt,
          cloudUpdatedAt: cloudTs,
          localListIds: _listIds,
          cloudListIds: cloudListIds,
          deletedLists: deletedLists,
        );

        if (mergedPersonal.isNotEmpty) {
          for (final entry in mergedPersonal.entries) {
            if (!isSharedList(entry.key)) {
              _shoppingLists[entry.key] = entry.value;
            }
          }
        }

        // 2. Obtener y fusionar listas compartidas
        final sharedLists = await _userRepository.getSharedShoppingLists(
          _currentUid!,
        );
        // Nombre local vigente por listId: evita duplicar la lista bajo el nombre antiguo
        // cuando hay un renombrado local que aún no se ha subido a Firestore.
        final localNameByListId = <String, String>{
          for (final entry in _sharedListIds.entries) entry.value: entry.key,
        };
        for (final sharedEntry in sharedLists.entries) {
          final data = sharedEntry.value;
          final listId = sharedEntry.key;
          final cloudName = (data['name'] ?? listId).toString();
          final ownerUid = (data['ownerUid'] ?? '').toString();

          final cloudUpdatedAt = (data['updatedAt'] is Timestamp)
              ? (data['updatedAt'] as Timestamp).toDate()
              : DateTime.fromMillisecondsSinceEpoch(0);

          final localName = localNameByListId[listId];
          final localNameTs = localName != null
              ? (_listUpdatedAt[localName] ??
                    DateTime.fromMillisecondsSinceEpoch(0))
              : DateTime.fromMillisecondsSinceEpoch(0);

          final name =
              (localName != null && localNameTs.isAfter(cloudUpdatedAt))
              ? localName
              : cloudName;

          if (localName != null && localName != name) {
            _shoppingLists.remove(localName);
            _sharedListIds.remove(localName);
            _sharedListOwners.remove(localName);
            _listUpdatedAt.remove(localName);
          }

          _sharedListIds[name] = listId;
          _sharedListOwners[name] = ownerUid;

          final cloudActive = _productsFromFirestore(name, data['active']);
          final cloudFrequent = _productsFromFirestore(name, data['frequent']);
          final mergedDeletedProducts = <String, DateTime>{
            ...?_deletedSharedProducts[listId],
          };
          for (final entry in _deletedProductsFromFirestore(
            data['deletedProductTimestamps'],
          ).entries) {
            final current = mergedDeletedProducts[entry.key];
            if (current == null || entry.value.isAfter(current)) {
              mergedDeletedProducts[entry.key] = entry.value;
            }
          }
          _deletedSharedProducts[listId] = mergedDeletedProducts;

          final localList =
              _shoppingLists[name] ??
              {'active': <Product>[], 'frequent': <Product>[]};
          final localTs =
              _listUpdatedAt[name] ?? DateTime.fromMillisecondsSinceEpoch(0);

          _shoppingLists[name] = _mergeSharedListProducts(
            localList,
            {'active': cloudActive, 'frequent': cloudFrequent},
            mergedDeletedProducts,
          );
          _listUpdatedAt[name] = cloudUpdatedAt.isAfter(localTs)
              ? cloudUpdatedAt
              : localTs;
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

            dataToSave[listName]![categoryName] = products
                .map((p) => p.toMapHive())
                .toList();
          }
        }

        await _box!.put('shopping_lists', dataToSave);
        await _box!.put('selected_list_name', _selectedListName);
        await _box!.put('shared_list_ids', _sharedListIds);
        await _box!.put('shared_list_owners', _sharedListOwners);
        await _box!.put(
          'deleted_shared_products',
          _deletedSharedProducts.map(
            (listId, products) => MapEntry(
              listId,
              products.map(
                (productId, deletedAt) =>
                    MapEntry(productId, deletedAt.millisecondsSinceEpoch),
              ),
            ),
          ),
        );
      }

      if (!_isOfflineMode && _currentUid != null && _currentUid!.isNotEmpty) {
        for (final entry in _shoppingLists.entries) {
          _listUpdatedAt[entry.key] =
              _listUpdatedAt[entry.key] ?? DateTime.now();
          if (!isSharedList(entry.key)) {
            _listIds[entry.key] =
                _listIds[entry.key] ??
                'list_${DateTime.now().millisecondsSinceEpoch}_${entry.key.hashCode}';
          }
        }

        await _box!.put('shopping_list_ids', _listIds);
        await _box!.put(
          'deleted_lists',
          _deletedLists.map(
            (key, value) => MapEntry(key, value.millisecondsSinceEpoch),
          ),
        );
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

  Future<void> resetGuestData() async {
    // Limpiar caché de las Listas de Compra. El método de la sesión es "resetLocalProfile()"
    if (Hive.isBoxOpen(_guestBoxName)) {
      final guestBox = Hive.box(_guestBoxName);
      await guestBox.clear();
    }

    // Reseteamos el estado en memoria
    _shoppingLists.clear();
    _listIds.clear();
    _deletedLists.clear();
    _selectedListName = '';

    notifyListeners();
  }

  /// Borra las listas locales (memoria + Hive) sin tocar los datos de sesión del usuario.
  Future<void> clearLocalShoppingCache() async {
    _shoppingLists.clear();
    _sharedListIds.clear();
    _sharedListOwners.clear();
    _deletedSharedProducts.clear();
    _listIds.clear();
    _listUpdatedAt.clear();
    _deletedLists.clear();
    _selectedListName = '';

    if (Hive.isBoxOpen(_guestBoxName)) {
      await Hive.box(_guestBoxName).clear();
    }
    if (Hive.isBoxOpen(_onlineCacheBoxName)) {
      await Hive.box(_onlineCacheBoxName).clear();
    }

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
    _listIds[uniqueName] =
        _listIds[uniqueName] ??
        'list_${DateTime.now().millisecondsSinceEpoch}_${uniqueName.hashCode}';
    _touchList(uniqueName);

    _selectedListName = uniqueName;
    notifyListeners();
    unawaited(saveToStorage());
  }

  void renameList(String oldName, String newName) {
    // Solo el propietario puede renombrar una lista compartida; los demás no tienen permiso.
    if (!canManageList(oldName)) return;
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

    final currentSharedId = _sharedListIds.remove(oldName);
    if (currentSharedId != null) {
      _sharedListIds[cleanedName] = currentSharedId;
    }

    final currentOwner = _sharedListOwners.remove(oldName);
    if (currentOwner != null) {
      _sharedListOwners[cleanedName] = currentOwner;
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

  void addActiveProductToList(
    String listName,
    String productName, {
    double? price,
    String? imageUrl,
  }) {
    final cleanedName = productName.trim();
    if (cleanedName.isEmpty) return;

    if (!_shoppingLists.containsKey(listName)) {
      _shoppingLists[listName] = <String, List<Product>>{
        'active': <Product>[],
        'frequent': <Product>[],
      };
    }

    _shoppingLists[listName]!['active'] ??= <Product>[];
    _shoppingLists[listName]!['frequent'] ??= <Product>[];
    _touchList(listName);

    final activeList = _shoppingLists[listName]!['active']!;
    final frequentList = _shoppingLists[listName]!['frequent']!;
    final existingIndex = activeList.indexWhere(
      (p) => p.name.toLowerCase() == cleanedName.toLowerCase(),
    );

    final frequentIndex = frequentList.indexWhere(
      (p) => p.name.toLowerCase() == cleanedName.toLowerCase(),
    );

    if (frequentIndex >= 0 && existingIndex < 0) {
      final existing = frequentList.removeAt(frequentIndex);
      activeList.add(
        existing.copyWith(
          frequency: existing.frequency + 1,
          lastAdded: DateTime.now(),
        ),
      );
      notifyListeners();
      unawaited(saveToStorage());
      return;
    }

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

  void addFrequentProductToList(
    String listName,
    String productName, {
    double? price,
    String? imageUrl,
  }) {
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
    final existingIndex = frequentList.indexWhere(
      (p) => p.name.toLowerCase() == cleanedName.toLowerCase(),
    );

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

  void addActiveProductToSelectedList(
    String productName, {
    double? price,
    String? imageUrl,
  }) {
    addActiveProductToList(
      _selectedListName,
      productName,
      price: price,
      imageUrl: imageUrl,
    );
  }

  void addFrequentProductToSelectedList(
    String productName, {
    double? price,
    String? imageUrl,
  }) {
    addFrequentProductToList(
      _selectedListName,
      productName,
      price: price,
      imageUrl: imageUrl,
    );
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

    _shoppingLists[listName]!['frequent']!.removeWhere(
      (p) => p.id == productId,
    );
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

    final activeIndex = activeList.indexWhere(
      (product) => product.id == productId,
    );
    if (activeIndex < 0) return;

    final product = activeList.removeAt(activeIndex);
    frequentList.removeWhere(
      (frequentProduct) => frequentProduct.id == product.id,
    );
    frequentList.add(product.copyWith(lastAdded: DateTime.now()));
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

    final frequentIndex = frequentList.indexWhere(
      (product) => product.id == productId,
    );
    if (frequentIndex < 0) return;

    final product = frequentList.removeAt(frequentIndex);
    activeList.removeWhere((activeProduct) => activeProduct.id == product.id);
    activeList.add(
      product.copyWith(
        frequency: product.frequency + 1,
        lastAdded: DateTime.now(),
      ),
    );
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

    final sharedListId = _sharedListIds[listName];
    final deletedAt = DateTime.now();
    var removed = false;
    for (final category in ['active', 'frequent']) {
      final products = list[category];
      if (products == null) continue;
      final previousLength = products.length;
      products.removeWhere((product) => product.id == productId);
      removed = products.length < previousLength || removed;
    }

    if (!removed) return;

    if (sharedListId != null) {
      final deletedProducts = _deletedSharedProducts.putIfAbsent(
        sharedListId,
        () => <String, DateTime>{},
      );
      deletedProducts[productId] = deletedAt;
    }

    _touchList(listName);
    notifyListeners();
    unawaited(saveToStorage());
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
          : '';
    }

    _listUpdatedAt.remove(cleanedName);

    notifyListeners();
    unawaited(saveToStorage());
  }
}
