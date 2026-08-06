import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();
    final shoppingProvider = context.watch<ShoppingProvider>();
    final usernameController = TextEditingController();

    return ListView(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 90),
            Container(
              width: 180,
              height: 40,
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border(),
                boxShadow: [BoxShadow(color: Colors.grey, spreadRadius: 1.5)],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: Center(child: Text('Cambiar Username', style: TextStyle(fontSize: 18),)),
              ),
            ),
            const SizedBox(height: 5),
            Container(
              width: 180,
              height: 50,
              decoration: BoxDecoration(
                color: themeProvider.isDarkMode ? Colors.black : Colors.white,
                borderRadius: BorderRadius.circular(20),
                border: Border(),
                boxShadow: [BoxShadow(color: Colors.grey, spreadRadius: 1.5)],
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 5.0),
                child: TextField(
                  controller: usernameController,
                  onSubmitted: (value) {
                    shoppingProvider.changeUsername(usernameController.text);
                  },
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
