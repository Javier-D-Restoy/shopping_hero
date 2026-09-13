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
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final shoppingProvider = context.watch<ShoppingProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final displayName = sessionProvider.displayName;
    final isDark = themeProvider.isDarkMode;
    final listNames = shoppingProvider.shoppingLists.keys.toList();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        leading: BackButton(
          onPressed: () async {
            if (context.mounted) {
              await context.read<SessionProvider>().logout();
              if (context.mounted) {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                );
              }
            }
          },
        ),
        title: Text(
          'Listas de $displayName',
          style: TextStyle(fontSize: 18, color: themeProvider.textStrongColor),
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
          Positioned.fill(
            child: Image.asset(
              themeProvider.backgroundImagePath,
              fit: BoxFit.cover,
            ),
          ),
          SafeArea(
            child: ListView(
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
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Crear lista'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
