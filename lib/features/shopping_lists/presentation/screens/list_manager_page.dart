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
    final username = context.watch<ShoppingProvider>().username;

    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.lightBlueAccent,
        leading: BackButton(
          onPressed: () {
            Navigator.pop(context);
          },
        ),
        title: Text('Listas de $username', style: TextStyle(fontSize: 20),
        ),
        centerTitle: true,

      ),
      body: ListView(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              ListBubble(colors: colors),
              Container(
                height: 20,
                width: 20,
                color: Colors.red,
              ),
              Container(
                height: 20,
                width: 20,
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}