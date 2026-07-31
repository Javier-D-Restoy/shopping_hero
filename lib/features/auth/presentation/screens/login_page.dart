import 'package:flutter/material.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_manager_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 240,
                  height: 240,
                  child: Image.asset(
                    'assets/images/Logo_ShoppingHero.png',
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: 24),
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      TextFormField(
                        controller: usernameController,
                        decoration: const InputDecoration(labelText: 'Username'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Introduce tu username';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: passwordController,
                        decoration: const InputDecoration(labelText: 'Password'),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Introduce tu password';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      await context.read<ShoppingProvider>().continueWithProfile(
                        username: usernameController.text,
                        password: passwordController.text,
                      );

                      if (context.mounted) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ListManager(),
                          ),
                        );
                      }
                    }
                  },
                  child: const Text('Continuar'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    if (formKey.currentState!.validate()) {
                      context.read<ShoppingProvider>().continueOffline(
                            username: usernameController.text,
                            password: passwordController.text,
                          );                      
                    }
                  },
                  child: const Text('Modo Offline'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}