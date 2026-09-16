import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:shopping_hero/features/auth/presentation/screens/login_page.dart';

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  final _usernameController = TextEditingController();
  bool _isSaving = false;
  bool _isDeletingAccount = false;
  bool _usernameInitialized = false;

  @override
  void dispose() {
    _usernameController.dispose();
    super.dispose();
  }

  Future<void> _saveUsername() async {
    final sessionProvider = context.read<SessionProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final newName = _usernameController.text.trim();

    if (newName == sessionProvider.displayName) return;

    setState(() => _isSaving = true);
    final success = await sessionProvider.updateDisplayName(newName);
    if (!mounted) return;
    setState(() => _isSaving = false);

    messenger?.showSnackBar(
      SnackBar(
        content: Text(
          success
              ? 'Nombre de usuario actualizado'
              : (sessionProvider.errorMessage ??
                    'No se pudo actualizar el nombre'),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final sessionProvider = context.watch<SessionProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;

    // Solo se prefija una vez para no pisar lo que el usuario está escribiendo.
    if (!_usernameInitialized) {
      _usernameController.text = sessionProvider.displayName;
      _usernameInitialized = true;
    }

    final surface = isDark ? const Color(0xFF1F2A1E) : Colors.white;
    final primary = isDark ? const Color(0xFF9DD388) : const Color(0xFF5E9C4C);
    final border = isDark ? const Color(0xFF4A6448) : const Color(0xFFBFE0B0);
    final textStrong = isDark ? Colors.white : const Color(0xFF234B2A);
    final textMuted = isDark
        ? const Color(0xFFD9E9D2)
        : const Color(0xFF55755E);
    final cardShadow = isDark
        ? Colors.black.withValues(alpha: 0.35)
        : Colors.black.withValues(alpha: 0.08);
    final dangerColor = const Color(0xFFB35C5C);

    final profileCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  const Color(0xFF1D2D1F).withValues(alpha: 0.80),
                  const Color(0xFF243928).withValues(alpha: 0.80),
                ]
              : [
                  const Color(0xFFF6F8E8).withValues(alpha: 0.80),
                  const Color(0xFFE7F4E1).withValues(alpha: 0.80),
                ],
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
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: primary,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.person_rounded,
                  color: isDark ? Colors.black : Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Mi perfil',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textStrong,
                  ),
                ),
              ),
            ],
          ),
          if (sessionProvider.email.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              sessionProvider.email,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: textMuted),
            ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _usernameController,
            style: TextStyle(color: textStrong),
            decoration: InputDecoration(
              labelText: 'Nombre de usuario',
              filled: true,
              fillColor: surface,
              labelStyle: TextStyle(color: textMuted),
              prefixIcon: Icon(Icons.badge_outlined, color: primary),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: primary, width: 1.6),
              ),
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isSaving ? null : _saveUsername,
              style: FilledButton.styleFrom(
                backgroundColor: primary,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.save_rounded),
              label: Text(_isSaving ? 'Guardando...' : 'Guardar cambios'),
            ),
          ),
        ],
      ),
    );

    // final dangerCard = Container(
    //   margin: const EdgeInsets.only(top: 18),
    //   padding: const EdgeInsets.all(18),
    //   decoration: BoxDecoration(
    //     color: surface.withValues(alpha: 0.80),
    //     borderRadius: BorderRadius.circular(22),
    //     border: Border.all(color: border, width: 1.2),
    //     boxShadow: [
    //       BoxShadow(
    //         color: cardShadow,
    //         blurRadius: 8,
    //         offset: const Offset(0, 4),
    //       ),
    //     ],
    //   ),
    //   child: Column(
    //     crossAxisAlignment: CrossAxisAlignment.start,
    //     children: [
    //       Row(
    //         children: [
    //           Icon(Icons.warning_amber_rounded, color: dangerColor),
    //           const SizedBox(width: 8),
    //           Text(
    //             'Datos locales',
    //             style: Theme.of(context).textTheme.titleMedium?.copyWith(
    //               fontWeight: FontWeight.w700,
    //               color: textStrong,
    //             ),
    //           ),
    //         ],
    //       ),
    //       const SizedBox(height: 14),
    //       Text(
    //         'Esta acción borra las listas de la compra guardadas en este dispositivo. Tu perfil (nombre, email) no se ve afectado.',
    //         style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textMuted),
    //       ),
    //       const SizedBox(height: 14),
    //       SizedBox(
    //         width: double.infinity,
    //         child: FilledButton.icon(
    //           onPressed: _showResetCacheDialog,
    //           style: FilledButton.styleFrom(
    //             backgroundColor: dangerColor,
    //             foregroundColor: isDark? Colors.black : Colors.white,
    //             padding: const EdgeInsets.symmetric(vertical: 14),
    //             shape: RoundedRectangleBorder(
    //               borderRadius: BorderRadius.circular(14),
    //             ),
    //           ),
    //           icon: const Icon(Icons.delete_sweep_rounded),
    //           label: const Text('Liberar caché local'),
    //         ),
    //       ),
    //     ],
    //   ),
    // );

    final deleteAccountCard = Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: dangerColor, width: 1.2),
        boxShadow: [
          BoxShadow(
            color: cardShadow,
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.dangerous_rounded, color: dangerColor),
              const SizedBox(width: 8),
              Text(
                'Eliminar cuenta',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'Esta acción es irreversible: se borrará tu cuenta, con su perfil y listas, se desvincularán las listas compartidas con otros usuarios y se borrarán datos locales del dispositivo.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: textMuted),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _isDeletingAccount ? null : _showDeleteAccountDialog,
              style: FilledButton.styleFrom(
                backgroundColor: dangerColor,
                foregroundColor: isDark ? Colors.black : Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isDeletingAccount
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.dangerous_rounded),
              label: Text(
                _isDeletingAccount
                    ? 'Eliminando...'
                    : 'Eliminar cuenta definitivamente',
              ),
            ),
          ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        profileCard,
        // dangerCard,
        if (!sessionProvider.isOffline) deleteAccountCard,
      ],
    );
  }

  // void _showResetCacheDialog() {
  //   final pageContext = context;
  //   showDialog<void>(
  //     context: context,
  //     builder: (dialogContext) {
  //       return AlertDialog(
  //         title: const Text('Liberar caché local'),
  //         content: const Text('Si haces esto, se borrarán todos los datos guardados en el dispositivo. ¿Estás seguro?'),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(dialogContext),
  //             child: const Text('Cancelar'),
  //           ),
  //           TextButton(
  //             onPressed: () {
  //               Navigator.pop(dialogContext);
  //               _handleResetLocalData(pageContext);
  //             },
  //             child: const Text('Liberar'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // Future<void> _handleResetLocalData(BuildContext context) async {
  //   final shoppingProvider = context.read<ShoppingProvider>();

  //   // Solo se borran las listas locales; el perfil del usuario (nombre, email, uid) se conserva.
  //   await shoppingProvider.clearLocalShoppingCache();

  //   if (context.mounted) {
  //     Navigator.pushReplacement(
  //       context,
  //       MaterialPageRoute(builder: (context) => const LoginPage()),
  //     );
  //   }
  // }

  Future<void> _showDeleteAccountDialog() async {
    // 1. Esperamos a que el usuario confirme o cancele en el diálogo
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        return const _DeleteAccountDialogContent();
      },
    );

    // 2. Verificamos 'mounted' después del 'await' antes de usar 'context'
    if (confirmed == true && mounted) {
      _handleDeleteAccount(context);
    }
  }

  Future<void> _handleDeleteAccount(BuildContext context) async {
    final sessionProvider = context.read<SessionProvider>();
    final shoppingProvider = context.read<ShoppingProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() => _isDeletingAccount = true);
    final success = await sessionProvider.deleteAccount();
    if (!mounted) return;
    setState(() => _isDeletingAccount = false);

    if (!success) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            sessionProvider.errorMessage ?? 'No se pudo eliminar la cuenta',
          ),
        ),
      );
      return;
    }

    // El perfil ya no existe: se borra también toda la caché local de listas.
    await shoppingProvider.clearLocalShoppingCache();

    if (context.mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const LoginPage()),
      );
    }
  }
}

