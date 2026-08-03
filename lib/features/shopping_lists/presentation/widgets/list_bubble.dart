import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_main_page.dart';

class ListBubble extends StatefulWidget {
  const ListBubble({
    super.key,
    required this.colors,
    required this.listName,
    required this.productCount,
    required this.onRename,
  });

  final ColorScheme colors;
  final String listName;
  final int productCount;
  final ValueChanged<String> onRename;

  @override
  State<ListBubble> createState() => _ListBubbleState();
}

class _ListBubbleState extends State<ListBubble> {
  bool _isHovered = false;
  final TextEditingController _renameController = TextEditingController();

  @override
  void dispose() {
    _renameController.dispose();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final shoppingProvider = context.read<ShoppingProvider>();

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
                  borderRadius: BorderRadius.circular(10),
                  splashColor: Colors.green.withValues(alpha: 0.5),
                  highlightColor: Colors.black.withValues(alpha: 0.10),
                  hoverColor: Colors.white.withValues(alpha: 0.08),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    decoration: BoxDecoration(
                      color: _isHovered
                          ? widget.colors.primary.withValues(alpha: 0.85)
                          : widget.colors.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    width: 320,
                    height: 100,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 10,
                              ),
                              child: Text(
                                widget.listName,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 20,
                                ),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    margin: const EdgeInsets.only(left: 20),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 4,
                                        horizontal: 6,
                                      ),
                                      child: Text(
                                        '${widget.productCount} Productos',
                                        style: const TextStyle(
                                          color: Colors.black,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 4),
                            const Padding(
                              padding: EdgeInsets.all(3.0),
                              child: CircleAvatar(radius: 15, child: Icon(Icons.face)),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(3.0),
                              child: CircleAvatar(radius: 15, child: Icon(Icons.face_2)),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(3.0),
                              child: CircleAvatar(radius: 15, child: Icon(Icons.face_3)),
                            ),
                            const Padding(
                              padding: EdgeInsets.all(3.0),
                              child: CircleAvatar(radius: 15, child: Icon(Icons.face_4)),
                            ),
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
              child: IconButton(
                onPressed: _showRenameDialog,
                icon: const Icon(Icons.edit, color: Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
