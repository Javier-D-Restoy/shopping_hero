import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/features/auth/presentation/screens/profile_page.dart';
import 'package:shopping_hero/features/auth/presentation/screens/sharing_page.dart';
import 'package:shopping_hero/features/products/presentation/widgets/product_bubble.dart';
import 'package:shopping_hero/shared/widgets/main_bottom_nav.dart';

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
        title: Text(
          _selectedIndex == 0
              ? widget.listName
              : _selectedIndex == 1
                  ? 'Profile'
                  : 'Compartido',
        ),
        centerTitle: true,
      ),
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          _buildListContent(products, shoppingProvider),
          const ProfilePage(),
          const SharingPage(),
        ],
      ),
      bottomNavigationBar: _selectedIndex == 0
          ? SafeArea(
              top: false,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
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
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _productNameController,
                            onTapOutside: (event) {
                              focusNode.unfocus();
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
                  ),
                  MainBottomNav(
                    currentIndex: _selectedIndex,
                    showSharedTab: shoppingProvider.isLoggedIn,
                    onTap: _onNavigationTap,
                  ),
                ],
              ),
            )
          : SafeArea(
              top: false,
              child: MainBottomNav(
                currentIndex: _selectedIndex,
                showSharedTab: shoppingProvider.isLoggedIn,
                onTap: _onNavigationTap,
              ),
            ),
    );
  }

  Widget _buildListContent(
    List<String> products,
    ShoppingProvider shoppingProvider,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: CustomScrollView(
        slivers: [
          SliverGrid.builder(
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
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
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