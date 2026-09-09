import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/services/user_repository.dart';

class _FakeFirestore extends Fake implements FirebaseFirestore {}

class FakeUserRepository extends UserRepository {
  FakeUserRepository() : super(firestore: _FakeFirestore());

  final List<String> emails = [];

  @override
  Future<String> shareShoppingList({
    required String ownerUid,
    required String listName,
    required String recipientEmail,
  }) async {
    emails.add(recipientEmail);
    return 'shared-$listName-${emails.length}';
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
  });

  test('deleting a list removes it and updates the selected list', () {
    final provider = ShoppingProvider(userRepository: FakeUserRepository());
    provider.createList(name: 'Mercadona');
    provider.createList(name: 'Aldi');
    provider.createList(name: 'Abuela');

    provider.selectList('Aldi');
    provider.removeList('Aldi');

    expect(provider.shoppingLists.keys.toList(), ['Mercadona', 'Abuela']);
    expect(provider.selectedListName, 'Mercadona');
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