class _DeleteAccountDialogContent extends StatefulWidget {
  const _DeleteAccountDialogContent();

  @override
  State<_DeleteAccountDialogContent> createState() =>
      _DeleteAccountDialogContentState();
}

class _DeleteAccountDialogContentState
    extends State<_DeleteAccountDialogContent> {
  int _secondsRemaining = 10;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  void _startCountdown() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_secondsRemaining > 1) {
        setState(() => _secondsRemaining--);
      } else {
        setState(() => _secondsRemaining = 0);
        _timer?.cancel();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel(); // Cancelamos el timer para evitar fugas de memoria
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isButtonEnabled = _secondsRemaining == 0;

    return AlertDialog(
      title: const Text('Eliminar cuenta'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Esta acción es irreversible. Se eliminará tu cuenta, tu perfil, tus listas y tu acceso a las listas compartidas.',
          ),
          const SizedBox(height: 16),
          if (!isButtonEnabled)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 10),
                Text(
                  'Espera para confirmar...',
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.secondary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: isButtonEnabled
              ? () => Navigator.pop(context, true)
              : null, // Si es null, Flutter inhabilita visualmente el botón
          style: FilledButton.styleFrom(
            backgroundColor: isButtonEnabled
                ? const Color(0xFFB35C5C)
                : Colors.grey,
          ),
          child: Text(
            isButtonEnabled ? 'Eliminar' : 'Eliminar ($_secondsRemaining)',
          ),
        ),
      ],
    );
  }
}
