import 'package:flutter/material.dart';
import 'package:shopping_hero/features/products/presentation/widgets/product_bubble.dart';

class ListMainPage extends StatefulWidget {
  const ListMainPage({super.key});

  @override
  State<ListMainPage> createState() => _ListMainPageState();
}

class _ListMainPageState extends State<ListMainPage> {
  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      appBar: AppBar(
        title: Text('List Main Page'),
      ),
      body: GridView.count(
        crossAxisCount: 3,
        children: [
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
          ProductBubble(),
        ],
      )
    );
  }
}