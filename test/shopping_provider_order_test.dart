import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shopping_hero/core/models/product_model.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/services/user_repository.dart';

class _FakeFirestore extends Fake implements FirebaseFirestore {}

class FakeUserRepository extends UserRepository {
  FakeUserRepository() : super(firestore: _FakeFirestore());

  final List<String> emails = [];
  bool failSharedDelete = false;

  @override
  Future<String> shareShoppingList({
    required String ownerUid,
    required String listName,
    required String recipientEmail,
    required List<Product> activeProducts,
    required List<Product> frequentProducts,
    required List<String> categories,
    required DateTime localUpdatedAt,
    String? preferredListId,
  }) async {
    emails.add(recipientEmail);
    return 'shared-$listName-${emails.length}';
  }

  @override
  Future<void> deleteSharedShoppingList(String listId) async {
    if (failSharedDelete) throw Exception('Firestore no disponible');
  }
}

class _LegacyCopyRepository extends UserRepository {
  _LegacyCopyRepository(
    this.product, {
    this.sharedOwnerUid = 'owner-1',
    Product? sharedProduct,
    this.personalListName = 'Lista 6 (2)',
    List<Product>? personalProducts,
  }) : _sharedProduct = sharedProduct ?? product,
       _personalProducts = personalProducts ?? [product],
       super(firestore: _FakeFirestore());

  final Product product;
  final String sharedOwnerUid;
  final Product _sharedProduct;
  final String personalListName;
  final List<Product> _personalProducts;
  Map<String, Map<String, List<Product>>>? savedPersonalLists;
  List<Product>? savedSharedActive;

  @override
  Future<Map<String, Map<String, dynamic>>> getShoppingListsWithCategories(
    String uid,
  ) async => {
    personalListName: {
      'active': _personalProducts,
      'frequent': <Product>[],
      'categories': <String>['Genérico'],
      'createdAt': DateTime(2025, 1, 1),
    },
  };

  @override
  Future<Map<String, DateTime>> getShoppingListTimestamps(String uid) async => {
    personalListName: DateTime(2025, 1, 2),
  };

  @override
  Future<Map<String, String>> getShoppingListIds(String uid) async => {
    personalListName: 'legacy-personal-id',
  };

  @override
  Future<Map<String, DateTime>> getDeletedShoppingListTimestamps(
    String uid,
  ) async => {};

  @override
  Future<Map<String, Map<String, dynamic>>> getSharedShoppingLists(
    String uid,
  ) async => {
    'shared-list-id': {
      'listId': 'shared-list-id',
      'ownerUid': sharedOwnerUid,
      'name': 'Lista 6',
      'memberUids': [uid],
      'active': [_sharedProduct.toMap()],
      'frequent': <Map<String, dynamic>>[],
      'categories': <String>['Genérico'],
      'updatedAt': Timestamp.fromDate(DateTime(2025, 1, 2)),
    },
  };

  @override
  Future<Map<String, DateTime>> getAcceptedShareInvitationTimestamps(
    String uid,
  ) async => {'shared-list-id': DateTime(2025, 1, 2)};

  @override
  Future<void> saveShoppingLists({
    required String uid,
    required Map<String, Map<String, List<Product>>> shoppingLists,
    Map<String, List<String>>? listCategories,
    Map<String, DateTime>? listUpdatedAt,
    Map<String, String>? listIds,
    Map<String, String>? canonicalListNames,
    Map<String, DateTime>? listCreatedAt,
    Map<String, DateTime>? deletedLists,
  }) async {
    savedPersonalLists = shoppingLists;
  }

  @override
  Future<void> saveSharedShoppingList({
    required String listId,
    required String name,
    required List<Product> active,
    required List<Product> frequent,
    required DateTime updatedAt,
    List<String>? categories,
    Map<String, DateTime>? deletedProductTimestamps,
  }) async {
    savedSharedActive = active;
  }
}

