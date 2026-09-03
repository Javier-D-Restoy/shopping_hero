import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/models/product_model.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:shopping_hero/features/auth/presentation/screens/config_page.dart';
import 'package:shopping_hero/features/auth/presentation/screens/profile_page.dart';
import 'package:shopping_hero/features/auth/presentation/screens/sharing_page.dart';
import 'package:shopping_hero/features/products/presentation/widgets/product_bubble.dart';
import 'package:shopping_hero/shared/widgets/main_bottom_nav.dart';

class ListMainPage extends StatefulWidget {
  const ListMainPage({super.key, required this.listName});

  final String listName;

  @override
  State<ListMainPage> createState() => _ListMainPageState();
}

class _ListMainPageState extends State<ListMainPage> {
  final TextEditingController _productNameController = TextEditingController();
  final focusNode = FocusNode();

  int _selectedIndex = 0;
  final Map<String, ProductAdd> _productLocations = {};
  bool _initialProductsRegistered = false;

  bool _shouldAnimateProduct(Product product, ProductAdd location) {
    final previousLocation = _productLocations[product.id];
    _productLocations[product.id] = location;

    if (!_initialProductsRegistered) return false;
    return previousLocation == null || previousLocation != location;
  }

  String _syncTooltip(ShoppingProvider provider) {
    switch (provider.syncStatus) {
      case ShoppingSyncStatus.offline:
        return 'Modo offline';
      case ShoppingSyncStatus.syncing:
        return 'Sincronizando...';
      case ShoppingSyncStatus.synced:
        final lastSyncedAt = provider.lastSyncedAt;
        if (lastSyncedAt == null) return 'Sincronizado';
        final hour = lastSyncedAt.hour.toString().padLeft(2, '0');
        final minute = lastSyncedAt.minute.toString().padLeft(2, '0');
        return 'Sincronizado a las $hour:$minute';
      case ShoppingSyncStatus.error:
        return 'Error de sincronización. Toca para reintentar';
    }
  }

  IconData _syncIcon(ShoppingProvider provider) {
    switch (provider.syncStatus) {
      case ShoppingSyncStatus.offline:
        return Icons.cloud_off_outlined;
      case ShoppingSyncStatus.syncing:
        return Icons.sync;
      case ShoppingSyncStatus.synced:
        return Icons.cloud_done_outlined;
      case ShoppingSyncStatus.error:
        return Icons.cloud_off_outlined;
    }
  }

