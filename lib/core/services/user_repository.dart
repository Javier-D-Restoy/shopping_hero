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

    CollectionReference<Map<String, dynamic>> get _sharedListsCollection =>
      _firestore.collection('sharedShoppingLists');

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

  Future<String> shareShoppingList({
    required String ownerUid,
    required String listName,
    required String recipientEmail,
  }) async {
    final recipientSnapshot = await _usersCollection
      .where('email', isEqualTo: recipientEmail.trim())
      .limit(1)
      .get();

    if (recipientSnapshot.docs.isEmpty) {
      throw Exception('No existe un usuario con ese email');
    }

    final recipientUid = recipientSnapshot.docs.first.id;

    final listSnapshot = await _userDoc(ownerUid)
        .collection('shoppingLists')
        .where('name', isEqualTo: listName)
        .limit(1)
        .get();

    String listId;
    Map<String, dynamic> listData = {};

    if (listSnapshot.docs.isNotEmpty) {
      listData = listSnapshot.docs.first.data();
      listId = (listData['listId'] ?? listSnapshot.docs.first.id).toString();
    } else {
      final sharedListSnapshot = await _sharedListsCollection
          .where('ownerUid', isEqualTo: ownerUid)
          .where('name', isEqualTo: listName)
          .limit(1)
          .get();

      if (sharedListSnapshot.docs.isEmpty) {
        throw Exception('No se encontró la lista seleccionada');
      }

      final existingDoc = sharedListSnapshot.docs.first;
      listData = existingDoc.data();
      listId = (listData['listId'] ?? existingDoc.id).toString();
    }

    final existingMembers = <String>{
      ...(listData['memberUids'] is List ? List<String>.from(listData['memberUids'] as List) : const <String>[]),
      ownerUid,
    };

    if (existingMembers.contains(recipientUid)) {
      throw Exception('Este usuario ya tiene acceso a la lista');
    }

    final finalMembers = <String>{...existingMembers, recipientUid}.toList();

    await _sharedListsCollection.doc(listId).set({
      ...listData,
      'listId': listId,
      'ownerUid': ownerUid,
      'name': listName,
      'memberUids': finalMembers,
      'updatedAt': listData['updatedAt'] ?? Timestamp.now(),
    }, SetOptions(merge: true));

    if (listSnapshot.docs.isNotEmpty) {
      await listSnapshot.docs.first.reference.delete();
    }

    return listId;
  }

  Future<Map<String, Map<String, dynamic>>> getSharedShoppingLists(
    String uid,
  ) async {
    final snapshot = await _sharedListsCollection
        .where('memberUids', arrayContains: uid)
        .get();
    return {
      for (final doc in snapshot.docs)
        doc.id: {
          ...doc.data(),
          'listId': doc.id,
        },
    };
  }

  Future<void> saveSharedShoppingList({
    required String listId,
    required String name,
    required List<Product> active,
    required List<Product> frequent,
    required DateTime updatedAt,
  }) async {
    await _sharedListsCollection.doc(listId).set({
      'name': name,
      'active': active.map((product) => product.toMap()).toList(),
      'frequent': frequent.map((product) => product.toMap()).toList(),
      'updatedAt': Timestamp.fromDate(updatedAt),
    }, SetOptions(merge: true));
  }

  Future<void> deleteSharedShoppingList(String listId) async {
    await _sharedListsCollection.doc(listId).delete();
  }

  Future<void> removeMemberFromSharedList({
    required String listId,
    required String uid,
  }) async {
    final docRef = _sharedListsCollection.doc(listId);
    final snapshot = await docRef.get();

    if (!snapshot.exists || snapshot.data() == null) {
      return;
    }

    final memberUids = (snapshot.data()!['memberUids'] as List<dynamic>? ?? const [])
        .whereType<String>()
        .where((memberUid) => memberUid.trim().isNotEmpty && memberUid != uid)
        .toList();

    if (memberUids.isEmpty) {
      await docRef.delete();
      return;
    }

    await docRef.update({
      'memberUids': memberUids,
      'updatedAt': FieldValue.serverTimestamp(),
    });
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

  /// Borra el perfil, las listas propias/compartidas y desvincula al usuario de las listas de otros.
  Future<void> deleteUserAccountData(String uid) async {
    final batch = _firestore.batch();

    final sharedSnapshot = await _sharedListsCollection
        .where('memberUids', arrayContains: uid)
        .get();

    for (final doc in sharedSnapshot.docs) {
      final data = doc.data();
      final ownerUid = (data['ownerUid'] ?? '').toString();

      if (ownerUid == uid) {
        batch.delete(doc.reference);
      } else {
        final memberUids = (data['memberUids'] as List<dynamic>? ?? const [])
            .whereType<String>()
            .where((memberUid) => memberUid.trim().isNotEmpty && memberUid != uid)
            .toList();
        batch.update(doc.reference, {
          'memberUids': memberUids,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
    }

    final personalListsSnapshot = await _userDoc(uid).collection('shoppingLists').get();
    for (final doc in personalListsSnapshot.docs) {
      batch.delete(doc.reference);
    }

    final tombstonesSnapshot = await _userDoc(uid).collection('shoppingListDeletes').get();
    for (final doc in tombstonesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    batch.delete(_userDoc(uid));

    await batch.commit();
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

    // Se guardan también las listas vacías: deben existir en Firestore desde el momento en que se crean.
    final sanitizedLists = <String, Map<String, List<Product>>>{};
    for (final entry in shoppingLists.entries) {
      final activeProducts = entry.value['active'] ?? <Product>[];
      final frequentProducts = entry.value['frequent'] ?? <Product>[];

      sanitizedLists[entry.key] = {
        'active': List<Product>.from(activeProducts),
        'frequent': List<Product>.from(frequentProducts),
      };
    }

    final currentDocs = await collection.get();
    // El ID de documento debe ser el listId estable, no el nombre: si no, renombrar crea un documento duplicado.
    final stableIdsToKeep = <String>{
      for (final listName in sanitizedLists.keys)
        listIds?[listName] ?? _buildDocId(listName),
    };
    for (final doc in currentDocs.docs) {
      if (!stableIdsToKeep.contains(doc.id)) {
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
      final stableId = listIds?[listName] ?? _buildDocId(listName);

      final activeProducts = (items['active'] ?? <Product>[])
          .map((p) => p.toMap())
          .toList();
      final frequentProducts = (items['frequent'] ?? <Product>[])
          .map((p) => p.toMap())
          .toList();

      final timestamp = listUpdatedAt?[listName] ?? DateTime.now();

      batch.set(
        collection.doc(stableId),
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
