import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shopping_hero/core/models/user_model.dart';

// --------------------------------------------------- ][ ACCESO A FIRESTORE ][ --------------------------------------------------- //

// Se encarga de:
//  - crear el perfil del usuario
//  - leerlo
//  - actualizarlo
//  - guardar listas
//  - recuperar listas
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
    required Map<String, Map<String, List<String>>> shoppingLists,
  }) async {
    final collection = _userDoc(uid).collection('shoppingLists');
    final batch = _firestore.batch();

    final currentDocs = await collection.get();
    for (final doc in currentDocs.docs) {
      batch.delete(doc.reference);
    }

    for (final entry in shoppingLists.entries) {
      final listName = entry.key;
      final items = entry.value;
      final docId = _buildDocId(listName);

      batch.set(
        collection.doc(docId),
        {
          'name': listName,
          'active': items['active'] ?? <String>[],
          'frequent': items['frequent'] ?? <String>[],
          'updatedAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<Map<String, Map<String, List<String>>>> getShoppingLists(String uid) async {
    final snapshot = await _userDoc(uid).collection('shoppingLists').get();

    final result = <String, Map<String, List<String>>>{};

    for (final doc in snapshot.docs) {
      final data = doc.data();

      final listName = (data['name'] ?? doc.id).toString();
      final active = (data['active'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => item.toString())
          .toList();
      final frequent = (data['frequent'] as List<dynamic>? ?? <dynamic>[])
          .map((item) => item.toString())
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
    required Map<String, List<String>> items,
  }) async {
    final docId = _buildDocId(listName);

    await _userDoc(uid)
        .collection('shoppingLists')
        .doc(docId)
        .set(
      {
        'name': listName,
        'active': items['active'] ?? <String>[],
        'frequent': items['frequent'] ?? <String>[],
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
