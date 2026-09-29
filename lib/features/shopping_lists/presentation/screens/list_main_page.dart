import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/models/product_model.dart';
import 'package:shopping_hero/core/models/product_sort_option.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:shopping_hero/features/auth/presentation/screens/config_page.dart';
import 'package:shopping_hero/features/auth/presentation/screens/profile_page.dart';
import 'package:shopping_hero/features/auth/presentation/screens/sharing_page.dart';
import 'package:shopping_hero/features/products/presentation/widgets/product_bubble.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_manager_page.dart';
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

  @override
  void initState() {
    super.initState();
    context.read<SessionProvider>().setLastRoute(
      route: 'listMain',
      listName: widget.listName,
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ShoppingProvider>().syncNow();
    });
  }

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

    // Validación de existencia de la lista actual
    if (!shoppingProvider.shoppingLists.containsKey(widget.listName)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        // 1. Mostrar un aviso informativo al usuario
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('La lista "${widget.listName}" ha sido eliminada por el propietario.'),
            backgroundColor: themeProvider.dangerColor,
          ),
        );

        // 2. Redirigir hacia ListManager reemplazando la ruta actual
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const ListManager()),
        );
      });

      // Retornar un Scaffold temporal mientras se procesa el callback de navegación
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final activeProducts2 = shoppingProvider.activeProductsForList(
      widget.listName,
    );
    final frequentProducts2 = shoppingProvider.frequentProductsForList(
      widget.listName,
    );

    final viewInsetsBottom = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = viewInsetsBottom > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 40,
        elevation: 2,
        shadowColor: themeProvider.cardShadowColor,
        leading: BackButton(
          onPressed: () async {
            await context.read<ShoppingProvider>().saveToStorage(
              mergeCloud: false,
            );
            if (context.mounted) {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const ListManager()),
              );
            }
          },
        ),
        title: AutoSizeText(
          _selectedIndex == 0
              ? widget.listName
              : _selectedIndex == 1
              ? 'Perfil'
              : 'Compartido',
          maxLines: 1,
          minFontSize: 10,
          stepGranularity: 1,
          overflow: TextOverflow.ellipsis,
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
                  MaterialPageRoute(builder: (context) => const ConfigPage()),
                );
              }
            },
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Stack(
        children: [
          SizedBox.expand(
            child: OverflowBox(
              alignment: Alignment.topCenter,
              minWidth: MediaQuery.of(context).size.width,
              maxWidth: MediaQuery.of(context).size.width,
              minHeight: MediaQuery.of(context).size.height * 0.83,
              maxHeight: MediaQuery.of(context).size.height,
              child: Image.asset(
                _selectedIndex == 0
                    ? 'assets/images/background/Background_Image_2.png'
                    : _selectedIndex == 1
                    ? 'assets/images/background/Background_Profile_Image_1.png'
                    : 'assets/images/background/Background_Sharing_Image_1.jpg',
                fit: BoxFit.cover,
              ),
            ),
          ),
          RefreshIndicator(
            color: themeProvider.primaryColor,
            onRefresh: shoppingProvider.refreshFromCloud,
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildListContent(
                  activeProducts2,
                  frequentProducts2,
                  shoppingProvider,
                  themeProvider,
                ),
                const ProfilePage(),
                SharingPage(listName: widget.listName),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: EdgeInsets.only(bottom: viewInsetsBottom),
        child: _selectedIndex == 0
            ? SafeArea(
                top: false,
                bottom: !isKeyboardOpen,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: const BorderRadiusDirectional.vertical(
                          top: Radius.circular(18),
                        ),
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
                      padding: EdgeInsets.fromLTRB(
                        12,
                        10,
                        12,
                        _selectedIndex == 0 ? 10 : 2,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _productNameController,
                              textCapitalization: TextCapitalization.sentences,
                              maxLength: 30,
                              onTapOutside: (event) {
                                focusNode.unfocus();
                              },
                              focusNode: focusNode,
                              decoration: InputDecoration(
                                hintText: 'Me hace falta...',
                                counterText: '',
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                filled: true,
                                fillColor: themeProvider.surface,
                                labelStyle: TextStyle(
                                  color: themeProvider.textMutedColor,
                                ),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: themeProvider.borderColor,
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: themeProvider.borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                  borderSide: BorderSide(
                                    color: themeProvider.primaryColor,
                                    width: 1.8,
                                  ),
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
                            style: ElevatedButton.styleFrom(elevation: 3),
                            child: Center(
                              heightFactor: 0.9,
                              widthFactor: 0,
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4.5),
                                child: Text(
                                  '+',
                                  style: TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    color: themeProvider.primaryColor,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
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
      ),
    );
  }

  Widget _buildSortButton(
    ShoppingProvider shoppingProvider,
    ThemeProvider themeProvider,
  ) {
    final currentOption = shoppingProvider.sortOptionForList(widget.listName);

    return PopupMenuButton<ProductSortOption>(
      initialValue: currentOption,
      tooltip: 'Ordenar productos',
      color: themeProvider.surfaceSoft,
      elevation: 6,
      shadowColor: themeProvider.cardShadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: themeProvider.borderColor, width: 1.5),
      ),
      onSelected: (option) {
        shoppingProvider.setSortOptionForList(widget.listName, option);
      },
      itemBuilder: (context) => ProductSortOption.values
          .map(
            (option) => PopupMenuItem<ProductSortOption>(
              value: option,
              child: Row(
                children: [
                  if (option == currentOption)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: themeProvider.primaryColor,
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(
                    option.label,
                    style: TextStyle(
                      color: themeProvider.textStrongColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: themeProvider.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.symmetric(
            horizontal: BorderSide(color: themeProvider.borderColor, width: 1),
            vertical: BorderSide(color: themeProvider.borderColor, width: 5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 18, color: themeProvider.primaryColor),
            const SizedBox(width: 6),
            Text(
              currentOption.label,
              style: TextStyle(
                fontSize: 13,
                color: themeProvider.textStrongColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: themeProvider.textMutedColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFrequentSortButton(
    ShoppingProvider shoppingProvider,
    ThemeProvider themeProvider,
  ) {
    final currentOption = shoppingProvider.frequentSortOption;

    return PopupMenuButton<FrequentSortOption>(
      initialValue: currentOption,
      tooltip: 'Ordenar productos frecuentes',
      color: themeProvider.surfaceSoft,
      elevation: 6,
      shadowColor: themeProvider.cardShadowColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: themeProvider.borderColor, width: 1.5),
      ),
      onSelected: (option) {
        shoppingProvider.setFrequentSortOption(widget.listName, option);
      },
      itemBuilder: (context) => FrequentSortOption.values
          .map(
            (option) => PopupMenuItem<FrequentSortOption>(
              value: option,
              child: Row(
                children: [
                  if (option == currentOption)
                    Icon(
                      Icons.check,
                      size: 18,
                      color: themeProvider.primaryColor,
                    )
                  else
                    const SizedBox(width: 18),
                  const SizedBox(width: 8),
                  Text(
                    option.displayName,
                    style: TextStyle(
                      color: themeProvider.textStrongColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          )
          .toList(),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: themeProvider.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.symmetric(
            horizontal: BorderSide(color: themeProvider.borderColor, width: 1),
            vertical: BorderSide(color: themeProvider.borderColor, width: 5),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.sort, size: 18, color: themeProvider.primaryColor),
            const SizedBox(width: 6),
            Text(
              currentOption.displayName,
              style: TextStyle(
                fontSize: 13,
                color: themeProvider.textStrongColor,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.arrow_drop_down,
              size: 20,
              color: themeProvider.textMutedColor,
            ),
          ],
        ),
      ),
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
      padding: const EdgeInsets.only(left: 8, right: 8),
      child: CustomScrollView(
        slivers: [
          const SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverToBoxAdapter(
            child: Align(
              alignment: Alignment.centerRight,
              child: _buildSortButton(shoppingProvider, themeProvider),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 6)),
          SliverGrid.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: activeProducts.length,
            itemBuilder: (context, index) {
              final product = activeProducts[index];

              // 1. Obtener la lista ordenada de categorías y el estado compartido
              final categories = shoppingProvider.categoriesForList(
                widget.listName,
              );
              final isShared = shoppingProvider.isSharedList(widget.listName);

              // 2. Obtener la categoría del producto actual
              final cat = product.getCategory(isShared: isShared);

              // 3. Asignar el color según el índice
              final categoryColor = themeProvider.getCategoryColor(
                cat,
                categories,
              );

              return ProductBubble(
                key: ValueKey('${product.id}-active'),
                label: product.name,
                amount: product.amount,
                icon: product.icon,
                productAdd: ProductAdd.active,
                categoryColor: categoryColor,
                animateOnEntry: _shouldAnimateProduct(
                  product,
                  ProductAdd.active,
                ),
                onLongPress: () => _showProductEditor(
                  shoppingProvider,
                  themeProvider,
                  product,
                ),
                onTap: () => _removeActiveProduct(shoppingProvider, product.id),
              );
            },
          ),
          if (frequentProducts.isNotEmpty)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.only(
                  top: 20,
                  bottom: 8,
                  left: 5,
                  right: 5,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Container(
                        height: 35,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
                          border: Border.symmetric(
                            horizontal: BorderSide(
                              color: themeProvider.borderColor,
                              width: 1,
                            ),
                            vertical: BorderSide(
                              color: themeProvider.borderColor,
                              width: 5,
                            ),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeProvider.borderColor,
                              spreadRadius: 1.5,
                            ),
                          ],
                          color: themeProvider.surface,
                          // gradient: LinearGradient(
                          //   begin: Alignment.topLeft,
                          //   end: Alignment.bottomRight,
                          //   colors: themeProvider.gradientColors2,
                          // ),
                        ),
                        child: Center(
                          child: Stack(
                            children: [
                              Text(
                                'Frecuentes',
                                style: TextStyle(
                                  // color: Colors.black,
                                  fontSize: 20,
                                  letterSpacing: 1.0,
                                  wordSpacing: 3.0,
                                  fontWeight: FontWeight.w600,
                                  foreground: Paint()
                                    ..style = PaintingStyle.stroke
                                    ..strokeWidth = 0.5
                                    ..color = themeProvider.primaryColor,
                                  shadows: [
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.2,
                                      ),
                                      blurRadius: 4,
                                      offset: Offset(0, 0),
                                    ),
                                    Shadow(
                                      color: Colors.black.withValues(
                                        alpha: 0.1,
                                      ),
                                      blurRadius: 2,
                                      offset: Offset(0, 0),
                                    ),
                                  ],
                                ),
                              ),
                              Text(
                                'Frecuentes',
                                style: TextStyle(
                                  color: themeProvider.textStrongColor,
                                  fontSize: 20,
                                  letterSpacing: 1.0,
                                  wordSpacing: 3.0,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: _buildFrequentSortButton(
                        shoppingProvider,
                        themeProvider,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (frequentProducts.isNotEmpty)
            SliverGrid.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 2,
                mainAxisSpacing: 2,
                childAspectRatio: 1,
              ),
              itemCount: frequentProducts.length,
              itemBuilder: (context, index) {
                final product = frequentProducts[index];
                return ProductBubble(
                  key: ValueKey('${product.id}-frequent'),
                  label: product.name,
                  amount: product.amount,
                  icon: product.icon,
                  productAdd: ProductAdd.frequent,
                  animateOnEntry: _shouldAnimateProduct(
                    product,
                    ProductAdd.frequent,
                  ),
                  onLongPress: () => _showProductEditor(
                    shoppingProvider,
                    themeProvider,
                    product,
                  ),
                  onTap: () =>
                      _removeFrequentProduct(shoppingProvider, product.id),
                );
              },
            ),
        ],
      ),
    );
  }

  void _addProduct(ShoppingProvider shoppingProvider) {
    final name = _productNameController.text.trim();
    if (name.isEmpty) return;

    shoppingProvider.addActiveProductToList(widget.listName, name);
    _productNameController.clear();
  }

  void _removeActiveProduct(
    ShoppingProvider shoppingProvider,
    String productId,
  ) {
    shoppingProvider.moveActiveProductToFrequent(widget.listName, productId);
  }

  void _removeFrequentProduct(
    ShoppingProvider shoppingProvider,
    String productId,
  ) {
    shoppingProvider.moveFrequentProductToActive(widget.listName, productId);
  }

  Future<void> _showProductEditor(
    ShoppingProvider shoppingProvider,
    ThemeProvider themeProvider,
    Product product,
  ) async {
    final isShared = shoppingProvider.isSharedList(widget.listName);

    final nameController = TextEditingController(text: product.name);
    final frequencyController = TextEditingController(
      text: product.frequency.toString(),
    );
    final priceController = TextEditingController(
      text: product.price?.toString() ?? '',
    );
    final pricePerKiloController = TextEditingController(
      text: product.pricePerKilo?.toString() ?? '',
    );
    final amountController = TextEditingController(
      text: product.amount.toString(),
    );
    final imageUrlController = TextEditingController(
      text: product.imageUrl ?? '',
    );

    String selectedCategory = product.getCategory(isShared: isShared);
    String? selectedIcon = product.icon;

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              final availableCategories = shoppingProvider.categoriesForList(
                widget.listName,
              );

              if (!availableCategories.contains(selectedCategory)) {
                selectedCategory = 'Genérico';
              }

              return Container(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: MediaQuery.of(context).viewInsets.bottom + 20,
                ),
                decoration: BoxDecoration(
                  color: themeProvider.surface,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  border: Border(
                    top: BorderSide(color: themeProvider.borderColor, width: 3),
                    left: BorderSide(
                      color: themeProvider.borderColor,
                      width: 1,
                    ),
                    right: BorderSide(
                      color: themeProvider.borderColor,
                      width: 1,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: themeProvider.cardShadowColor,
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Text(
                          'Editar producto',
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(
                                color: themeProvider.textStrongColor,
                                fontWeight: FontWeight.w600,
                              ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: nameController,
                        maxLength: 30,
                        decoration: InputDecoration(
                          labelText: 'Nombre',
                          counterText: '',
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(
                            color: themeProvider.textMutedColor,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: themeProvider.borderColor,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(
                              color: themeProvider.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            flex: 2,
                            child: InkWell(
                              onTap: () async {
                                FocusManager.instance.primaryFocus?.unfocus();

                                final selectedResult = await showDialog<String>(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (dialogContext) {
                                    return StatefulBuilder(
                                      builder: (context, setDialogState) {
                                        final currentCategories =
                                            shoppingProvider.categoriesForList(
                                              widget.listName,
                                            );
                                        final customCategoriesCount =
                                            currentCategories
                                                .where(
                                                  (cat) => cat != 'Genérico',
                                                )
                                                .length;
                                        final canReorder =
                                            customCategoriesCount > 1;

                                        return AlertDialog(
                                          backgroundColor:
                                              themeProvider.surface,
                                          elevation: 10,
                                          shadowColor:
                                              themeProvider.cardShadowColor,
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            side: BorderSide(
                                              color: themeProvider.borderColor,
                                              width: 1.5,
                                            ),
                                          ),
                                          titlePadding:
                                              const EdgeInsets.fromLTRB(
                                                14,
                                                24,
                                                14,
                                                0,
                                              ),
                                          contentPadding: const EdgeInsets.only(
                                            left: 14,
                                            right: 14,
                                            bottom: 14,
                                          ),
                                          title: const Center(
                                            child: Text(
                                              'Seleccionar Categoría',
                                              style: TextStyle(
                                                fontSize: 24,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                          ),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(
                                                maxHeight:
                                                    MediaQuery.of(
                                                      context,
                                                    ).size.height *
                                                    0.6,
                                              ),
                                              child: Builder(
                                                builder: (context) {
                                                  final scrollController =
                                                      ScrollController();
                                                  bool canScrollUp = false;
                                                  bool canScrollDown = false;

                                                  return StatefulBuilder(
                                                    builder: (context, setInnerState) {
                                                      void
                                                      updateScrollIndicators() {
                                                        if (!scrollController
                                                            .hasClients) {
                                                          return;
                                                        }
                                                        final maxScroll =
                                                            scrollController
                                                                .position
                                                                .maxScrollExtent;
                                                        final currentScroll =
                                                            scrollController
                                                                .offset;

                                                        final showUp =
                                                            currentScroll > 5;
                                                        final showDown =
                                                            maxScroll > 0 &&
                                                            currentScroll <
                                                                (maxScroll - 5);

                                                        if (showUp !=
                                                                canScrollUp ||
                                                            showDown !=
                                                                canScrollDown) {
                                                          setInnerState(() {
                                                            canScrollUp =
                                                                showUp;
                                                            canScrollDown =
                                                                showDown;
                                                          });
                                                        }
                                                      }

                                                      scrollController.addListener(
                                                        updateScrollIndicators,
                                                      );

                                                      WidgetsBinding.instance
                                                          .addPostFrameCallback((
                                                            _,
                                                          ) {
                                                            updateScrollIndicators();
                                                          });

                                                      return Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        children: [
                                                          AnimatedOpacity(
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      200,
                                                                ),
                                                            opacity: canScrollUp
                                                                ? 1.0
                                                                : 0.0,
                                                            child: SizedBox(
                                                              height: 22,
                                                              child: Center(
                                                                child: Icon(
                                                                  Icons
                                                                      .keyboard_arrow_up,
                                                                  size: 40,
                                                                  color: themeProvider
                                                                      .primaryColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 10,
                                                          ),
                                                          Flexible(
                                                            child: SingleChildScrollView(
                                                              controller:
                                                                  scrollController,
                                                              child: RadioGroup<String>(
                                                                groupValue:
                                                                    selectedCategory, // <- Aquí debe ser groupValue en lugar de value
                                                                onChanged:
                                                                    (
                                                                      String?
                                                                      val,
                                                                    ) {
                                                                      if (val !=
                                                                          null) {
                                                                        Navigator.pop(
                                                                          dialogContext,
                                                                          val,
                                                                        );
                                                                      }
                                                                    },
                                                                child: Column(
                                                                  children: currentCategories.map((
                                                                    cat,
                                                                  ) {
                                                                    return Padding(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        vertical:
                                                                            2.0,
                                                                      ),
                                                                      child: Row(
                                                                        children: [
                                                                          Expanded(
                                                                            child: InkWell(
                                                                              borderRadius: BorderRadius.circular(
                                                                                8,
                                                                              ),
                                                                              onTap: () {
                                                                                Navigator.pop(
                                                                                  dialogContext,
                                                                                  cat,
                                                                                );
                                                                              },
                                                                              child: Padding(
                                                                                padding: const EdgeInsets.symmetric(
                                                                                  vertical: 4.0,
                                                                                ),
                                                                                child: Row(
                                                                                  children: [
                                                                                    Radio<
                                                                                      String
                                                                                    >(
                                                                                      value: cat,
                                                                                    ),
                                                                                    Expanded(
                                                                                      child: Text(
                                                                                        cat,
                                                                                        style: TextStyle(
                                                                                          color: themeProvider.textStrongColor,
                                                                                          fontWeight: FontWeight.w500,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                  ],
                                                                                ),
                                                                              ),
                                                                            ),
                                                                          ),
                                                                          if (cat !=
                                                                              'Genérico')
                                                                            IconButton(
                                                                              icon: const Icon(
                                                                                Icons.delete,
                                                                                color: Colors.red,
                                                                              ),
                                                                              onPressed: () async {
                                                                                // Mostrar diálogo de confirmación
                                                                                final confirmDelete =
                                                                                    await showDialog<
                                                                                      bool
                                                                                    >(
                                                                                      context: context,
                                                                                      barrierDismissible: true,
                                                                                      builder:
                                                                                          (
                                                                                            ctx,
                                                                                          ) => AlertDialog(
                                                                                            backgroundColor: themeProvider.surface,
                                                                                            elevation: 10,
                                                                                            shadowColor: themeProvider.cardShadowColor,
                                                                                            shape: RoundedRectangleBorder(
                                                                                              borderRadius: BorderRadius.circular(
                                                                                                16,
                                                                                              ),
                                                                                              side: BorderSide(
                                                                                                color: themeProvider.borderColor,
                                                                                                width: 1.5,
                                                                                              ),
                                                                                            ),
                                                                                            titlePadding: const EdgeInsets.fromLTRB(
                                                                                              24,
                                                                                              20,
                                                                                              24,
                                                                                              10,
                                                                                            ),
                                                                                            contentPadding: const EdgeInsets.symmetric(
                                                                                              horizontal: 24,
                                                                                              vertical: 10,
                                                                                            ),
                                                                                            title: const Center(
                                                                                              child: Text(
                                                                                                'Eliminar Categoría',
                                                                                                style: TextStyle(
                                                                                                  fontSize: 22,
                                                                                                  fontWeight: FontWeight.w500,
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                            content: Text(
                                                                                              '"$cat"',
                                                                                              textAlign: TextAlign.center,
                                                                                              style: TextStyle(
                                                                                                fontSize: 16,
                                                                                                color: themeProvider.textStrongColor,
                                                                                                fontWeight: FontWeight(
                                                                                                  600,
                                                                                                ),
                                                                                              ),
                                                                                            ),
                                                                                            actionsAlignment: MainAxisAlignment.spaceEvenly,
                                                                                            actionsPadding: const EdgeInsets.only(
                                                                                              bottom: 12,
                                                                                              top: 8,
                                                                                            ),
                                                                                            actions: [
                                                                                              TextButton(
                                                                                                onPressed: () => Navigator.pop(
                                                                                                  ctx,
                                                                                                  false,
                                                                                                ),
                                                                                                child: const Text(
                                                                                                  'Cancelar',
                                                                                                  style: TextStyle(
                                                                                                    fontSize: 16,
                                                                                                  ),
                                                                                                ),
                                                                                              ),
                                                                                              TextButton(
                                                                                                onPressed: () => Navigator.pop(
                                                                                                  ctx,
                                                                                                  true,
                                                                                                ),
                                                                                                child: const Text(
                                                                                                  'Eliminar',
                                                                                                  style: TextStyle(
                                                                                                    fontSize: 16,
                                                                                                    color: Colors.red,
                                                                                                    fontWeight: FontWeight.bold,
                                                                                                  ),
                                                                                                ),
                                                                                              ),
                                                                                            ],
                                                                                          ),
                                                                                    );

                                                                                // Si el usuario confirma la eliminación
                                                                                if (confirmDelete ==
                                                                                    true) {
                                                                                  shoppingProvider.removeCategoryFromList(
                                                                                    widget.listName,
                                                                                    cat,
                                                                                  );
                                                                                  if (selectedCategory ==
                                                                                      cat) {
                                                                                    selectedCategory = 'Genérico';
                                                                                  }
                                                                                  setDialogState(
                                                                                    () {},
                                                                                  );
                                                                                  setModalState(
                                                                                    () {},
                                                                                  );
                                                                                }
                                                                              },
                                                                            ),
                                                                        ],
                                                                      ),
                                                                    );
                                                                  }).toList(),
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          AnimatedOpacity(
                                                            duration:
                                                                const Duration(
                                                                  milliseconds:
                                                                      200,
                                                                ),
                                                            opacity:
                                                                canScrollDown
                                                                ? 1.0
                                                                : 0.0,
                                                            child: SizedBox(
                                                              height: 22,
                                                              child: Center(
                                                                child: Icon(
                                                                  Icons
                                                                      .keyboard_arrow_down,
                                                                  size: 40,
                                                                  color: themeProvider
                                                                      .primaryColor,
                                                                ),
                                                              ),
                                                            ),
                                                          ),
                                                          const Divider(),
                                                          ListTile(
                                                            leading: const Icon(
                                                              Icons.add,
                                                              color:
                                                                  Colors.blue,
                                                            ),
                                                            title: const Text(
                                                              'Crear categoría',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors.blue,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                            onTap: () async {
                                                              final newCatController =
                                                                  TextEditingController();
                                                              final newCat = await showDialog<String>(
                                                                context:
                                                                    context,
                                                                barrierDismissible:
                                                                    true,
                                                                builder: (ctx) => AlertDialog(
                                                                  backgroundColor:
                                                                      themeProvider
                                                                          .surface,
                                                                  elevation: 10,
                                                                  shadowColor:
                                                                      themeProvider
                                                                          .cardShadowColor,
                                                                  shape: RoundedRectangleBorder(
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          16,
                                                                        ),
                                                                    side: BorderSide(
                                                                      color: themeProvider
                                                                          .borderColor,
                                                                      width:
                                                                          1.5,
                                                                    ),
                                                                  ),
                                                                  titlePadding:
                                                                      const EdgeInsets.fromLTRB(
                                                                        24,
                                                                        20,
                                                                        24,
                                                                        20,
                                                                      ),
                                                                  contentPadding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            14,
                                                                        vertical:
                                                                            0,
                                                                      ),
                                                                  title: const Center(
                                                                    child: Text(
                                                                      'Nueva Categoría',
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            24,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  content: Padding(
                                                                    padding:
                                                                        const EdgeInsets.only(
                                                                          bottom:
                                                                              10,
                                                                        ),
                                                                    child: TextField(
                                                                      controller:
                                                                          newCatController,
                                                                      autofocus:
                                                                          true,
                                                                      maxLines:
                                                                          1,
                                                                      maxLength:
                                                                          15,
                                                                      decoration: InputDecoration(
                                                                        counterText:
                                                                            '',
                                                                        contentPadding: const EdgeInsets.symmetric(
                                                                          horizontal:
                                                                              12,
                                                                        ),
                                                                        filled:
                                                                            true,
                                                                        fillColor:
                                                                            themeProvider.surface,
                                                                        labelStyle: TextStyle(
                                                                          color:
                                                                              themeProvider.textMutedColor,
                                                                        ),
                                                                        border: OutlineInputBorder(
                                                                          borderRadius: BorderRadius.circular(
                                                                            14,
                                                                          ),
                                                                          borderSide: BorderSide(
                                                                            color:
                                                                                themeProvider.borderColor,
                                                                          ),
                                                                        ),
                                                                        enabledBorder: OutlineInputBorder(
                                                                          borderRadius: BorderRadius.circular(
                                                                            14,
                                                                          ),
                                                                          borderSide: BorderSide(
                                                                            color:
                                                                                themeProvider.borderColor,
                                                                            width:
                                                                                1.5,
                                                                          ),
                                                                        ),
                                                                        focusedBorder: OutlineInputBorder(
                                                                          borderRadius: BorderRadius.circular(
                                                                            14,
                                                                          ),
                                                                          borderSide: BorderSide(
                                                                            color:
                                                                                themeProvider.primaryColor,
                                                                            width:
                                                                                1.8,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                    ),
                                                                  ),
                                                                  actions: [
                                                                    Row(
                                                                      mainAxisAlignment:
                                                                          MainAxisAlignment
                                                                              .center,
                                                                      crossAxisAlignment:
                                                                          CrossAxisAlignment
                                                                              .center,
                                                                      children: [
                                                                        TextButton(
                                                                          onPressed: () => Navigator.pop(
                                                                            ctx,
                                                                          ),
                                                                          child: const Text(
                                                                            'Cancelar',
                                                                            style: TextStyle(
                                                                              fontSize: 16,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                        const SizedBox(
                                                                          width:
                                                                              10,
                                                                        ),
                                                                        TextButton(
                                                                          onPressed: () => Navigator.pop(
                                                                            ctx,
                                                                            newCatController.text.trim(),
                                                                          ),
                                                                          child: const Text(
                                                                            'Añadir',
                                                                            style: TextStyle(
                                                                              fontSize: 16,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                                  ],
                                                                ),
                                                              );

                                                              if (newCat !=
                                                                      null &&
                                                                  newCat
                                                                      .isNotEmpty) {
                                                                shoppingProvider
                                                                    .addCategoryToList(
                                                                      widget
                                                                          .listName,
                                                                      newCat,
                                                                    );
                                                                setDialogState(
                                                                  () {},
                                                                );
                                                                setModalState(
                                                                  () {},
                                                                );
                                                              }
                                                            },
                                                          ),
                                                          const Divider(),
                                                          ListTile(
                                                            enabled: canReorder,
                                                            leading: Icon(
                                                              Icons.swap_vert,
                                                              color: canReorder
                                                                  ? Colors
                                                                        .orange
                                                                  : Colors.grey,
                                                            ),
                                                            title: Text(
                                                              'Reordenar categorías',
                                                              style: TextStyle(
                                                                color:
                                                                    canReorder
                                                                    ? Colors
                                                                          .orange
                                                                    : Colors
                                                                          .grey,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                            ),
                                                            onTap: canReorder
                                                                ? () async {
                                                                    await _showReorderCategoriesDialog(
                                                                      dialogContext,
                                                                      shoppingProvider,
                                                                      themeProvider,
                                                                      widget
                                                                          .listName,
                                                                    );
                                                                    setDialogState(
                                                                      () {},
                                                                    );
                                                                    setModalState(
                                                                      () {},
                                                                    );
                                                                  }
                                                                : null,
                                                          ),
                                                        ],
                                                      );
                                                    },
                                                  );
                                                },
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );

                                if (selectedResult != null) {
                                  setModalState(() {
                                    selectedCategory = selectedResult;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Categoría',
                                  border: const OutlineInputBorder(),
                                  labelStyle: TextStyle(
                                    color: themeProvider.textMutedColor,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: themeProvider.borderColor,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    AutoSizeText(
                                      selectedCategory,
                                      maxFontSize: 15,
                                      minFontSize: 8,
                                      maxLines: 1,
                                    ),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 1,
                            child: InkWell(
                              onTap: () async {
                                FocusManager.instance.primaryFocus?.unfocus();

                                final chosenIcon = await showDialog<String?>(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      backgroundColor: themeProvider.surface,
                                      elevation: 10,
                                      shadowColor:
                                          themeProvider.cardShadowColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                        side: BorderSide(
                                          color: themeProvider.borderColor,
                                          width: 1.5,
                                        ),
                                      ),
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 14,
                                          ),
                                      title: const Center(
                                        child: Text(
                                          'Seleccionar Icono',
                                          style: TextStyle(
                                            fontSize: 24,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              ListTile(
                                                leading: const Icon(
                                                  Icons.block,
                                                  color: Colors.grey,
                                                ),
                                                title: const Text('Sin icono'),
                                                trailing: selectedIcon == null
                                                    ? const Icon(
                                                        Icons.check,
                                                        color: Colors.blue,
                                                      )
                                                    : null,
                                                onTap: () => Navigator.pop(
                                                  dialogContext,
                                                  'CLEAR',
                                                ),
                                              ),
                                              const Divider(),
                                              ...themeProvider
                                                  .availableIconsSvg
                                                  .entries
                                                  .map((entry) {
                                                    return ListTile(
                                                      leading: SvgPicture.asset(
                                                        entry.value,
                                                      ),
                                                      title: Text(entry.key),
                                                      trailing:
                                                          selectedIcon ==
                                                              entry.key
                                                          ? const Icon(
                                                              Icons.check,
                                                              color:
                                                                  Colors.blue,
                                                            )
                                                          : null,
                                                      onTap: () =>
                                                          Navigator.pop(
                                                            dialogContext,
                                                            entry.key,
                                                          ),
                                                    );
                                                  }),
                                            ],
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                );

                                if (chosenIcon != null) {
                                  setModalState(() {
                                    selectedIcon = chosenIcon == 'CLEAR'
                                        ? null
                                        : chosenIcon;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: InputDecoration(
                                  labelText: 'Icono',
                                  border: const OutlineInputBorder(),
                                  labelStyle: TextStyle(
                                    color: themeProvider.textMutedColor,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    borderSide: BorderSide(
                                      color: themeProvider.borderColor,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        if (selectedIcon != null &&
                                            themeProvider.availableIconsSvg
                                                .containsKey(selectedIcon))
                                          SvgPicture.asset(
                                            themeProvider
                                                .availableIconsSvg[selectedIcon]!,
                                            width: 25,
                                            height: 25,
                                            fit: BoxFit.fitHeight,
                                          )
                                        else
                                          const Center(
                                            child: AutoSizeText(
                                              'No',
                                              maxFontSize: 16,
                                              minFontSize: 10,
                                              maxLines: 1,
                                              style: TextStyle(
                                                color: Colors.grey,
                                              ),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: frequencyController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Frecuencia',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 12,
                                ),
                                border: const OutlineInputBorder(),
                                labelStyle: TextStyle(
                                  fontSize: 14,
                                  color: themeProvider.textMutedColor,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: themeProvider.borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: themeProvider.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: amountController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: 'Cantidad',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 12,
                                ),
                                border: const OutlineInputBorder(),
                                labelStyle: TextStyle(
                                  fontSize: 14,
                                  color: themeProvider.textMutedColor,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: themeProvider.borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: themeProvider.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              textAlign: TextAlign.center,
                              controller: priceController,
                              maxLength: 7,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Precio',
                                counterText: '',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 12,
                                ),
                                border: const OutlineInputBorder(),
                                labelStyle: TextStyle(
                                  fontSize: 14,
                                  color: themeProvider.textMutedColor,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: themeProvider.borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: themeProvider.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              textAlign: TextAlign.center,
                              controller: pricePerKiloController,
                              maxLength: 7,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              decoration: InputDecoration(
                                labelText: 'Precio/Kg',
                                counterText: '',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                isDense: true,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 12,
                                ),
                                border: const OutlineInputBorder(),
                                labelStyle: TextStyle(
                                  fontSize: 14,
                                  color: themeProvider.textMutedColor,
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: themeProvider.borderColor,
                                    width: 1.5,
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderSide: BorderSide(
                                    color: themeProvider.primaryColor,
                                    width: 2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageUrlController,
                        keyboardType: TextInputType.url,
                        decoration: InputDecoration(
                          labelText: 'URL de imagen',
                          border: const OutlineInputBorder(),
                          labelStyle: TextStyle(
                            fontSize: 14,
                            color: themeProvider.textMutedColor,
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: themeProvider.borderColor,
                              width: 1.5,
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderSide: BorderSide(
                              color: themeProvider.primaryColor,
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(elevation: 10),
                              onPressed: () async {
                                final name = nameController.text.trim();
                                final frequency = int.tryParse(
                                  frequencyController.text.trim(),
                                );
                                final amount = int.tryParse(
                                  amountController.text.trim(),
                                );

                                if (name.isEmpty ||
                                    frequency == null ||
                                    amount == null) {
                                  return;
                                }

                                shoppingProvider.updateProduct(
                                  widget.listName,
                                  product.id,
                                  name: name,
                                  frequency: frequency,
                                  amount: amount,
                                  category: selectedCategory,
                                  icon: selectedIcon,
                                );

                                await shoppingProvider.saveToStorage(
                                  mergeCloud: false,
                                );

                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
                              },
                              child: const Text('Guardar'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                elevation: 10,
                                backgroundColor: Colors.red,
                              ),
                              onPressed: () async {
                                // Mostrar diálogo de confirmación de eliminación de producto
                                final confirmDelete = await showDialog<bool>(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (ctx) => AlertDialog(
                                    backgroundColor: themeProvider.surface,
                                    elevation: 10,
                                    shadowColor: themeProvider.cardShadowColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      side: BorderSide(
                                        color: themeProvider.borderColor,
                                        width: 1.5,
                                      ),
                                    ),
                                    titlePadding: const EdgeInsets.fromLTRB(
                                      24,
                                      20,
                                      24,
                                      10,
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 24,
                                      vertical: 10,
                                    ),
                                    title: const Center(
                                      child: Text(
                                        'Eliminar Producto',
                                        style: TextStyle(
                                          fontSize: 22,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    content: Text(
                                      '"${product.name}"',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        fontSize: 16,
                                        color: themeProvider.textStrongColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    actionsAlignment:
                                        MainAxisAlignment.spaceEvenly,
                                    actionsPadding: const EdgeInsets.only(
                                      bottom: 12,
                                      top: 8,
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text(
                                          'Cancelar',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text(
                                          'Eliminar',
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.red,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                );

                                // Si el usuario confirma la eliminación
                                if (confirmDelete == true) {
                                  shoppingProvider.deleteProduct(
                                    widget.listName,
                                    product.id,
                                  );

                                  await shoppingProvider.saveToStorage(
                                    mergeCloud: false,
                                  );

                                  if (context.mounted) {
                                    Navigator.of(
                                      context,
                                    ).pop(); // Cierra la hoja inferior (bottom sheet)
                                  }
                                }
                              },
                              child: const Text(
                                'Borrar',
                                style: TextStyle(color: Colors.white),
                              ),
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
        },
      );
    } finally {
      nameController.dispose();
      frequencyController.dispose();
      priceController.dispose();
      pricePerKiloController.dispose();
      amountController.dispose();
      imageUrlController.dispose();
    }
  }

  Future<void> _showReorderCategoriesDialog(
    BuildContext context,
    ShoppingProvider shoppingProvider,
    ThemeProvider themeProvider,
    String listName,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final allCategories = shoppingProvider.categoriesForList(listName);
            final categories = shoppingProvider
                .categoriesForList(listName)
                .where((cat) => cat != 'Genérico')
                .toList();

            return AlertDialog(
              backgroundColor: themeProvider.surface,
              elevation: 10,
              shadowColor: themeProvider.cardShadowColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: themeProvider.borderColor, width: 1.5),
              ),
              titlePadding: const EdgeInsets.fromLTRB(14, 20, 14, 20),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 0,
              ),
              title: const Center(
                child: Text(
                  'Reordenar Categorías',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 300,
                child: categories.isEmpty
                    ? const Center(
                        child: Text('No hay categorías personalizadas.'),
                      )
                    : ReorderableListView.builder(
                        itemCount: categories.length,
                        onReorderItem: (oldIndex, newIndex) {
                          shoppingProvider.reorderCategoriesForList(
                            listName,
                            oldIndex,
                            newIndex,
                          );
                          setDialogState(() {});
                        },
                        itemBuilder: (context, index) {
                          final cat = categories[index];
                          final catColor = themeProvider.getCategoryColor(
                            cat,
                            allCategories,
                          );
                          return ListTile(
                            key: ValueKey(cat),
                            leading: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '${index + 1}.',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  width: 16,
                                  height: 16,
                                  decoration: BoxDecoration(
                                    color: catColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: Colors.black.withValues(
                                        alpha: 0.3,
                                      ),
                                      width: 1,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            title: Text(cat),
                            trailing: const Icon(Icons.drag_handle),
                          );
                        },
                      ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('Cerrar'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  void _onNavigationTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
