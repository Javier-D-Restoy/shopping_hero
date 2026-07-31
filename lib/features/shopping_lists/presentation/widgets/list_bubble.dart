import 'package:flutter/material.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_main_page.dart';

class ListBubble extends StatefulWidget {
  const ListBubble({
    super.key,
    required this.colors,
  });

  final ColorScheme colors;

  @override
  State<ListBubble> createState() => _ListBubbleState();
}

class _ListBubbleState extends State<ListBubble> {
  bool _isHovered = false;
  final String _listName = 'lista';

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: MouseRegion(
        onEnter: (_) => setState(() => _isHovered = true),
        onExit: (_) => setState(() => _isHovered = false),
        child: Material(  // Inkwell necesita un material padre para pintar sus efectos visuales ripple, splash, highlight y hover correctamente
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const ListMainPage(),));
            },
            borderRadius: BorderRadius.circular(10),
            splashColor: Colors.green.withValues(alpha: 0.5),  // efecto al pulsar
            highlightColor: Colors.black.withValues(alpha: 0.10), // efecto de presionado
            hoverColor: Colors.white.withValues(alpha: 0.08), // efecto al pasar el raton por encima
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
              child: Row(
                children: [
                  Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 10,
                        ),
                        child: Text(
                          _listName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                          ),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(15),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.symmetric(
                            vertical: 4,
                            horizontal: 6,
                          ),
                          child: Text(
                            'XX Productos',
                            style: TextStyle(
                              color: Colors.black,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 20),
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
            ),
          ),
        ),
      ),
    );
  }
}