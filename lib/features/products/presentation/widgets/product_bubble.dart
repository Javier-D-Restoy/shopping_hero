import 'package:flutter/material.dart';

enum ProductAdd{active, frequent}

class ProductBubble extends StatelessWidget {
  const ProductBubble({
    super.key,
    required this.label,
    this.onTap, required this.productAdd,
  });
  

  final String label;
  final ProductAdd productAdd;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.all(1),
          child: Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: productAdd == ProductAdd.active
                ? Colors.orange
                : productAdd == ProductAdd.frequent
                  ? Colors.green
                  : Colors.grey,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [BoxShadow(color: Colors.black, spreadRadius: 1)],
            ),
            child: Center(
              child: Stack(
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      // color: Colors.white,
                      fontWeight: FontWeight.bold,
                      foreground: Paint()
                        ..style = PaintingStyle.stroke
                        ..strokeWidth = 3 // Grosor del borde
                        ..color = Colors.black,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  Text(
                    label,
                    style: TextStyle(
                      // color: Colors.white,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
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