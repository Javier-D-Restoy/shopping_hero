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

enum _ListManagerAction { reorder, notifications, settings }

class ListManager extends StatefulWidget {
  const ListManager({super.key});

  @override
  State<ListManager> createState() => _ListManagerState();
}

class _ListManagerState extends State<ListManager> {
  int _pendingNotificationCount = 0;
  bool _isLoggingOut = false;
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
    final listNames = shoppingProvider.orderedListNames;
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
              onPressed: _isLoggingOut
                  ? null
                  : () async {
                      setState(() => _isLoggingOut = true);
                      final session = context.read<SessionProvider>();
                      final shopping = context.read<ShoppingProvider>();
                      final navigator = Navigator.of(context);
                      final messenger = ScaffoldMessenger.maybeOf(context);
                      final wasLoggedIn = session.isLoggedIn;

                      try {
                        if (wasLoggedIn) {
                          await shopping.saveToStorage();
                          if (shopping.syncStatus !=
                              ShoppingSyncStatus.synced) {
                            messenger?.showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'No se pudieron sincronizar tus listas. Sigues dentro de tu cuenta.',
                                ),
                              ),
                            );
                            return;
                          }
                        }

                        await session.logout();
                        if (session.isLoggedIn) {
                          messenger?.showSnackBar(
                            SnackBar(
                              content: Text(
                                session.errorMessage ??
                                    'No se pudo cerrar la sesión.',
                              ),
                            ),
                          );
                          return;
                        }

                        await shopping.clearCurrentUser();
                        if (wasLoggedIn) {
                          await shopping.clearLocalShoppingCache();
                        }

                        if (!mounted) return;
                        navigator.pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                          (route) => false,
                        );
                      } catch (error) {
                        if (mounted) {
                          messenger?.showSnackBar(
                            SnackBar(
                              content: Text(
                                error.toString().replaceFirst(
                                  'Exception: ',
                                  '',
                                ),
                              ),
                            ),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _isLoggingOut = false);
                      }
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
          PopupMenuButton<_ListManagerAction>(
            tooltip: 'Más opciones',
            enabled: !_isLoggingOut,
            icon: const Icon(Icons.more_vert),
            color: themeProvider.surfaceSoft,
            elevation: 6,
            shadowColor: themeProvider.cardShadowColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: themeProvider.borderColor, width: 1.5),
            ),
            onSelected: (action) {
              switch (action) {
                case _ListManagerAction.reorder:
                  _showReorderListsDialog(shoppingProvider, themeProvider);
                case _ListManagerAction.notifications:
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const NotificationsPage(),
                    ),
                  );
                case _ListManagerAction.settings:
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const ConfigPage()),
                  );
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem<_ListManagerAction>(
                value: _ListManagerAction.reorder,
                enabled: listNames.length > 1,
                child: Row(
                  children: [
                    Icon(
                      Icons.swap_vert,
                      size: 20,
                      color: Colors.orange,
                      weight: 30,
                      shadows: themeProvider.shadowsMid,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Reordenar',
                      style: TextStyle(
                        color: listNames.length > 1
                            ? themeProvider.textStrongColor
                            : Colors.grey,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              if (sessionProvider.isLoggedIn)
                PopupMenuItem<_ListManagerAction>(
                  value: _ListManagerAction.notifications,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_outlined,
                        size: 20,
                        color: themeProvider.primaryColor,
                        weight: 30,
                        shadows: themeProvider.shadowsMid,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Notificaciones',
                        style: TextStyle(
                          color: themeProvider.textStrongColor,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (_pendingNotificationCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          constraints: const BoxConstraints(
                            minWidth: 20,
                            minHeight: 20,
                          ),
                          alignment: Alignment.center,
                          padding: const EdgeInsets.symmetric(horizontal: 5),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            _pendingNotificationCount > 99
                                ? '99+'
                                : '$_pendingNotificationCount',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              PopupMenuItem<_ListManagerAction>(
                value: _ListManagerAction.settings,
                child: Row(
                  children: [
                    Icon(
                      Icons.settings_outlined,
                      size: 20,
                      color: Colors.blueGrey,
                      weight: 30,
                      shadows: themeProvider.shadowsMid,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Configuración',
                      style: TextStyle(
                        color: themeProvider.textStrongColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
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
                            hasAcceptedCollaborators: shoppingProvider
                                .hasAcceptedCollaborators(listName),
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
          if (_isLoggingOut) ...[
            const Positioned.fill(
              child: ModalBarrier(dismissible: false, color: Colors.black26),
            ),
            const Center(child: CircularProgressIndicator()),
          ],
        ],
      ),
    );
  }

  Future<void> _showReorderListsDialog(
    ShoppingProvider shoppingProvider,
    ThemeProvider themeProvider,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            final listNames = shoppingProvider.orderedListNames;

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
                  'Reordenar listas',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w500),
                ),
              ),
              content: SizedBox(
                width: double.maxFinite,
                height: 320,
                child: listNames.length < 2
                    ? const Center(child: Text('No hay listas para reordenar.'))
                    : ReorderableListView.builder(
                        itemCount: listNames.length,
                        onReorderItem: (oldIndex, newIndex) {
                          shoppingProvider.reorderLists(oldIndex, newIndex);
                          setDialogState(() {});
                        },
                        itemBuilder: (context, index) {
                          final listName = listNames[index];
                          return ListTile(
                            key: ValueKey(listName),
                            leading: Text(
                              '${index + 1}.',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            title: Text(listName),
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
}
