import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_hero/core/models/product_model.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';

void main() {
  group('ShoppingProvider merge strategy', () {
    test('does not restore an active product after it moved to frequent locally', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': <Product>[],
          'frequent': [Product(id: 'product-1', name: 'Pan', frequency: 2, lastAdded: DateTime(2024, 1, 2))],
        },
      };
      final cloud = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [Product(id: 'product-1', name: 'Pan', frequency: 2, lastAdded: DateTime(2024, 1, 2))],
          'frequent': <Product>[],
        },
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(
        local,
        cloud,
        localUpdatedAt: {'Lista 1': DateTime(2024, 1, 3)},
        cloudUpdatedAt: {'Lista 1': DateTime(2024, 1, 2)},
      );

      expect(merged['Lista 1']!['active'], isEmpty);
      expect(merged['Lista 1']!['frequent']!.single.name, 'Pan');
    });

    test('does not keep the old name when a product is renamed locally', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [Product(id: 'product-1', name: 'Huevos Camperos', frequency: 1, lastAdded: DateTime(2024, 1, 3))],
          'frequent': <Product>[],
        },
      };
      final cloud = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [Product(id: 'product-1', name: 'Huevos', frequency: 1, lastAdded: DateTime(2024, 1, 2))],
          'frequent': <Product>[],
        },
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(
        local,
        cloud,
        localUpdatedAt: {'Lista 1': DateTime(2024, 1, 3)},
        cloudUpdatedAt: {'Lista 1': DateTime(2024, 1, 2)},
      );

      expect(merged['Lista 1']!['active'], hasLength(1));
      expect(merged['Lista 1']!['active']!.single.name, 'Huevos Camperos');
    });

    test('prefers the most recently updated list when both local and cloud versions exist', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [Product(id: 'lista_1_pan', name: 'Pan', frequency: 2, lastAdded: DateTime(2024, 1, 3))],
          'frequent': <Product>[],
        },
      };

      final cloud = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [Product(id: 'lista_1_leche', name: 'Leche', frequency: 5, lastAdded: DateTime(2024, 1, 5))],
          'frequent': <Product>[],
        },
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(
        local,
        cloud,
        localUpdatedAt: {'Lista 1': DateTime(2024, 1, 3)},
        cloudUpdatedAt: {'Lista 1': DateTime(2024, 1, 5)},
      );

      expect(merged['Lista 1']!['active']!.map((p) => p.name), ['Leche']);
    });

    test('keeps the newer product data and keeps unique products from both sources', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [Product(id: 'lista_1_pan', name: 'Pan', frequency: 2, lastAdded: DateTime(2024, 1, 3))],
          'frequent': <Product>[],
        },
      };

      final cloud = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [
            Product(id: 'lista_1_pan', name: 'Pan', frequency: 6, lastAdded: DateTime(2024, 1, 2)),
            Product(id: 'lista_1_leche', name: 'Leche', frequency: 1, lastAdded: DateTime(2024, 1, 4)),
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

    test('keeps empty lists so they exist in Firestore as soon as they are created', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista vacía': {'active': <Product>[], 'frequent': <Product>[]},
      };

      final cloud = <String, Map<String, List<Product>>>{
        'Lista vacía': {'active': <Product>[], 'frequent': <Product>[]},
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(local, cloud);

      expect(merged.containsKey('Lista vacía'), isTrue);
    });

    test('keeps the same list identity when it is renamed on another device', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista de compra': {
          'active': [Product(id: 'p1', name: 'Pan', frequency: 2, lastAdded: DateTime(2024, 2, 1))],
          'frequent': <Product>[],
        },
      };

      final cloud = <String, Map<String, List<Product>>>{
        'Lista de supermercado': {
          'active': [Product(id: 'p2', name: 'Leche', frequency: 3, lastAdded: DateTime(2024, 2, 3))],
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
      expect(merged.keys.single, 'Lista de supermercado');
      expect(merged.values.first['active']!.map((p) => p.name), ['Leche']);
    });

    test('does not resurrect a deleted product when local deletion timestamp is newer than cloud', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista 1': {'active': <Product>[], 'frequent': <Product>[]},
      };
      final cloud = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [Product(id: 'product-1', name: 'Pan', frequency: 1, lastAdded: DateTime(2024, 1, 1))],
          'frequent': <Product>[],
        },
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(
        local,
        cloud,
        localUpdatedAt: {'Lista 1': DateTime(2024, 1, 5)},
        cloudUpdatedAt: {'Lista 1': DateTime(2024, 1, 1)},
      );

      expect(merged['Lista 1']!['active'], isEmpty);
      expect(merged['Lista 1']!['frequent'], isEmpty);
    });

    test('removes a list when the deletion tombstone is newer than the local version', () {
      final local = <String, Map<String, List<Product>>>{
        'Lista antigua': {
          'active': [Product(id: 'p1', name: 'Pan', frequency: 1, lastAdded: DateTime(2024, 3, 1))],
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

    test('keeps a locally edited price even when lastAdded is unchanged', () {
      final added = DateTime(2024, 1, 1);
      final local = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [
            Product(
              id: 'p1',
              name: 'Pan',
              price: 2.5,
              pricePerKilo: 4,
              lastAdded: added,
              updatedAt: DateTime(2024, 1, 5),
            ),
          ],
          'frequent': <Product>[],
        },
      };
      final cloud = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [Product(id: 'p1', name: 'Pan', price: 1, pricePerKilo: 2, lastAdded: added)],
          'frequent': <Product>[],
        },
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(local, cloud);
      final pan = merged['Lista 1']!['active']!.single;

      expect(pan.price, 2.5);
      expect(pan.pricePerKilo, 4);
      expect(pan.lastAdded, added);
    });

    test('does not bring back a price that was cleared locally', () {
      final added = DateTime(2024, 1, 1);
      final local = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [
            Product(
              id: 'p1',
              name: 'Pan',
              price: null,
              pricePerKilo: null,
              lastAdded: added,
              updatedAt: DateTime(2024, 1, 5),
            ),
          ],
          'frequent': <Product>[],
        },
      };
      final cloud = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [Product(id: 'p1', name: 'Pan', price: 1, pricePerKilo: 2, lastAdded: added)],
          'frequent': <Product>[],
        },
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(local, cloud);
      final pan = merged['Lista 1']!['active']!.single;

      expect(pan.price, isNull);
      expect(pan.pricePerKilo, isNull);
    });

    test('keeps the cloud price when it was edited more recently', () {
      final added = DateTime(2024, 1, 1);
      final local = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [Product(id: 'p1', name: 'Pan', price: 1, lastAdded: added, updatedAt: DateTime(2024, 1, 3))],
          'frequent': <Product>[],
        },
      };
      final cloud = <String, Map<String, List<Product>>>{
        'Lista 1': {
          'active': [Product(id: 'p1', name: 'Pan', price: 3, lastAdded: added, updatedAt: DateTime(2024, 1, 4))],
          'frequent': <Product>[],
        },
      };

      final merged = ShoppingProvider.mergeShoppingListsForSync(
        local,
        cloud,
        localUpdatedAt: {'Lista 1': DateTime(2024, 1, 3)},
        cloudUpdatedAt: {'Lista 1': DateTime(2024, 1, 4)},
      );

      expect(merged['Lista 1']!['active']!.single.price, 3);
    });

    test('product prices and updatedAt survive Hive and Firestore maps', () {
      final product = Product(
        id: 'p1',
        name: 'Pan',
        price: 2.5,
        pricePerKilo: 4.75,
        lastAdded: DateTime(2024, 1, 1),
        updatedAt: DateTime(2024, 1, 5),
      );

      final fromHive = Product.fromMapHive(product.toMapHive());
      final fromCloud = Product.fromMap('p1', product.toMap());

      for (final restored in [fromHive, fromCloud]) {
        expect(restored.price, 2.5);
        expect(restored.pricePerKilo, 4.75);
        expect(restored.updatedAt, DateTime(2024, 1, 5));
        expect(restored.modifiedAt, DateTime(2024, 1, 5));
      }
      expect(
        Product.fromMapHive({
          'id': 'old',
          'name': 'Viejo',
          'lastAdded': DateTime(2024, 1, 1).toIso8601String(),
        }).modifiedAt,
        DateTime(2024, 1, 1),
      );
    });
  });
}
