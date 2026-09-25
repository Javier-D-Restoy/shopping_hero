import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:shopping_hero/features/auth/presentation/screens/config_page.dart';
import 'package:shopping_hero/features/auth/presentation/screens/login_page.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/widgets/list_bubble.dart';

class ListManager extends StatefulWidget {
  const ListManager({super.key});

  @override
  State<ListManager> createState() => _ListManagerState();
}

class _ListManagerState extends State<ListManager> {
  @override
  void initState() {
    super.initState();
    // Recordamos que esta fue la última pantalla visitada, para restaurarla al reabrir la app.
    context.read<SessionProvider>().setLastRoute(route: 'listManager');
    // Sincronización instantánea al entrar, sin esperar el debounce de 5s.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ShoppingProvider>().syncNow();
    });
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final shoppingProvider = context.watch<ShoppingProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final displayName = sessionProvider.displayName;
    final isDark = themeProvider.isDarkMode;
    final listNames = shoppingProvider.shoppingLists.keys.toList();
    final screenSize = MediaQuery.sizeOf(context);

    return Scaffold(
      resizeToAvoidBottomInset: false,
      appBar: AppBar(
        toolbarHeight: 40,
        elevation: 2,
        shadowColor: themeProvider.cardShadowColor,
        leading: Padding(
          padding: const EdgeInsets.all(2.0),
          child: Material(
            // color: Colors.yellow,
            shape: const CircleBorder(),
            elevation: 8.0,
            shadowColor: themeProvider.cardShadowColor,
            child: IconButton(
              icon: Stack(
                children: [
                  Icon(Icons.logout,color: Colors.black,),
                  Icon(Icons.logout,color: themeProvider.dangerColor,),
                ],
              ),
              // color: Colors.red,
              style: ButtonStyle(),
              tooltip: 'Cerrar Sesión',
              onPressed: () async {
                final session = context.read<SessionProvider>();
                final shopping = context.read<ShoppingProvider>();
                final navigator = Navigator.of(context);

                // Limpiamos la caché local de Hive, la sesión y ejecutamos el logout en segundo plano.
                // Si el usuario estaba con sesión online iniciada, limpiamos la caché online
                // para que un Usuario B no vea residuos.
                // Si estaba en modo offline (invitado), NO se borra nada.
                if (session.isLoggedIn) {
                  await shopping.clearLocalShoppingCache();
                }

                // Guardamos seguridad tras el await por si el widget se desmontó
                if (!mounted) return;

                // Reemplazamos la ruta al instante eliminando todo el historial previo.
                // Al no haber 'await' previo, no se requiere la comprobación de context.mounted.
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
            
                // Limpiamos los datos y ejecutamos el logout en segundo plano.
                // Como ListManager ya fue desmontado del árbol de widgets,
                // notifyListeners() no provocará ningún redibujado no deseado.
                shopping.clearCurrentUser();
                session.logout();
              },
            ),
          ),
        ),
        title: AutoSizeText(
          'Listas de $displayName',
          maxLines: 1,
          minFontSize: 10,
          stepGranularity: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight(500), color: themeProvider.textStrongColor),
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
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Stack(
        children: [
          // Positioned.fill(
          //   child: Image.asset(
          //     themeProvider.backgroundImagePath,
          //     fit: BoxFit.cover,
          //   ),
          // ),
          SizedBox(
            width: screenSize.width,
            height: screenSize.height,
            child: Image.asset(
              themeProvider.backgroundImagePath,
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: RefreshIndicator(
              color: themeProvider.primaryColor,
              onRefresh: shoppingProvider.refreshFromCloud,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(12),
                children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (listNames.isEmpty) ...[
                      Container(
                        width: double.infinity,
                        margin: const EdgeInsets.symmetric(
                          vertical: 24,
                          horizontal: 4,
                        ),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: themeProvider.gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: themeProvider.borderColor,
                            width: 1.6,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: themeProvider.cardShadowColor,
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: themeProvider.primaryColor,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(
                                Icons.list_alt_rounded,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No tienes ninguna lista de la compra.\nPulsa el botón de abajo para crear tu primera lista.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: themeProvider.textMutedColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ] else ...[
                      ...listNames.map((listName) {
                        return ListBubble(
                          isDark: isDark,
                          listName: listName,
                          productCount: shoppingProvider
                              .activeProductsForList(listName)
                              .length,
                          canManageList: shoppingProvider.canManageList(
                            listName,
                          ),
                          isSharedList: shoppingProvider.isSharedList(listName),
                          onRename: (newName) {
                            shoppingProvider.renameList(listName, newName);
                          },
                          onLeaveShared: () async {
                            await shoppingProvider.leaveSharedList(listName);
                          },
                        );
                      }),
                    ],
                    const SizedBox(height: 12),
                    SizedBox(
                      width: 320,
                      child: FilledButton.icon(
                        onPressed: () {
                          shoppingProvider.createList();
                        },
                        style: FilledButton.styleFrom(
                          backgroundColor: themeProvider.primaryColor,
                          foregroundColor: isDark ? Colors.black : Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          side: BorderSide(color: themeProvider.borderColor.withValues(alpha: 0.3), width: 2,)
                        ),
                        icon: const Icon(Icons.add, size: 19,),
                        label: const Text('Crear lista', style: TextStyle(fontSize: 16),),
                      ),
                    ),
                  ],
                ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
