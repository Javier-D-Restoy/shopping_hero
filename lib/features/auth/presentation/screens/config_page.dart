import 'package:flutter/material.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_manager_page.dart';

class ConfigPage extends StatefulWidget {
  const ConfigPage({super.key});

  @override
  State<ConfigPage> createState() => _ConfigPageState();
}

class _ConfigPageState extends State<ConfigPage> {

  bool isFirstConfigActive = false;
  bool isSecondConfigActive = false;
  bool isThirdConfigActive = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Configuration'),
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
                    Row(
                      children: [
                        SizedBox(width: 50,),
                        Container(
                          width: 120,
                          height: 40,
                          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                          child: Text('Modo Dia/Noche',textAlign: TextAlign.center,),
                        ),
                        Switch(
                          value: isFirstConfigActive,
                          onChanged: (value) {
                            setState(() {
                              isFirstConfigActive = value;
                            });
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 290,),
                    Container(
                      width: 200,
                      height: 50,
                      decoration: BoxDecoration(color: Colors.white),
                      child: Row(
                        children: [
                          Text('Modo Claro/Oscuro')
                        ],
                      ),
                    ),
                    SizedBox(height: 60,),
                    Container(
                      width: 200,
                      height: 50,
                      decoration: BoxDecoration(color: Colors.white),
                      child: Row(
                        children: [
                          Text('Modo Claro/Oscuro')
                        ],
                      ),
                    ),
                    SizedBox(height: 60,),
                    Container(
                      width: 200,
                      height: 50,
                      decoration: BoxDecoration(color: Colors.white),
                      child: Row(
                        children: [
                          Text('Modo Claro/Oscuro')
                        ],
                      ),
                    ),
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