import 'package:flutter/material.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
// import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/features/auth/presentation/screens/register_page.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_manager_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final usernameController = TextEditingController();
    final passwordController = TextEditingController();
    final focusNode = FocusNode();

    final formKey = GlobalKey<FormState>();

    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 480),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 240,
                          height: 240,
                          child: Image.asset(
                            'assets/images/logos/Logo_ShoppingHero.png',
                            fit: BoxFit.contain,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Form(
                          key: formKey,
                          child: SizedBox(
                            width: 250,
                            child: Column(
                              children: [
                                TextFormField(
                                  controller: usernameController,
                                  decoration: const InputDecoration(labelText: 'Username'),
                                  // focusNode: focusNode,
                                  onTapOutside: (event) {
                                    focusNode.unfocus();
                                  },
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
                                  // focusNode: focusNode,
                                  onTapOutside: (event) {
                                    focusNode.unfocus();
                                  },
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
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () async {
                            if (formKey.currentState!.validate()) {
                              await context.read<SessionProvider>().continueWithProfile(
                                username: usernameController.text,
                                password: passwordController.text,
                              );

                              if (context.mounted) {
                                Navigator.pushReplacement(
                                  context,
                                  MaterialPageRoute(
                                    builder: (context) => const ListManager(),
                                  ),
                                );
                              }
                            }
                          },
                          child: const Text('Login'),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => RegisterPage()),
                              );
                            }
                          },
                          child: const Text(
                            'Aún no tienes cuenta, Pisha?',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 30),
                        TextButton(
                          onPressed: () async {
                            await context.read<SessionProvider>().continueOffline(
                              username: 'Shopping Hero',
                              password: '',
                            );
                            if (context.mounted) {
                              Navigator.pushReplacement(
                                context,
                                MaterialPageRoute(builder: (context) => const ListManager()),
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
          },
        ),
      ),
    );
  }
}