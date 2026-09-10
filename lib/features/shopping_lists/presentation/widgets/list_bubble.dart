import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_main_page.dart';
import 'package:auto_size_text/auto_size_text.dart';

class _ListMemberAvatar {
  const _ListMemberAvatar({
    required this.uid,
    required this.displayName,
  });

  final String uid;
  final String displayName;
}

class ListBubble extends StatefulWidget {
  const ListBubble({
    super.key,
    required this.isDark,
    required this.listName,
    required this.productCount,
    required this.canManageList,
    required this.isSharedList,
    required this.onRename,
    required this.onLeaveShared,
  });

  final bool isDark;
  final String listName;
  final int productCount;
  final bool canManageList;
  final bool isSharedList;
  final ValueChanged<String> onRename;
  final Future<void> Function() onLeaveShared;

  @override
  State<ListBubble> createState() => _ListBubbleState();
}

class _ListBubbleState extends State<ListBubble> {
  bool _isHovered = false;
  final TextEditingController _renameController = TextEditingController();
  List<_ListMemberAvatar> _sharedMembers = const [];
  bool _isLoadingMembers = false;

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
    _renameController.dispose();
    super.dispose();
  }

  Future<void> _loadSharedMembers() async {
    if (!widget.isSharedList) {
      if (mounted) setState(() => _sharedMembers = const []);
      return;
    }

    final shoppingProvider = context.read<ShoppingProvider>();
    final currentUid = context.read<SessionProvider>().uid;
    final sharedListId = shoppingProvider.sharedListIdFor(widget.listName);

    if (sharedListId == null) {
      if (mounted) setState(() => _sharedMembers = const []);
      return;
    }

    try {
      if (mounted) setState(() => _isLoadingMembers = true);

      final doc = await FirebaseFirestore.instance
          .collection('sharedShoppingLists')
          .doc(sharedListId)
          .get();

      final memberUids = (doc.data()?['memberUids'] as List<dynamic>? ?? const [])
          .whereType<String>()
          .where((uid) => uid.isNotEmpty && uid != currentUid)
          .toSet()
          .toList();

      if (memberUids.isEmpty) {
        if (mounted) setState(() => _sharedMembers = const []);
        return;
      }

      final loadedMembers = <_ListMemberAvatar>[];
      for (var i = 0; i < memberUids.length; i += 10) {
        final chunk = memberUids.sublist(
          i,
          i + 10 < memberUids.length ? i + 10 : memberUids.length,
        );

        final snapshot = await FirebaseFirestore.instance
            .collection('users')
            .where(FieldPath.documentId, whereIn: chunk)
            .get();

        for (final userDoc in snapshot.docs) {
          final data = userDoc.data();
          loadedMembers.add(
            _ListMemberAvatar(
              uid: userDoc.id,
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

  void _showRenameDialog() {
    _renameController.text = widget.listName;

    showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Renombrar lista'),
          content: TextField(
            controller: _renameController,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Nuevo nombre de la lista',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () {
                final newName = _renameController.text.trim();
                if (newName.isNotEmpty) {
                  widget.onRename(newName);
                }
                Navigator.pop(context);
              },
              child: const Text('Guardar'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showDeleteConfirmationDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Eliminar lista'),
          content: Text(
            '¿Estás seguro de que quieres eliminar la lista "${widget.listName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      context.read<ShoppingProvider>().removeList(widget.listName);
    }
  }

  Future<void> _showLeaveSharedListDialog() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Desvincularte de la lista'),
          content: Text(
            '¿Quieres dejar de tener acceso a la lista "${widget.listName}"?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Sí, quitarme'),
            ),
          ],
        );
      },
    );

    if (confirmed == true && mounted) {
      await widget.onLeaveShared();
    }
  }

  @override
  Widget build(BuildContext context) {
    final shoppingProvider = context.read<ShoppingProvider>();
    final visibleMembers = _sharedMembers.take(4).toList();
    final extraMembersCount = _sharedMembers.length > 4 ? _sharedMembers.length - 4 : 0;
    final isDark = widget.isDark;

    final primary = isDark ? const Color(0xFF9DD388) : const Color(0xFF5E9C4C);
    final primarySoft = isDark ? const Color(0xFF7DBB74) : const Color(0xFFBFE0B0);
    final border = isDark ? const Color(0xFF4A6448) : const Color(0xFFBFE0B0);
    final textStrong = isDark ? Colors.white : const Color(0xFF234B2A);
    final cardShadow = isDark ? Colors.black.withValues(alpha: 0.35) : Colors.black.withValues(alpha: 0.08);
    final dangerColor = const Color(0xFFB35C5C);
    final gradientColors = isDark
        ? [const Color(0xFF1D2D1F).withValues(alpha: 0.85), const Color(0xFF243928).withValues(alpha: 0.85)]
        : [const Color(0xFFF6F8E8).withValues(alpha: 0.95), const Color(0xFFE7F4E1).withValues(alpha: 0.95)];

    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: SizedBox(
        width: 320,
        child: Stack(
          children: [
            MouseRegion(
              onEnter: (_) => setState(() => _isHovered = true),
              onExit: (_) => setState(() => _isHovered = false),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    shoppingProvider.selectList(widget.listName);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ListMainPage(listName: widget.listName),
                      ),
                    );
                  },
                  borderRadius: BorderRadius.circular(20),
                  splashColor: primary.withValues(alpha: 0.25),
                  highlightColor: primary.withValues(alpha: 0.10),
                  hoverColor: primary.withValues(alpha: 0.08),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: gradientColors,
                      ),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _isHovered ? primary : border,
                        width: _isHovered ? 1.8 : 1.4,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: cardShadow,
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    width: 320,
                    height: 100,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.list_alt_rounded, color: Colors.white, size: 16),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 3,
                              child: AutoSizeText(
                                widget.listName,
                                maxLines: 1,
                                minFontSize: 10,
                                stepGranularity: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: textStrong,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 1,
                              child: SizedBox(
                                // width: 55,
                              ),
                            )
                          ],
                        ),
                        const Spacer(),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                              decoration: BoxDecoration(
                                color: primary,
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Text(
                                '${widget.productCount} Productos',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (widget.isSharedList) ...[
                              if (_isLoadingMembers)
                                Padding(
                                  padding: const EdgeInsets.all(3.0),
                                  child: CircleAvatar(
                                    radius: 15,
                                    backgroundColor: primarySoft.withValues(alpha: 0.35),
                                    child: SizedBox(
                                      width: 12,
                                      height: 12,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: primary,
                                      ),
                                    ),
                                  ),
                                )
                              else ...[
                                ...visibleMembers.asMap().entries.map((entry) {
                                  final index = entry.key;
                                  final member = entry.value;
                                  final initials = member.displayName.trim().isNotEmpty
                                      ? member.displayName.trim().split(RegExp(r'\s+')).take(2).map((part) => part[0].toUpperCase()).join()
                                      : 'U';

                                  return Padding(
                                    padding: EdgeInsets.only(left: index == 0 ? 0 : 3.0, right: 3.0),
                                    child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: primarySoft,
                                      child: Text(
                                        initials,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  );
                                }),
                                if (extraMembersCount > 0)
                                  Padding(
                                    padding: const EdgeInsets.only(left: 3.0),
                                    child: CircleAvatar(
                                      radius: 15,
                                      backgroundColor: primary,
                                      child: Text(
                                        '+$extraMembersCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            Positioned(
              top: 4,
              right: 4,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.canManageList) ...[
                    IconButton(
                      iconSize: 25,
                      constraints: BoxConstraints(
                        minWidth: 35,
                        minHeight: 35
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: _showDeleteConfirmationDialog,
                      icon: Icon(Icons.delete_outline, color: dangerColor),
                      tooltip: 'Eliminar lista',
                    ),
                    IconButton(
                      iconSize: 23,
                      constraints: BoxConstraints(
                        minWidth: 35,
                        minHeight: 35
                      ),
                      padding: EdgeInsets.zero,
                      onPressed: _showRenameDialog,
                      icon: Icon(Icons.edit, color: primary),
                      tooltip: 'Renombrar lista',
                    ),
                  ] else if (widget.isSharedList) ...[
                    IconButton(
                      onPressed: _showLeaveSharedListDialog,
                      icon: Icon(Icons.person_remove_alt_1, color: dangerColor),
                      tooltip: 'Desvincularme de la lista',
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
