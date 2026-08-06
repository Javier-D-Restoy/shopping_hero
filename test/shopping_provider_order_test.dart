import 'package:flutter_test/flutter_test.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';

void main() {
  test('renaming a list preserves its original position', () {
    final provider = ShoppingProvider();

    final before = provider.shoppingLists.keys.toList();
    expect(before, ['Mercadona', 'Aldi', 'Abuela']);

    provider.renameList('Aldi', 'Aldi Renombrada');

    final after = provider.shoppingLists.keys.toList();
    expect(after, ['Mercadona', 'Aldi Renombrada', 'Abuela']);
  });

  test('deleting a list removes it and updates the selected list', () {
    final provider = ShoppingProvider();

    provider.selectList('Aldi');
    provider.removeList('Aldi');

    expect(provider.shoppingLists.keys.toList(), ['Mercadona', 'Abuela']);
    expect(provider.selectedListName, 'Mercadona');
  });
}
