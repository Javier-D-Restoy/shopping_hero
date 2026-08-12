import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
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
    List<String> activeProducts,
    List<String> frequentProducts,
    ShoppingProvider shoppingProvider,
    ThemeProvider themeProvider,
  ) {
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
              return ProductBubble(
                label: activeProducts[index],
                productAdd: ProductAdd.active,
                onTap: () => _removeActiveProduct(
                  shoppingProvider,
                  activeProducts[index],
                ), //_removeProduct(shoppingProvider, products[index]),
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
                ), //symmetric(vertical: 15.0, horizontal: 5.0),
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
                        // fontWeight: FontWeight(600),
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
                return ProductBubble(
                  label: frequentProducts[index],
                  productAdd: ProductAdd.frequent,
                  onTap: () => _removeFrequentProduct(
                    shoppingProvider,
                    frequentProducts[index],
                  ), //_removeProduct(shoppingProvider, products[index]),
                );
              },
            ), // ----------------------------------------------------------------------- //
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
    String productName,
  ) {
    shoppingProvider.removeActiveProductFromSelectedList(
      productName,
    ); // Lista Actualizada: Active + Frequent
    shoppingProvider.addFrequentProductToSelectedList(productName);
  }

  void _removeFrequentProduct(
    ShoppingProvider shoppingProvider,
    String productName,
  ) {
    shoppingProvider.removeFrequentProductFromSelectedList(
      productName,
    ); // Lista Actualizada: Active + Frequent
    shoppingProvider.addActiveProductToSelectedList(productName);
  }

  void _onNavigationTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