void main() {
  setUpAll(() {
    final tempDir = Directory.systemTemp.createTempSync('hive_test');
    Hive.init(tempDir.path);
  });
  test('renaming a list preserves its original position', () {
    final provider = ShoppingProvider(userRepository: FakeUserRepository());
    provider.createList(name: 'Mercadona');
    provider.createList(name: 'Aldi');
    provider.createList(name: 'Abuela');

    final before = provider.shoppingLists.keys.toList();
    expect(before, ['Mercadona', 'Aldi', 'Abuela']);

    provider.renameList('Aldi', 'Aldi Renombrada');

    final after = provider.shoppingLists.keys.toList();
    expect(after, ['Mercadona', 'Aldi Renombrada', 'Abuela']);
    expect(provider.orderedListNames, after);
  });

  test('shared list aliases avoid name collisions and remain unique', () {
    expect(
      ShoppingProvider.sharedListDisplayName('Lista 6', ['Lista 6']),
      'Lista 6 (compartida)',
    );
    expect(
      ShoppingProvider.sharedListDisplayName('Lista 6', [
        'Lista 6',
        'Lista 6 (compartida)',
      ]),
      'Lista 6 (compartida 2)',
    );
  });

  test('new lists append after the manually ordered lists', () {
    final provider = ShoppingProvider(userRepository: FakeUserRepository());
    provider.createList(name: 'Lista A');
    provider.createList(name: 'Lista B');
    provider.createList(name: 'Lista C');

    provider.reorderLists(0, 2);
    expect(provider.orderedListNames, ['Lista B', 'Lista C', 'Lista A']);

    provider.createList(name: 'Lista D');
    expect(provider.orderedListNames, [
      'Lista B',
      'Lista C',
      'Lista A',
      'Lista D',
    ]);
  });

  test('reordering the first list to the second position moves it down', () {
    final provider = ShoppingProvider(userRepository: FakeUserRepository());
    provider.createList(name: 'Mercadona');
    provider.createList(name: 'Prueba');

    provider.reorderLists(0, 1);

    expect(provider.orderedListNames, ['Prueba', 'Mercadona']);
  });

  test('reordering the second list to the first position moves it up', () {
    final provider = ShoppingProvider(userRepository: FakeUserRepository());
    provider.createList(name: 'Mercadona');
    provider.createList(name: 'Prueba');

    provider.reorderLists(1, 0);

    expect(provider.orderedListNames, ['Prueba', 'Mercadona']);
  });

  test('clears the online Hive cache after queued writes finish', () async {
    const onlineBoxName = 'shopping_lists_online_cache';
    final box = Hive.isBoxOpen(onlineBoxName)
        ? Hive.box(onlineBoxName)
        : await Hive.openBox(onlineBoxName);
    await box.clear();

    final provider = ShoppingProvider(userRepository: FakeUserRepository());
    await provider.init(isOffline: false);
    provider.createList(name: 'Cambio pendiente');

    await provider.clearLocalShoppingCache();

    expect(box.get('shopping_lists'), isNull);
    expect(provider.shoppingLists, isEmpty);
  });

  test(
    'removes a legacy personal copy when it matches an owned shared list',
    () async {
      final product = Product(
        id: 'product-pan',
        name: 'Pan',
        lastAdded: DateTime(2025, 1, 1),
      );
      final repository = _LegacyCopyRepository(product);
      final provider = ShoppingProvider(userRepository: repository);
      provider.setCurrentUser('owner-1', isOffline: false);

      const onlineBoxName = 'shopping_lists_online_cache';
      if (Hive.isBoxOpen(onlineBoxName)) {
        await Hive.box(onlineBoxName).clear();
      }

      await provider.saveToStorage();
      await provider.saveToStorage();

      expect(provider.shoppingLists.keys, ['Lista 6']);
      expect(provider.isSharedList('Lista 6'), isTrue);
      expect(repository.savedPersonalLists, isEmpty);
      expect(repository.savedSharedActive, hasLength(1));
    },
  );

  test(
    'preserves a same-named personal list when the shared owner is another user',
    () async {
      final product = Product(
        id: 'product-pan',
        name: 'Pan',
        lastAdded: DateTime(2025, 1, 1),
      );
      final repository = _LegacyCopyRepository(
        product,
        sharedOwnerUid: 'owner-2',
        sharedProduct: Product(
          id: 'shared-pan-from-owner-2',
          name: 'Pan',
          amount: 2,
          lastAdded: DateTime(2025, 1, 1),
        ),
      );
      final provider = ShoppingProvider(userRepository: repository);
      provider.setCurrentUser('owner-1', isOffline: false);

      const onlineBoxName = 'shopping_lists_online_cache';
      if (Hive.isBoxOpen(onlineBoxName)) {
        await Hive.box(onlineBoxName).clear();
      }

      await provider.saveToStorage();

      expect(
        provider.shoppingLists.keys,
        containsAll(['Lista 6', 'Lista 6 (2)']),
      );
      expect(provider.isSharedList('Lista 6'), isTrue);
      expect(provider.isSharedList('Lista 6 (2)'), isFalse);
      expect(repository.savedPersonalLists, hasLength(1));
    },
  );

  test('removes an exact legacy copy of another owner shared list', () async {
    final product = Product(
      id: 'product-pan',
      name: 'Pan',
      lastAdded: DateTime(2025, 1, 1),
    );
    final repository = _LegacyCopyRepository(
      product,
      sharedOwnerUid: 'owner-2',
      sharedProduct: Product(
        id: 'shared-product-pan',
        name: 'Pan',
        lastAdded: DateTime(2025, 1, 2),
      ),
    );
    final provider = ShoppingProvider(userRepository: repository);
    provider.setCurrentUser('owner-1', isOffline: false);

    const onlineBoxName = 'shopping_lists_online_cache';
    if (Hive.isBoxOpen(onlineBoxName)) {
      await Hive.box(onlineBoxName).clear();
    }

    await provider.saveToStorage();
    await provider.saveToStorage();

    expect(provider.shoppingLists.keys, ['Lista 6']);
    expect(provider.isSharedList('Lista 6'), isTrue);
    expect(repository.savedPersonalLists, isEmpty);
    expect(repository.savedSharedActive, hasLength(1));
  });

  test('removes an empty legacy generated shared alias', () async {
    final sharedProduct = Product(
      id: 'shared-pan',
      name: 'Pan',
      lastAdded: DateTime(2025, 1, 1),
    );
    final repository = _LegacyCopyRepository(
      sharedProduct,
      sharedOwnerUid: 'owner-2',
      personalListName: 'Lista 6 (compartida) (2)',
      personalProducts: <Product>[],
    );
    final provider = ShoppingProvider(userRepository: repository);
    provider.setCurrentUser('owner-1', isOffline: false);

    const onlineBoxName = 'shopping_lists_online_cache';
    if (Hive.isBoxOpen(onlineBoxName)) {
      await Hive.box(onlineBoxName).clear();
    }

    await provider.saveToStorage();

    expect(provider.shoppingLists.keys, ['Lista 6']);
    expect(provider.isSharedList('Lista 6'), isTrue);
    expect(repository.savedPersonalLists, isEmpty);
  });

  test(
    'keeps an exact-name empty personal list under a stable local alias',
    () async {
      final sharedProduct = Product(
        id: 'shared-pan',
        name: 'Pan',
        lastAdded: DateTime(2025, 1, 1),
      );
      final repository = _LegacyCopyRepository(
        sharedProduct,
        sharedOwnerUid: 'owner-2',
        personalListName: 'Lista 6',
        personalProducts: <Product>[],
      );
      final provider = ShoppingProvider(userRepository: repository);
      provider.setCurrentUser('owner-1', isOffline: false);

      const onlineBoxName = 'shopping_lists_online_cache';
      if (Hive.isBoxOpen(onlineBoxName)) {
        await Hive.box(onlineBoxName).clear();
      }

      await provider.saveToStorage();

      expect(
        provider.shoppingLists.keys,
        containsAll(['Lista 6', 'Lista 6 (personal)']),
      );
      expect(provider.isSharedList('Lista 6'), isTrue);
      expect(provider.isSharedList('Lista 6 (personal)'), isFalse);
    },
  );

  test('deleting a list removes it and updates the selected list', () async {
    final provider = ShoppingProvider(userRepository: FakeUserRepository());
    provider.createList(name: 'Mercadona');
    provider.createList(name: 'Aldi');
    provider.createList(name: 'Abuela');

    provider.selectList('Aldi');
    await provider.removeList('Aldi');

    expect(provider.shoppingLists.keys.toList(), ['Mercadona', 'Abuela']);
    expect(provider.selectedListName, 'Mercadona');
  });

  test('keeps an owned shared list when its remote deletion fails', () async {
    final fakeRepo = FakeUserRepository()..failSharedDelete = true;
    final provider = ShoppingProvider(userRepository: fakeRepo);
    provider.createList(name: 'Lista compartida');
    provider.selectList('Lista compartida');
    provider.setCurrentUser('owner-1', isOffline: false);
    await provider.shareSelectedListWithEmail('persona@ejemplo.com');

    await expectLater(provider.removeList('Lista compartida'), throwsException);

    expect(provider.shoppingLists.containsKey('Lista compartida'), isTrue);
    expect(provider.sharedListIdFor('Lista compartida'), isNotNull);
    expect(provider.canManageList('Lista compartida'), isTrue);
  });

  test('sharing the same list with multiple users is allowed', () async {
    final fakeRepo = FakeUserRepository();
    final provider = ShoppingProvider(userRepository: fakeRepo);

    provider.createList(name: 'Mas');
    provider.selectList('Mas');
    provider.setCurrentUser('owner-1', isOffline: false);

    await provider.shareSelectedListWithEmail('a@a.com');
    await provider.shareSelectedListWithEmail('c@c.com');

    expect(fakeRepo.emails, ['a@a.com', 'c@c.com']);
    expect(provider.sharedListIdFor('Mas'), isNotNull);
  });
}
