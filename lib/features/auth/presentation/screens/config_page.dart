import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:shopping_hero/features/auth/presentation/widgets/fontsize_segmented_button.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 40,
        title: const Text('Configuración'),
        centerTitle: true,
        leading: BackButton(
          onPressed: () {
            if (context.mounted) {
              Navigator.pop(context);
            }
          },
        ),
      ),
      body: Stack(
        children: [
          // 1. Imagen de Fondo
          Positioned.fill(
            child: Image.asset(
              'assets/images/background/Background_Config_Image_1.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // 2. Elemento posicionado en coordenadas específicas (ej. Top: 150, Right: 20)
          Positioned(
            top: 250, 
            right: 0, 
            left: 0,
            child: Center(
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 130,
                    height: 30,
                    decoration: BoxDecoration(
                      color: themeProvider.isDarkMode ? Colors.black : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: const [
                        BoxShadow(color: Colors.grey, spreadRadius: 1.5),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        themeProvider.isDarkMode ? 'Tema Oscuro' : 'Tema Claro',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Switch(
                    value: themeProvider.isDarkMode,
                    onChanged: (value) {
                      themeProvider.setDarkMode(value);
                    },
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 340,
            right: 0,
            left: 0,
            child: Center(
              child: FontSizeSegmentedButton(value: themeProvider.fontSize, onChanged: (newSize) {
                themeProvider.setFontSize(newSize);
              }),
            ),
          )
        ],
      ),
    );
  }
}