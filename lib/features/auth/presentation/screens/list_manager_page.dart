import 'package:flutter/material.dart';

class ListManager extends StatelessWidget {
  const ListManager({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Icon(Icons.abc),
        title: Text('List Manager'),
      ),
      body: ListView(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                color: Colors.blue,
              ),
              Container(
                color: Colors.red,
              ),
              Container(
                color: Colors.blue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}