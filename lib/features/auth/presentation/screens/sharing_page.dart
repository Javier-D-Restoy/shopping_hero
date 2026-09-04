import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';

class SharingPage extends StatefulWidget {
  const SharingPage({super.key});

  @override
  State<SharingPage> createState() => _SharingPageState();
}

class _SharingPageState extends State<SharingPage> {
  final _emailController = TextEditingController();
  bool _isSharing = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _shareList() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() => _isSharing = true);
    try {
      await context.read<ShoppingProvider>().shareSelectedListWithEmail(email);
      if (!mounted) return;
      _emailController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lista compartida correctamente')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shoppingProvider = context.watch<ShoppingProvider>();
    final listName = shoppingProvider.selectedListName;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Compartir "$listName"',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(
            labelText: 'Email del usuario',
            hintText: 'usuario@ejemplo.com',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _isSharing ? null : _shareList,
          icon: _isSharing
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.person_add_alt_1),
          label: Text(_isSharing ? 'Compartiendo...' : 'Compartir lista'),
        ),
      ],
    );
  }
}