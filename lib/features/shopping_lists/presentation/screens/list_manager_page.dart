import 'dart:async';

import 'package:auto_size_text/auto_size_text.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:shopping_hero/features/auth/presentation/screens/config_page.dart';
import 'package:shopping_hero/features/auth/presentation/screens/login_page.dart';
import 'package:shopping_hero/features/auth/presentation/screens/notifications_page.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/widgets/list_bubble.dart';

class ListManager extends StatefulWidget {
  const ListManager({super.key});

  @override
  State<ListManager> createState() => _ListManagerState();
}

class _ListManagerState extends State<ListManager> {
  int _pendingNotificationCount = 0;
  String? _observedInvitationUid;
  StreamSubscription<int>? _invitationCountSubscription;

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final sessionProvider = context.read<SessionProvider>();
    final uid = sessionProvider.isLoggedIn ? sessionProvider.uid : null;
    if (uid == _observedInvitationUid) return;

    _observedInvitationUid = uid;
    _invitationCountSubscription?.cancel();
    _invitationCountSubscription = null;

    if (uid == null) {
      if (_pendingNotificationCount != 0) {
        setState(() => _pendingNotificationCount = 0);
      }
      return;
    }

    _invitationCountSubscription = context
        .read<ShoppingProvider>()
        .watchPendingShareInvitationCount()
        .listen((count) {
          if (mounted && count != _pendingNotificationCount) {
            setState(() => _pendingNotificationCount = count);
          }
        }, onError: (_) {});
  }

  @override
  void dispose() {
    _invitationCountSubscription?.cancel();
    super.dispose();
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
            shape: const CircleBorder(),
            elevation: 8.0,
            shadowColor: themeProvider.cardShadowColor,
            child: IconButton(
              icon: Stack(
                children: [
                  const Icon(Icons.logout, color: Colors.black),
                  Icon(Icons.logout, color: themeProvider.dangerColor),
                ],
              ),
              tooltip: 'Cerrar Sesión',
              onPressed: () async {
                final session = context.read<SessionProvider>();
                final shopping = context.read<ShoppingProvider>();
                final navigator = Navigator.of(context);

                // 1. Limpiamos los listeners de Firestore y temporizadores activos
                await shopping.clearCurrentUser();

                // 2. Limpiamos la caché local de Hive si estaba en modo online
                if (session.isLoggedIn) {
                  await shopping.clearLocalShoppingCache();
                }

                // 3. Reseteamos la sesión en SessionProvider
                await session.logout();

                if (!mounted) return;

                // 4. Redirigimos a LoginPage
                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                  (route) => false,
                );
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
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: themeProvider.textStrongColor,
          ),
        ),
        centerTitle: true,
        actions: [
          if (sessionProvider.isLoggedIn)
            IconButton(
              tooltip: 'Notificaciones',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const NotificationsPage(),
                  ),
                );
              },
              icon: SizedBox(
                width: 32,
                height: 32,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    const Center(child: Icon(Icons.notifications_outlined)),
                    if (_pendingNotificationCount > 0)
                      Positioned(
                        right: -5,
                        bottom: -4,
                        child: Container(
                          constraints: const BoxConstraints(
                            minWidth: 18,
                            minHeight: 18,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          decoration: BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Theme.of(context).colorScheme.surface,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            _pendingNotificationCount > 99
                                ? '99+'
                                : '$_pendingNotificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              height: 1,
                            ),
                          ),
                        ),
                      ),
                  ],
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
                            isSharedList: shoppingProvider.isSharedList(
                              listName,
                            ),
                            onRename: (newName) {
                              shoppingProvider.renameList(listName, newName);
                            },
                            onLeaveShared: () async {
                              try {
                                await context
                                    .read<ShoppingProvider>()
                                    .leaveSharedList(listName);

                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Te has desvinculado de "$listName"',
                                      ),
                                      backgroundColor:
                                          themeProvider.primaryColor,
                                    ),
                                  );
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Error al desvincularse: ${e.toString().replaceAll('Exception: ', '')}',
                                      ),
                                      backgroundColor:
                                          themeProvider.dangerColor,
                                    ),
                                  );
                                }
                              }
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
                            foregroundColor: isDark
                                ? Colors.black
                                : Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            side: BorderSide(
                              color: themeProvider.borderColor.withValues(
                                alpha: 0.3,
                              ),
                              width: 2,
                            ),
                          ),
                          icon: const Icon(Icons.add, size: 19),
                          label: const Text(
                            'Crear lista',
                            style: TextStyle(fontSize: 16),
                          ),
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
