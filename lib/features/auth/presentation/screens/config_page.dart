import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';

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
        title: Text('Configuración'),
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
          Positioned.fill(child: Image.asset('assets/images/background/Background_Config_Image_1.jpg', fit: BoxFit.cover,)),
          SafeArea(
            child: ListView(
              children: [
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: 245,),
                    Row(
                      children: [
                        SizedBox(width: 90,),
                        Container(
                          width: 130,
                          height: 30,
                          decoration: BoxDecoration(
                            color: themeProvider.isDarkMode? Colors.black : Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            border: Border(),
                            boxShadow: [BoxShadow(color: Colors.grey, spreadRadius: 1.5)]
                          ),
                          child: Center(child: Text( themeProvider.isDarkMode? 'Tema Oscuro' : 'Tema Claro',style: TextStyle(fontSize: 15),)),
                        ),
                        Switch(
                          value: themeProvider.isDarkMode,
                          onChanged: (value) {
                            themeProvider.setDarkMode(value);
                          },
                        ),
                      ],
                    )
                  ],
                )
              ],
            ),
          ),
        ],
      ),
    );
  }
}