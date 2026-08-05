import 'package:flutter/material.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_manager_page.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

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
            return Stack(
              children: [
                SingleChildScrollView(
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
                                'assets/images/logos/Logo_Register.png',
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
                            const SizedBox(height: 50),
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
                              child: const Text('Registrar'),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  top: 8,
                  left: 8,
                  child: BackButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}