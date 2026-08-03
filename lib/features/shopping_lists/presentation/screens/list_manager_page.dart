import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/widgets/list_bubble.dart';

class ListManager extends StatefulWidget {
  const ListManager({super.key});

  @override
  State<ListManager> createState() => _ListManagerState();
}

class _ListManagerState extends State<ListManager> {
  @override
  Widget build(BuildContext context) {
    final shoppingProvider = context.watch<ShoppingProvider>();
    final username = shoppingProvider.username;
    final colors = Theme.of(context).colorScheme;
    final listNames = shoppingProvider.shoppingLists.keys.toList();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlueAccent,
        leading: BackButton(
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text(
          'Listas de $username',
          style: const TextStyle(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ...listNames.map((listName) {
                return ListBubble(
                  colors: colors,
                  listName: listName,
                  productCount: shoppingProvider.productsForList(listName).length,
                  onRename: (newName) {
                    shoppingProvider.renameList(listName, newName);
                  },
                );
              }),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () {
                  shoppingProvider.createList();
                },
                icon: const Icon(Icons.add),
                label: const Text('Crear lista'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}