import 'package:auto_size_text/auto_size_text.dart';
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
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_manager_page.dart';
import 'package:shopping_hero/shared/widgets/main_bottom_nav.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
    // Sincronización instantánea al entrar, sin esperar el debounce de 5s.
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
        leading: BackButton(
          onPressed: () {
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
          // IMAGEN DE FONDO FIJA: Usa el tamaño total del dispositivo e ignora los cambios del viewport
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

          // CONTENIDO PRINCIPAL
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
                const SharingPage(),
              ],
            ),
          ),
        ],
      ),
      // 3. PADDING DIRECTO: Se sincroniza milisegundo a milisegundo con el teclado
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
                        borderRadius: BorderRadiusDirectional.vertical(
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
                                contentPadding: EdgeInsets.symmetric(
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
                                padding: EdgeInsets.only(bottom: 4.5),
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
          SliverToBoxAdapter(child: SizedBox(height: 8)),
          SliverGrid.builder(
            // ------------------------ ][ PRODUCTOS ACTIVOS ][ ------------------------ //
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 2,
              mainAxisSpacing: 2,
              childAspectRatio: 1,
            ),
            itemCount: activeProducts.length,
            itemBuilder: (context, index) {
              final product = activeProducts[index];
              return ProductBubble(
                key: ValueKey('${product.id}-active'),
                label: product.name,
                amount: product.amount,
                icon: product.icon,
                productAdd: ProductAdd.active,
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
                    // border: Border(),
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

    shoppingProvider.addActiveProductToList(
      widget.listName,
      name,
    ); // Lista Actualizada: Active + Frequent
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

    String selectedCategory = product.category;
    String? selectedIcon = product.icon;

    // Mapa de iconos disponibles
    final Map<String, IconData> availableIcons = {
      'shopping_bag': Icons.shopping_bag,
      'fastfood': Icons.fastfood,
      'local_grocery_store': Icons.local_grocery_store,
      'local_drink': Icons.local_drink,
      'kitchen': Icons.kitchen,
      'cleaning_services': Icons.cleaning_services,
    };

    try {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        builder: (modalContext) {
          return StatefulBuilder(
            builder: (BuildContext context, StateSetter setModalState) {
              // Obtener la lista de categorías actual de la lista seleccionada
              final availableCategories = shoppingProvider.availableCategories;

              // Si la categoría del producto ya no existe en la lista, fallback a 'Genérico'
              if (!availableCategories.contains(selectedCategory)) {
                selectedCategory = 'Genérico';
              }

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
                        maxLength: 30,
                        decoration: const InputDecoration(
                          labelText: 'Nombre',
                          counterText: '',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),

                      // --------------------------------------------------------
                      // CAMPO SELECTOR DE CATEGORÍA (REEMPLAZO SEGURO DEL DROPDOWN)
                      // --------------------------------------------------------
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                // 1. Desenfocar cualquier TextField activo globalmente antes de abrir el diálogo
                                FocusManager.instance.primaryFocus?.unfocus();

                                // 2. Abrir diálogo asegurando un descarte (dismiss) seguro
                                final selectedResult = await showDialog<String>(
                                  context: context,
                                  barrierDismissible:
                                      true, // Permite tocar fuera sin bloquear la app
                                  builder: (dialogContext) {
                                    return StatefulBuilder(
                                      builder: (context, setDialogState) {
                                        final currentCategories =
                                            shoppingProvider
                                                .availableCategories;

                                        return AlertDialog(
                                          title: const Text(
                                            'Seleccionar Categoría',
                                          ),
                                          content: SizedBox(
                                            width: double.maxFinite,
                                            child: SingleChildScrollView(
                                              child: Column(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  // --------------------------------------------------------
                                                  // API MODERNA DE FLUTTER: RadioGroup engloba los RadioListTile
                                                  // --------------------------------------------------------
                                                  RadioGroup<String>(
                                                    groupValue:
                                                        selectedCategory,
                                                    onChanged: (String? val) {
                                                      if (val != null) {
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
                                                        return RadioListTile<
                                                          String
                                                        >(
                                                          title: Text(cat),
                                                          value:
                                                              cat, // Solo necesita su propio valor
                                                          secondary:
                                                              cat != 'Genérico'
                                                              ? IconButton(
                                                                  icon: const Icon(
                                                                    Icons
                                                                        .delete,
                                                                    color: Colors
                                                                        .red,
                                                                  ),
                                                                  onPressed: () {
                                                                    shoppingProvider
                                                                        .removeCategoryFromSelectedList(
                                                                          cat,
                                                                        );
                                                                    if (selectedCategory ==
                                                                        cat) {
                                                                      selectedCategory =
                                                                          'Genérico';
                                                                    }
                                                                    setDialogState(
                                                                      () {},
                                                                    );
                                                                    setModalState(
                                                                      () {},
                                                                    );
                                                                  },
                                                                )
                                                              : null,
                                                          contentPadding:
                                                              const EdgeInsets.symmetric(
                                                                horizontal: 8,
                                                              ),
                                                        );
                                                      }).toList(),
                                                    ),
                                                  ),
                                                  const Divider(),
                                                  ListTile(
                                                    leading: const Icon(
                                                      Icons.add,
                                                      color: Colors.blue,
                                                    ),
                                                    title: const Text(
                                                      'Añadir nueva categoría',
                                                      style: TextStyle(
                                                        color: Colors.blue,
                                                      ),
                                                    ),
                                                    onTap: () async {
                                                      final newCatController =
                                                          TextEditingController();
                                                      final newCat = await showDialog<String>(
                                                        context: dialogContext,
                                                        barrierDismissible:
                                                            true,
                                                        builder: (ctx) => AlertDialog(
                                                          title: const Text(
                                                            'Nueva Categoría',
                                                          ),
                                                          content: TextField(
                                                            controller:
                                                                newCatController,
                                                            autofocus: true,
                                                          ),
                                                          actions: [
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                  ),
                                                              child: const Text(
                                                                'Cancelar',
                                                              ),
                                                            ),
                                                            TextButton(
                                                              onPressed: () =>
                                                                  Navigator.pop(
                                                                    ctx,
                                                                    newCatController
                                                                        .text
                                                                        .trim(),
                                                                  ),
                                                              child: const Text(
                                                                'Añadir',
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      );

                                                      if (newCat != null &&
                                                          newCat.isNotEmpty) {
                                                        shoppingProvider
                                                            .addCategoryToSelectedList(
                                                              newCat,
                                                            );
                                                        selectedCategory =
                                                            newCat;
                                                        setDialogState(() {});
                                                        setModalState(() {});
                                                      }
                                                    },
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                );

                                // 3. Si el usuario seleccionó una categoría (no tocó fuera), actualizamos la variable local
                                if (selectedResult != null) {
                                  setModalState(() {
                                    selectedCategory = selectedResult;
                                  });
                                }
                              },
                              child: InputDecorator(
                                decoration: const InputDecoration(
                                  labelText: 'Categoría',
                                  border: OutlineInputBorder(),
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(selectedCategory),
                                    const Icon(Icons.arrow_drop_down),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 2. Selector de Icono
                          Expanded(
                            child: InkWell(
                              onTap: () async {
                                FocusManager.instance.primaryFocus?.unfocus();

                                final chosenIcon = await showDialog<String?>(
                                  context: context,
                                  barrierDismissible: true,
                                  builder: (dialogContext) {
                                    return AlertDialog(
                                      title: const Text('Seleccionar Icono'),
                                      content: SizedBox(
                                        width: double.maxFinite,
                                        child: SingleChildScrollView(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Opción para no llevar ningún icono
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
                                              // Lista estática de iconos
                                              ...themeProvider
                                                  .availableIconsSvg
                                                  .entries
                                                  .map((entry) {
                                                    return ListTile(
                                                      leading: SvgPicture.asset(
                                                        entry.value,
                                                      ), //Icon(entry.value),
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
                                decoration: const InputDecoration(
                                  labelText: 'Icono',
                                  border: OutlineInputBorder(),
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
                                          // Icon(
                                          //   availableIcons[selectedIcon],
                                          //   size: 20,
                                          // )
                                          SvgPicture.asset(
                                            themeProvider
                                                .availableIconsSvg[selectedIcon]!,
                                            width: 25,
                                            height: 25,
                                            fit: BoxFit.fitHeight,
                                          )
                                        else
                                          const Text(
                                            'Ninguno',
                                            style: TextStyle(
                                              color: Colors.grey,
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

                      // CAMPO DE FRECUENCIA, CANTIDAD, PRECIO y PRECIOKILO
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: frequencyController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Frecuencia',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 12,
                                ),
                                labelStyle: TextStyle(fontSize: 14),
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
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 12,
                                ),
                                labelStyle: TextStyle(fontSize: 14),
                                border: OutlineInputBorder(),
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
                              decoration: const InputDecoration(
                                labelText: 'Precio',
                                alignLabelWithHint: false,
                                counterText: '',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 12,
                                ),
                                labelStyle: TextStyle(fontSize: 14),
                                border: OutlineInputBorder(),
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
                              decoration: const InputDecoration(
                                labelText: 'Precio/Kg',
                                alignLabelWithHint: false,
                                counterText: '',
                                floatingLabelBehavior:
                                    FloatingLabelBehavior.always,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  horizontal: 2,
                                  vertical: 12,
                                ),
                                labelStyle: TextStyle(fontSize: 14),
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

                      // BOTONES DE ACCIÓN
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(elevation: 10),
                              onPressed: () {
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
                                Navigator.of(context).pop();
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
                              onPressed: () {
                                shoppingProvider.deleteProduct(
                                  widget.listName,
                                  product.id,
                                );
                                Navigator.of(context).pop();
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

  void _onNavigationTap(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }
}
