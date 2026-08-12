import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:shopping_hero/features/auth/presentation/screens/config_page.dart';
import 'package:shopping_hero/features/auth/presentation/screens/login_page.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/widgets/list_bubble.dart';

class ListManager extends StatefulWidget {
  const ListManager({super.key});

  @override
  State<ListManager> createState() => _ListManagerState();
}

class _ListManagerState extends State<ListManager> {
  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final shoppingProvider = context.watch<ShoppingProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final username = sessionProvider.username;
    final colors = Theme.of(context).colorScheme;
    final listNames = shoppingProvider.shoppingLists.keys.toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        leading: BackButton(
          onPressed: () {
            if (context.mounted) {
              context.read<SessionProvider>().clearSession();
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const LoginPage(),
                ),
              );
            }
          },
        ),
        title: Text(
          'Listas de $username',
          style: const TextStyle(fontSize: 18),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: (){
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ConfigPage()),
                );
              }
            },
            icon: Icon(Icons.settings)),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(
            themeProvider.isDarkMode ? 'assets/images/background/Background_Dark_Image_1.jpg'
            : 'assets/images/background/Background_Image_1.jpg',
            fit: BoxFit.cover,)),
          SafeArea(
            child: ListView(
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
                        productCount: shoppingProvider.activeProductsForList(listName).length, //shoppingProvider.productsForList(listName).length,
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
          ),
        ],
      )
    );
  }
}