  Color _syncColor(ShoppingProvider provider) {
    switch (provider.syncStatus) {
      case ShoppingSyncStatus.offline:
        return Colors.grey;
      case ShoppingSyncStatus.syncing:
        return Colors.orange;
      case ShoppingSyncStatus.synced:
        return Colors.green;
      case ShoppingSyncStatus.error:
        return Colors.red;
    }
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final shoppingProvider = context.watch<ShoppingProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    // final activeProducts = shoppingProvider.productsForList(widget.listName);  <- PARA LISTA ANTIGUA. QUITAR
    final activeProducts2 = shoppingProvider.activeProductsForList(
      widget.listName,
    );
    final frequentProducts2 = shoppingProvider.frequentProductsForList(
      widget.listName,
    );

    // 1. Obtener las dimensiones totales combinando la altura visible y el teclado
    // final double screenWidth = MediaQuery.of(context).size.width;
    // final double screenHeight =
    //     MediaQuery.of(context).size.height +
    //     MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 40,
        title: Text(
          _selectedIndex == 0
              ? widget.listName
              : _selectedIndex == 1
              ? 'Perfil'
              : 'Compartido',
        ),
        centerTitle: true,
        actions: [
          Tooltip(
            message: _syncTooltip(shoppingProvider),
            child: IconButton(
              onPressed: shoppingProvider.syncStatus == ShoppingSyncStatus.error
                  ? () => shoppingProvider.saveToStorage()
                  : null,
              icon: Icon(
                _syncIcon(shoppingProvider),
                color: _syncColor(shoppingProvider),
              ),
            ),
          ),
          IconButton(
            onPressed: () {
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ConfigPage()),
                );
              }
            },
            icon: Icon(Icons.settings),
          ),
        ],
      ),
      body: Stack(
        children: [
          if (_selectedIndex == 0)
            Positioned.fill(
              child: Image.asset(
                'assets/images/background/Background_Image_2.png',
                fit: BoxFit.cover,
              ),
            ),
          if (_selectedIndex == 1)
            Positioned.fill(
              child: Image.asset(
                'assets/images/background/Background_Profile_Image_1.png',
                fit: BoxFit.cover,
              ),
            ),
          if (_selectedIndex == 2)
            Positioned.fill(
              child: Image.asset(
                'assets/images/background/Background_Image_4.png',
                fit: BoxFit.cover,
              ),
            ),
          SizedBox(height: 10),
          IndexedStack(
            index: _selectedIndex,
            children: [
              _buildListContent(
                activeProducts2,
                frequentProducts2,
                shoppingProvider,
                themeProvider,
              ),
              const ProfilePage(),
              const SharingPage(),
            ],
          ),
        ],
      ),
      bottomNavigationBar: () {
        // Detecta si el teclado está abierto
        final isKeyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;

        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: _selectedIndex == 0
              ? SafeArea(
                  top: false,
                  // Si el teclado está abierto, quitamos el safeArea inferior para que quede pegado
                  bottom: !isKeyboardOpen,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        decoration: BoxDecoration(
                          color: themeProvider.isDarkMode
                              ? Colors.black
                              : Colors.white,
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
                              child: TextFormField(
                                controller: _productNameController,
                                onTapOutside: (event) {
                                  focusNode.unfocus();
                                },
                                focusNode: focusNode,
                                decoration: const InputDecoration(
                                  hintText: 'Me hace falta...',
                                  border: OutlineInputBorder(),
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                ),
                                onFieldSubmitted: (value) {
                                  _addProduct(shoppingProvider);
                                  focusNode.requestFocus();
                                },
                              ),
                            ),
                            const SizedBox(width: 8),
                            ElevatedButton(
                              onPressed: () => _addProduct(shoppingProvider),
                              child: Center(
                                heightFactor: 1,
                                widthFactor: 0,
                                child: Padding(
                                  padding: const EdgeInsets.only(bottom: 4.5),
                                  child: const Text(
                                    '+',
                                    style: TextStyle(
                                      fontSize: 30,
                                      fontWeight: FontWeight(1000),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Solo se muestra el BottomNav si el teclado está CERRADO
                      if (!isKeyboardOpen)
                        MainBottomNav(
                          currentIndex: _selectedIndex,
                          showSharedTab: sessionProvider.isLoggedIn,
                          onTap: _onNavigationTap,
                        ),
                    ],
                  ),
                )
              : SafeArea(
                  top: false,
                  child: MainBottomNav(
                    currentIndex: _selectedIndex,
                    showSharedTab: sessionProvider.isLoggedIn,
                    onTap: _onNavigationTap,
                  ),
                ),
        );
      }(),
    );
  }

  Widget _buildListContent(
    List<Product> activeProducts,
    List<Product> frequentProducts,
    ShoppingProvider shoppingProvider,
    ThemeProvider themeProvider,
  ) {
    if (!_initialProductsRegistered) {
      for (final product in activeProducts) {
        _productLocations[product.id] = ProductAdd.active;
      }
      for (final product in frequentProducts) {
        _productLocations[product.id] = ProductAdd.frequent;
      }
      _initialProductsRegistered = true;
    }

    return Padding(
      padding: const EdgeInsets.only(left: 12, right: 12),
      child: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(child: SizedBox(height: 12)),
          SliverGrid.builder(
            // ------------------------ ][ PRODUCTOS ACTIVOS ][ ------------------------ //
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: activeProducts.length,
            itemBuilder: (context, index) {
              final product = activeProducts[index];
              return ProductBubble(
                key: ValueKey('${product.id}-active'),
                label: product.name,
                amount: product.amount,
                productAdd: ProductAdd.active,
                animateOnEntry: _shouldAnimateProduct(product, ProductAdd.active),
                onLongPress: () => _showProductEditor(shoppingProvider, product),
                onTap: () => _removeActiveProduct(
                  shoppingProvider,
                  product.id,
                ),
              );
            },
          ),
          if (frequentProducts.isNotEmpty)
            SliverToBoxAdapter(
              // ------------------------ ][ PRODUCTOS FRECUENTES ][ ------------------------ //
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 30,
                  bottom: 10,
                  left: 5,
                  right: 5,
                ),
                child: Container(
                  width: 100,
                  height: 35,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: Border(),
                    boxShadow: [
                      BoxShadow(
                        color: themeProvider.isDarkMode
                            ? Colors.blueGrey
                            : Colors.black,
                        spreadRadius: 1.5,
                      ),
                    ],
                    color: themeProvider.isDarkMode
                        ? Colors.black
                        : Colors.white,
                  ),
                  child: Center(
                    child: Text(
                      'Productos Frecuentes',
                      style: TextStyle(
                        fontSize: 20,
                        letterSpacing: 1.0,
                        wordSpacing: 5.0,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          if (frequentProducts.isNotEmpty)
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: 1,
              ),
              itemCount: frequentProducts.length,
              itemBuilder: (context, index) {
                final product = frequentProducts[index];
                return ProductBubble(
                  key: ValueKey('${product.id}-frequent'),
                  label: product.name,
                  amount: product.amount,
                  productAdd: ProductAdd.frequent,
                  animateOnEntry: _shouldAnimateProduct(product, ProductAdd.frequent),
                  onLongPress: () => _showProductEditor(shoppingProvider, product),
                  onTap: () => _removeFrequentProduct(
                    shoppingProvider,
                    product.id,
                  ),
                );
              },
            ),
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Text('Otro elemento'),
                  // SizedBox(height: 10),
                  // Text('Otro elemento'),
                  // SizedBox(height: 10),
                  // Text('Otro elemento'),
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

    shoppingProvider.addActiveProductToSelectedList(
      name,
    ); // Lista Actualizada: Active + Frequent
    _productNameController.clear();
  }

  void _removeActiveProduct(
    ShoppingProvider shoppingProvider,
    String productId,
  ) {
    shoppingProvider.moveActiveProductToFrequentSelectedList(productId);
  }

  void _removeFrequentProduct(
    ShoppingProvider shoppingProvider,
    String productId,
  ) {
    shoppingProvider.moveFrequentProductToActiveSelectedList(productId);
  }

  Future<void> _showProductEditor(
    ShoppingProvider shoppingProvider,
    Product product,
  ) async {
    final nameController = TextEditingController(text: product.name);
    final frequencyController = TextEditingController(
      text: product.frequency.toString(),
    );
    final priceController = TextEditingController(
      text: product.price?.toString() ?? '',
    );
    final amountController = TextEditingController(
      text: product.amount.toString(),
    );
    final imageUrlController = TextEditingController(text: product.imageUrl ?? '');

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (context) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              top: 20,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Editar producto',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    maxLength: 35,
                    autofocus: true,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(
                      labelText: 'Nombre',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: frequencyController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Frecuencia',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: amountController,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Cantidad',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: priceController,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(
                            labelText: 'Precio',
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: imageUrlController,
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'URL de imagen',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            final name = nameController.text.trim();
                            final frequency = int.tryParse(frequencyController.text.trim());
                            final amount = int.tryParse(amountController.text.trim());
                            final priceText = priceController.text.trim().replaceAll(',', '.');
                            final price = priceText.isEmpty ? null : double.tryParse(priceText);

                            if (name.isEmpty || frequency == null || frequency < 0 ||
                                amount == null || amount < 0 ||
                                (priceText.isNotEmpty && price == null)) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Revisa los datos del producto')),
                              );
                              return;
                            }

                            shoppingProvider.updateProduct(
                              shoppingProvider.selectedListName,
                              product.id,
                              name: name,
                              frequency: frequency,
                              amount: amount,
                              price: price,
                              imageUrl: imageUrlController.text.trim().isEmpty
                                  ? null
                                  : imageUrlController.text.trim(),
                            );
                            Navigator.of(context).pop();
                          },
                          icon: const Icon(Icons.save_outlined),
                          label: const Text('Guardar'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            shoppingProvider.deleteProduct(
                              shoppingProvider.selectedListName,
                              product.id,
                            );
                            Navigator.of(context).pop();
                          },
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.red,
                            foregroundColor: Colors.white,
                          ),
                          icon: const Icon(Icons.delete_outline),
                          label: const Text('Borrar'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    } finally {
      nameController.dispose();
      frequencyController.dispose();
      priceController.dispose();
      imageUrlController.dispose();
    }
  }

  void _onNavigationTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
