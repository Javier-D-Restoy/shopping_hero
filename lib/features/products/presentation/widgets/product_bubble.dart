import 'package:flutter/material.dart';

class ProductBubble extends StatelessWidget {
  const ProductBubble({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(4.0),
      child: Container(
        width: 100,
        height: 100,
        decoration: BoxDecoration(
          color: Colors.orange,
          borderRadius: BorderRadius.circular(10)),
      ),
    );
  }
}