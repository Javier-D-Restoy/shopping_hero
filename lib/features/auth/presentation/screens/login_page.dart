import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/features/auth/presentation/screens/register_page.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_manager_page.dart';

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
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
                                  controller: emailController,
                                  decoration: const InputDecoration(labelText: 'Email'),
                                  keyboardType: TextInputType.emailAddress,
                                  onTapOutside: (event) {
                                    focusNode.unfocus();
                                  },
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Introduce tu email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Email inválido';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 12),
                                TextFormField(
                                  controller: passwordController,
                                  decoration: const InputDecoration(labelText: 'Password'),
                                  obscureText: true,
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
                        Consumer<SessionProvider>(
                          builder: (context, sessionProvider, _) {
                            return Column(
                              children: [
                                if (sessionProvider.errorMessage != null)
                                  Padding(
                                    padding: const EdgeInsets.only(bottom: 16),
                                    child: Text(
                                      sessionProvider.errorMessage!,
                                      style: const TextStyle(color: Colors.red, fontSize: 12),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ElevatedButton(
                                  onPressed: sessionProvider.isLoading
                                      ? null
                                      : () async {
                                          if (formKey.currentState!.validate()) {
                                            final success = await sessionProvider.login(
                                              email: emailController.text,
                                              password: passwordController.text,
                                            );

                                            if (!context.mounted) return;

                                            if (success) {
                                              final shoppingProvider =
                                                  context.read<ShoppingProvider>();
                                              await shoppingProvider.setCurrentUser(
                                                sessionProvider.uid,
                                                isOffline: false,
                                              );
                                              await shoppingProvider.switchUserEnvironment(
                                                isOffline: false,
                                              );

                                              if (!context.mounted) return;

                                              Navigator.pushReplacement(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) => const ListManager(),
                                                ),
                                              );
                                            }
                                          }
                                        },
                                  child: sessionProvider.isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(strokeWidth: 2),
                                        )
                                      : const Text('Login'),
                                ),
                              ],
                            );
                          },
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            if (context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(builder: (context) => const RegisterPage()),
                              );
                            }
                          },
                          child: const Text(
                            'Aún no tienes cuenta, Pisha?',
                            style: TextStyle(fontSize: 13),
                          ),
                        ),
                        const SizedBox(height: 30),
                        Consumer<SessionProvider>(
                          builder: (context, sessionProvider, _) {
                            return TextButton(
                              onPressed: sessionProvider.isLoading
                                  ? null
                                  : () async {
                                      final success = await sessionProvider.continueOffline(
                                        displayName: 'Usuario Offline',
                                      );

                                      if (!context.mounted) return;

                                      if (success) {
                                        final shoppingProvider =
                                            context.read<ShoppingProvider>();
                                        await shoppingProvider.clearCurrentUser();
                                        await shoppingProvider.switchUserEnvironment(
                                          isOffline: true,
                                        );

                                        if (!context.mounted) return;

                                        Navigator.pushReplacement(
                                          context,
                                          MaterialPageRoute(
                                            builder: (context) => const ListManager(),
                                          ),
                                        );
                                      }
                                    },
                              child: const Text('Modo Offline'),
                            );
                          },
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