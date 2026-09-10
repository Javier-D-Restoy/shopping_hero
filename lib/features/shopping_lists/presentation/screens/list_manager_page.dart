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

    final primary = isDark ? const Color(0xFF9DD388) : const Color(0xFF5E9C4C);
    final border = isDark ? const Color(0xFF4A6448) : const Color(0xFFBFE0B0);
    final textStrong = isDark ? Colors.white : const Color(0xFF234B2A);
    final textMuted = isDark ? const Color(0xFFD9E9D2) : const Color(0xFF55755E);
    final cardShadow = isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.08);
    final gradientColors = isDark
        ? [const Color(0xFF1D2D1F).withValues(alpha: 0.50), const Color(0xFF243928).withValues(alpha: 0.50)]
        : [const Color(0xFFF6F8E8).withValues(alpha: 0.50), const Color(0xFFE7F4E1).withValues(alpha: 0.50)];

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
                  MaterialPageRoute(
                    builder: (context) => const LoginPage(),
                  ),
                );
              }
            }
          },
        ),
        title: Text(
          'Listas de $displayName',
          style: TextStyle(fontSize: 18, color: textStrong),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            onPressed: (){
              if (context.mounted) {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ConfigPage()),
                );
              }
            },
            icon: Icon(Icons.settings)),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(child: Image.asset(
            themeProvider.isDarkMode ? 'assets/images/background/Background_Dark_Image_1.jpg'
            : 'assets/images/background/Background_Image_1.jpg',
            fit: BoxFit.cover,)),
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
                        margin: const EdgeInsets.symmetric(vertical: 24, horizontal: 4),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: gradientColors,
                          ),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(color: border, width: 1.6),
                          boxShadow: [
                            BoxShadow(
                              color: cardShadow,
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
                                color: primary,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.list_alt_rounded, color: Colors.white, size: 22),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'No tienes ninguna lista de la compra.\nPulsa el botón de abajo para crear tu primera lista.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 15,
                                color: textMuted,
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
                          productCount: shoppingProvider.activeProductsForList(listName).length,
                          canManageList: shoppingProvider.canManageList(listName),
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
                          backgroundColor: primary,
                          foregroundColor: Colors.white,
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
      )
    );
  }
}