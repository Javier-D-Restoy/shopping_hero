import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_hero/core/models/product_model.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';

void main() {
  group('ShoppingProvider merge strategy', () {
    test('prefers the most recently updated list when both local and cloud versions exist', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [
            Product(
              id: 'lista_1_pan',
              name: 'Pan',
              frequency: 2,
              lastAdded: DateTime(2024, 1, 3),
            ),
          ],
          'frequent': <Product>[],
        },
      };

      final cloud = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [
            Product(
              id: 'lista_1_leche',
              name: 'Leche',
              frequency: 5,
              lastAdded: DateTime(2024, 1, 5),
            ),
          ],
          'frequent': <Product>[],
        },
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(
        local,
        cloud,
        localUpdatedAt: {'Lista 1': DateTime(2024, 1, 3)},
        cloudUpdatedAt: {'Lista 1': DateTime(2024, 1, 5)},
      );

      expect(merged['Lista 1']!['active']!.map((p) => p.name), containsAll(['Pan', 'Leche']));
    });

    test('keeps the newer product data and keeps unique products from both sources', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [
            Product(
              id: 'lista_1_pan',
              name: 'Pan',
              frequency: 2,
              lastAdded: DateTime(2024, 1, 3),
            ),
          ],
          'frequent': <Product>[],
        },
      };

      final cloud = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [
            Product(
              id: 'lista_1_pan',
              name: 'Pan',
              frequency: 6,
              lastAdded: DateTime(2024, 1, 2),
            ),
            Product(
              id: 'lista_1_leche',
              name: 'Leche',
              frequency: 1,
              lastAdded: DateTime(2024, 1, 4),
            ),
          ],
          'frequent': <Product>[],
        },
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(local, cloud);

      final pan = merged['Lista 1']!['active']!.singleWhere((p) => p.name == 'Pan');
      final leche = merged['Lista 1']!['active']!.singleWhere((p) => p.name == 'Leche');

      expect(pan.frequency, 2);
      expect(leche.frequency, 1);
      expect(merged['Lista 1']!['active']!.length, 2);
    });

    test('ignores empty lists so no useless Firestore documents are created', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista vacía': {
          'active': <Product>[],
          'frequent': <Product>[],
        },
      };

      final cloud = <String, Map<String, List<Product>>>{
        'Lista vacía': {
          'active': <Product>[],
          'frequent': <Product>[],
        },
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(local, cloud);

      expect(merged.containsKey('Lista vacía'), isFalse);
    });

    test('keeps the same list identity when it is renamed on another device', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista de compra': {
          'active': [
            Product(
              id: 'p1',
              name: 'Pan',
              frequency: 2,
              lastAdded: DateTime(2024, 2, 1),
            ),
          ],
          'frequent': <Product>[],
        },
      };

      final cloud = <String, Map<String, List<Product>>>{
        'Lista de supermercado': {
          'active': [
            Product(
              id: 'p2',
              name: 'Leche',
              frequency: 3,
              lastAdded: DateTime(2024, 2, 3),
            ),
          ],
          'frequent': <Product>[],
        },
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(
        local,
        cloud,
        localUpdatedAt: {'Lista de compra': DateTime(2024, 2, 1)},
        cloudUpdatedAt: {'Lista de supermercado': DateTime(2024, 2, 5)},
        localListIds: {'Lista de compra': 'list-42'},
        cloudListIds: {'Lista de supermercado': 'list-42'},
      );

      expect(merged.length, 1);
      expect(merged.keys.single, contains('Lista'));
      expect(merged.values.first['active']!.map((p) => p.name), containsAll(['Pan', 'Leche']));
    });

    test('removes a list when the deletion tombstone is newer than the local version', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista antigua': {
          'active': [
            Product(
              id: 'p1',
              name: 'Pan',
              frequency: 1,
              lastAdded: DateTime(2024, 3, 1),
            ),
          ],
          'frequent': <Product>[],
        },
      };

      final cloud = <String, Map<String, List<Product>>>{};

      final merged = ShoppingProvider.mergeShoppingListsForSync(
        local,
        cloud,
        localUpdatedAt: {'Lista antigua': DateTime(2024, 3, 1)},
        localListIds: {'Lista antigua': 'list-88'},
        deletedLists: {'list-88': DateTime(2024, 3, 2)},
      );

      expect(merged.containsKey('Lista antigua'), isFalse);
    });
  });
}
