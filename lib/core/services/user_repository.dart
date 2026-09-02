import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shopping_hero/core/models/product_model.dart';
import 'package:shopping_hero/core/models/user_model.dart';

// --------------------------------------------------- ][ ACCESO A FIRESTORE ][ --------------------------------------------------- //

// Se encarga de:
//  - crear el perfil del usuario
//  - leerlo
//  - actualizarlo
//  - guardar listas con productos
//  - recuperar listas con productos
//  - eliminar listas

class UserRepository {
  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _usersCollection =>
      _firestore.collection('users');

  DocumentReference<Map<String, dynamic>> _userDoc(String uid) =>
      _usersCollection.doc(uid);

  Future<void> createUserProfile({
    required String uid,
    required String email,
    String? displayName,
  }) async {
    final now = DateTime.now();

    final user = UserModel(
      uid: uid,
      email: email,
      displayName: displayName,
      createdAt: now,
      updatedAt: now,
    );

    await _userDoc(uid).set(user.toMap(), SetOptions(merge: true));
  }

  Future<UserModel?> getUser(String uid) async {
    final snapshot = await _userDoc(uid).get();

    if (!snapshot.exists || snapshot.data() == null) {
      return null;
    }

    return UserModel.fromMap(uid, snapshot.data()!);
  }

  Future<void> updateUserProfile({
    required String uid,
    String? email,
    String? displayName,
  }) async {
    final data = <String, dynamic>{};

    if (email != null) {
      data['email'] = email;
    }

    if (displayName != null) {
      data['displayName'] = displayName;
    }

    if (data.isNotEmpty) {
      data['updatedAt'] = FieldValue.serverTimestamp();
      await _userDoc(uid).set(data, SetOptions(merge: true));
    }
  }

  Future<void> saveShoppingLists({
    required String uid,
    required Map<String, Map<String, List<Product>>> shoppingLists,
    Map<String, DateTime>? listUpdatedAt,
    Map<String, String>? listIds,
    Map<String, DateTime>? deletedLists,
  }) async {
    final collection = _userDoc(uid).collection('shoppingLists');
    final batch = _firestore.batch();

    final sanitizedLists = <String, Map<String, List<Product>>>{};
    for (final entry in shoppingLists.entries) {
      final activeProducts = entry.value['active'] ?? <Product>[];
      final frequentProducts = entry.value['frequent'] ?? <Product>[];

      if (activeProducts.isEmpty && frequentProducts.isEmpty) {
        continue;
      }

      sanitizedLists[entry.key] = {
        'active': List<Product>.from(activeProducts),
        'frequent': List<Product>.from(frequentProducts),
      };
    }

    final currentDocs = await collection.get();
    for (final doc in currentDocs.docs) {
      final data = doc.data();
      final docName = (data['name'] ?? doc.id).toString();
      final docIdValue = (data['listId'] ?? '').toString();
      final shouldKeep = sanitizedLists.containsKey(docName) ||
          (listIds != null && listIds.values.contains(docIdValue));
      if (!shouldKeep) {
        batch.delete(doc.reference);
      }
    }

    if (deletedLists != null && deletedLists.isNotEmpty) {
      final tombstonesRef = _userDoc(uid).collection('shoppingListDeletes');
      for (final entry in deletedLists.entries) {
        await tombstonesRef.doc(entry.key).set({
          'deletedAt': Timestamp.fromDate(entry.value),
        }, SetOptions(merge: true));
      }
    }

    for (final entry in sanitizedLists.entries) {
      final listName = entry.key;
      final items = entry.value;
      final docId = _buildDocId(listName);
      final stableId = listIds?[listName] ?? docId;

      final activeProducts = (items['active'] ?? <Product>[])
          .map((p) => p.toMap())
          .toList();
      final frequentProducts = (items['frequent'] ?? <Product>[])
          .map((p) => p.toMap())
          .toList();

      final timestamp = listUpdatedAt?[listName] ?? DateTime.now();

      batch.set(
        collection.doc(docId),
        {
          'name': listName,
          'listId': stableId,
          'active': activeProducts,
          'frequent': frequentProducts,
          'updatedAt': Timestamp.fromDate(timestamp),
        },
        SetOptions(merge: true),
      );
    }

    if (currentDocs.docs.isNotEmpty || sanitizedLists.isNotEmpty) {
      await batch.commit();
    }
  }

