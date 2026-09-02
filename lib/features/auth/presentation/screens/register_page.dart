import 'package:flutter/material.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_manager_page.dart';

class RegisterPage extends StatelessWidget {
  const RegisterPage({super.key});

  @override
  Widget build(BuildContext context) {
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final displayNameController = TextEditingController();
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
                                      controller: displayNameController,
                                      decoration: const InputDecoration(labelText: 'Nombre'),
                                      onTapOutside: (event) {
                                        focusNode.unfocus();
                                      },
                                      validator: (value) {
                                        if (value == null || value.trim().isEmpty) {
                                          return 'Introduce tu nombre';
                                        }
                                        return null;
                                      },
                                    ),
                                    const SizedBox(height: 12),
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
                                        if (value.length < 6) {
                                          return 'Mínimo 6 caracteres';
                                        }
                                        return null;
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 50),
                            Consumer<SessionProvider>(
                              builder: (context, sessionProvider, _) {
                                return Column(
                                  children: [
                                    if (sessionProvider.errorMessage != null)
                                      Padding(
                                        padding: const EdgeInsets.only(bottom: 16),
                                        child: Text(
                                          sessionProvider.errorMessage!,
                                          style: const TextStyle(
                                              color: Colors.red, fontSize: 12),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ElevatedButton(
                                      onPressed: sessionProvider.isLoading
                                          ? null
                                          : () async {
                                              if (formKey.currentState!.validate()) {
                                                final success = await sessionProvider.register(
                                                  email: emailController.text,
                                                  password: passwordController.text,
                                                  displayName: displayNameController.text,
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
                                              child: CircularProgressIndicator(
                                                  strokeWidth: 2),
                                            )
                                          : const Text('Registrar'),
                                    ),
                                  ],
                                );
                              },
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