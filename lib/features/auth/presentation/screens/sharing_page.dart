import 'package:flutter/material.dart';

class SharingPage extends StatelessWidget {
  const SharingPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: Colors.orange),
            ),
            const SizedBox(height: 20),
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: Colors.blue),
            ),
            const SizedBox(height: 20),
            Container(
              width: 20,
              height: 20,
              decoration: const BoxDecoration(color: Colors.orange),
            ),
          ],
        )
      ],
    );
  }
}