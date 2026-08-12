import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:shopping_hero/features/auth/presentation/screens/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    // final shoppingProvider = context.watch<ShoppingProvider>();
    final usernameController = TextEditingController();

    return ListView(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
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
                child: Center(
                  child: Text(
                    'Cambiar Username',
                    style: TextStyle(fontSize: 18),
                  ),
                ),
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
                    sessionProvider.changeUsername(usernameController.text);
                  },
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                _showRenameDialog();
              },
              child: Text('Liberar Caché Local'),
            ),
          ],
        ),
      ],
    );
  }

  void _showRenameDialog() {
    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Liberar Caché Local'),
          content: Text('Si haces esto, se va cagar la perra. Estás segurito?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                _handleResetLocalData(context);
              },
              child: const Text('Liberar')),
          ],
        );
      },
    );
  }

  Future<void> _handleResetLocalData(BuildContext context) async {
    final sessionProvider = context.read<SessionProvider>();
    final shoppingProvider = context.read<ShoppingProvider>();

    // 1. Borramos la sesión local en Hive
    await sessionProvider.resetLocalProfile();

    // 2. Borramos las listas del invitado en Hive
    await shoppingProvider.resetGuestData();

    // 3. Redirigimos al Login
    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }
}


