import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/features/products/presentation/widgets/product_bubble.dart';

class ListMainPage extends StatefulWidget {
  const ListMainPage({
    super.key,
    required this.listName,
  });

  final String listName;

  @override
  State<ListMainPage> createState() => _ListMainPageState();
}

class _ListMainPageState extends State<ListMainPage> {
  final TextEditingController _productNameController = TextEditingController();
  final focusNode = FocusNode();

  int _selectedIndex = 0;
  
  @override
  Widget build(BuildContext context) {
    final shoppingProvider = context.watch<ShoppingProvider>();
    final products = shoppingProvider.productsForList(widget.listName);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.listName),
        centerTitle: true,
      ),
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(12),
            sliver: SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: products.length,
              itemBuilder: (context, index) {
                return ProductBubble(
                  label: products[index],
                  onTap: () => _removeProduct(shoppingProvider, products[index]),
                );
              },
            ),
          ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Otro elemento'),
                  SizedBox(height: 10),
                  Text('Otro elemento'),
                  SizedBox(height: 10),
                  Text('Otro elemento'),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 6,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _productNameController,
                      onTapOutside: (event) {
                        focusNode.unfocus();  // si toco fuera del formulario, remuevo el foco
                      },
                      focusNode: focusNode,
                      decoration: const InputDecoration(
                        hintText: 'Nombre del producto',
                        border: OutlineInputBorder(),
                        contentPadding: EdgeInsets.symmetric(horizontal: 12),
                      ),
                      onSubmitted: (value) {
                        focusNode.requestFocus();
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _addProduct(shoppingProvider),
                    child: const Text('Add'),
                    
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _buildNavigationButton(Icons.home, 'Inicio', 0),
                  _buildNavigationButton(Icons.list, 'Listas', 1),
                  _buildNavigationButton(Icons.settings, 'Ajustes', 2),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavigationButton(
    IconData icon,
    String label,
    int index,
  ) {
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: InkWell(
        onTap: () => _onNavigationTap(index),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected ? Colors.orange.shade100 : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isSelected ? Colors.orange : Colors.grey),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.orange : Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _addProduct(ShoppingProvider shoppingProvider) {
    final name = _productNameController.text.trim();
    if (name.isEmpty) return;

    shoppingProvider.addProductToList(widget.listName, name);
    _productNameController.clear();
  }

  void _removeProduct(
    ShoppingProvider shoppingProvider,
    String productName,
  ) {
    shoppingProvider.removeProductFromList(widget.listName, productName);
  }

  void _onNavigationTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  } 
}