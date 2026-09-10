import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_manager_page.dart';

class _SharedMember {
  const _SharedMember({
    required this.uid,
    required this.email,
    required this.displayName,
  });

  final String uid;
  final String email;
  final String displayName;
}

class SharingPage extends StatefulWidget {
  const SharingPage({super.key});

  @override
  State<SharingPage> createState() => _SharingPageState();
}

class _SharingPageState extends State<SharingPage> {
  final _emailController = TextEditingController();
  final _firestore = FirebaseFirestore.instance;
  bool _isSharing = false;
  bool _isLoadingMembers = false;
  List<_SharedMember> _sharedMembers = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSharedMembers());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadSharedMembers();
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _loadSharedMembers() async {
    if (!mounted) return;

    final shoppingProvider = context.read<ShoppingProvider>();
    final listName = shoppingProvider.selectedListName;
    final sharedListId = shoppingProvider.sharedListIdFor(listName);
    final currentUid = context.read<SessionProvider>().uid;

    if (sharedListId == null) {
      if (mounted) {
        setState(() => _sharedMembers = const []);
      }
      return;
    }

    try {
      if (mounted) {
        setState(() => _isLoadingMembers = true);
      }

      final doc = await _firestore.collection('sharedShoppingLists').doc(sharedListId).get();
      final memberUids = (doc.data()?['memberUids'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .where((uid) => uid.isNotEmpty && uid != currentUid)
          .toSet()
          .toList();

      if (memberUids.isEmpty) {
        if (mounted) {
          setState(() => _sharedMembers = const []);
        }
        return;
      }

      final loadedMembers = <_SharedMember>[];
      for (var i = 0; i < memberUids.length; i += 10) {
        final chunk = memberUids.sublist(
          i,
          i + 10 < memberUids.length ? i + 10 : memberUids.length,
        );

        final snapshot = await _firestore
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final userDoc in snapshot.docs) {
          final data = userDoc.data();
          loadedMembers.add(
            _SharedMember(
              uid: userDoc.id,
              email: (data['email'] ?? '').toString(),
              displayName: (data['displayName'] ?? 'Usuario').toString(),
            ),
          );
        }
      }

      if (mounted) {
        setState(() => _sharedMembers = loadedMembers);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sharedMembers = const []);
      }
    } finally {
      if (mounted) {
        setState(() => _isLoadingMembers = false);
      }
    }
  }

  Future<void> _shareList() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    final shoppingProvider = context.read<ShoppingProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);

    setState(() => _isSharing = true);
    try {
      await shoppingProvider.shareSelectedListWithEmail(email);
      if (!mounted) return;
      _emailController.clear();
      await _loadSharedMembers();
      messenger?.showSnackBar(
        const SnackBar(content: Text('Lista compartida correctamente')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  Future<void> _leaveSharedList() async {
    final shoppingProvider = context.read<ShoppingProvider>();
    final messenger = ScaffoldMessenger.maybeOf(context);
    final listName = shoppingProvider.selectedListName;

    try {
      await shoppingProvider.leaveSharedList(listName);
      if (!mounted) return;
      messenger?.showSnackBar(
        const SnackBar(content: Text('Te has desvinculado de la lista')),
      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const ListManager()),
      );
    } catch (error) {
      if (!mounted) return;
      messenger?.showSnackBar(
        SnackBar(content: Text(error.toString().replaceFirst('Exception: ', ''))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final shoppingProvider = context.watch<ShoppingProvider>();
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = themeProvider.isDarkMode;
    final listName = shoppingProvider.selectedListName;
    final isOwner = shoppingProvider.canManageList(listName);

    final surface = isDark ? const Color(0xFF1F2A1E) : Colors.white;
    final surfaceSoft = isDark ? const Color(0xFF2C3A2D) : const Color(0xFFF4F8EE);
    final primary = isDark ? const Color(0xFF9DD388) : const Color(0xFF5E9C4C);
    final primarySoft = isDark ? const Color(0xFF7DBB74) : const Color(0xFFBFE0B0);
    final border = isDark ? const Color(0xFF4A6448) : const Color(0xFFBFE0B0);
    final textStrong = isDark ? Colors.white : const Color(0xFF234B2A);
    final textMuted = isDark ? const Color(0xFFD9E9D2) : const Color(0xFF55755E);
    final cardShadow = isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.08);

    final shareCard = Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [const Color(0xFF1D2D1F).withValues(alpha: 0.50), const Color(0xFF243928).withValues(alpha: 0.50)]
              : [const Color(0xFFF6F8E8).withValues(alpha: 0.50), const Color(0xFFE7F4E1).withValues(alpha: 0.50)],
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
                child: const Icon(Icons.share_rounded, color: Colors.white, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Compartir "$listName"',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: textStrong,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (isOwner) ...[
            TextField(
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
              style: TextStyle(color: textStrong),
              decoration: InputDecoration(
                labelText: 'Email del usuario',
                hintText: 'usuario@ejemplo.com',
                filled: true,
                fillColor: surface,
                labelStyle: TextStyle(color: textMuted),
                hintStyle: TextStyle(color: textMuted.withValues(alpha: 0.8)),
                prefixIcon: Icon(Icons.mail_outline, color: primary),
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
                onPressed: _isSharing ? null : _shareList,
                style: FilledButton.styleFrom(
                  backgroundColor: primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: _isSharing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Icon(Icons.person_add_alt_1_rounded),
                label: Text(_isSharing ? 'Compartiendo...' : 'Compartir lista'),
              ),
            ),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _leaveSharedList,
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFB35C5C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.person_remove_alt_1_rounded),
                label: const Text('Desvincularme de la lista'),
              ),
            ),
          ],
        ],
      ),
    );

    final membersCard = Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: surface.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: border, width: 1.2),
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
              Icon(Icons.people_alt_rounded, color: primary),
              const SizedBox(width: 8),
              Text(
                'Usuarios con acceso',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: textStrong,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (_isLoadingMembers)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else if (_sharedMembers.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: surfaceSoft,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Text(
                'No hay otros usuarios con acceso a esta lista.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: textStrong,
                ),
              ),
            )
          else
            ..._sharedMembers.map(
              (member) => Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: surfaceSoft.withValues(alpha: 0.90),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: border),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: primarySoft,
                      child: Text(
                        member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : 'U',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            member.displayName,
                            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: textStrong,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            member.email,
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        shareCard,
        membersCard,
      ],
    );
  }
}