  Future<Map<String, DateTime>> getShoppingListTimestamps(String uid) async {
    final snapshot = await _userDoc(uid).collection('shoppingLists').get();
    final result = <String, DateTime>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final listName = (data['name'] ?? doc.id).toString();
      final timestamp = data['updatedAt'];
      if (timestamp is Timestamp) {
        result[listName] = timestamp.toDate();
      }
    }

    return result;
  }

  Future<Map<String, String>> getShoppingListIds(String uid) async {
    final snapshot = await _userDoc(uid).collection('shoppingLists').get();
    final result = <String, String>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final listName = (data['name'] ?? doc.id).toString();
      final listId = (data['listId'] ?? doc.id).toString();
      result[listName] = listId;
    }

    return result;
  }

  Future<Map<String, DateTime>> getDeletedShoppingListTimestamps(String uid) async {
    final snapshot = await _userDoc(uid).collection('shoppingListDeletes').get();
    final result = <String, DateTime>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();
      final deletedAt = data['deletedAt'];
      if (deletedAt is Timestamp) {
        result[doc.id] = deletedAt.toDate();
      }
    }

    return result;
  }

  Future<Map<String, Map<String, List<Product>>>> getShoppingLists(
    String uid,
  ) async {
    final snapshot = await _userDoc(uid).collection('shoppingLists').get();

    final result = <String, Map<String, List<Product>>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final listName = (data['name'] ?? doc.id).toString();
      
      final active = (data['active'] as List<dynamic>? ?? <dynamic>[])
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final item = entry.value;
            if (item is Map<String, dynamic>) {
              return Product.fromMap('${listName}_active_$index', item);
            }
            return null;
          })
          .whereType<Product>()
          .toList();

      final frequent = (data['frequent'] as List<dynamic>? ?? <dynamic>[])
          .asMap()
          .entries
          .map((entry) {
            final index = entry.key;
            final item = entry.value;
            if (item is Map<String, dynamic>) {
              return Product.fromMap('${listName}_frequent_$index', item);
            }
            return null;
          })
          .whereType<Product>()
          .toList();

      result[listName] = {
        'active': active,
        'frequent': frequent,
      };
    }

    return result;
  }

  Future<void> addOrUpdateShoppingList({
    required String uid,
    required String listName,
    required Map<String, List<Product>> items,
  }) async {
    final docId = _buildDocId(listName);

    final activeProducts = (items['active'] ?? <Product>[])
        .map((p) => p.toMap())
        .toList();
    final frequentProducts = (items['frequent'] ?? <Product>[])
        .map((p) => p.toMap())
        .toList();

    await _userDoc(uid)
        .collection('shoppingLists')
        .doc(docId)
        .set(
          {
            'name': listName,
            'active': activeProducts,
            'frequent': frequentProducts,
            'updatedAt': FieldValue.serverTimestamp(),
          },
          SetOptions(merge: true),
        );
  }

  Future<void> deleteShoppingList({
    required String uid,
    required String listName,
  }) async {
    final docId = _buildDocId(listName);
    await _userDoc(uid).collection('shoppingLists').doc(docId).delete();
  }

  String _buildDocId(String value) {
    final cleaned = value.trim();
    if (cleaned.isEmpty) {
      return 'lista_1';
    }

    final sanitized = cleaned
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+4d?'), '');

    return sanitized.isEmpty ? 'list_${DateTime.now().millisecondsSinceEpoch}' : sanitized;
  }
}
