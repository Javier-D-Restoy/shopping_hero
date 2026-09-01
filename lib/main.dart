import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shopping_hero/firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/session_provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:shopping_hero/core/theme/app_theme.dart';
import 'package:shopping_hero/features/auth/presentation/screens/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase en la app  (FIREBASE)  - Esto es obligatorio. Sin esto, Firestore no sabe a qué proyecto conectarse.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // 1. Obtener directorio base e instanciar la subcarpeta    (HIVE_CE)
  final Directory appSupportDir = await getApplicationSupportDirectory();
  final Directory hiveDir = Directory(appSupportDir.path);

  // 2. Crear la carpeta si no existe previamente   (HIVE_CE)
  if (!await hiveDir.exists()) {
    await hiveDir.create(recursive: true);
  }

  await Hive.initFlutter(hiveDir.path);

  final sessionProvider = SessionProvider();
  final shoppingProvider = ShoppingProvider();
  final themeProvider = ThemeProvider();

  // Inicializamos primero el estado de la sesión
  await sessionProvider.init();

  // Inicializamos el theme y el shopping provider pasando el estado isOffline actual
  await Future.wait([
    themeProvider.init(),
    shoppingProvider.init(isOffline: sessionProvider.isOffline),
  ]);

  runApp(
    MyApp(
      sessionProvider: sessionProvider,
      shoppingProvider: shoppingProvider,
      themeProvider: themeProvider,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.sessionProvider,
    required this.shoppingProvider,
    required this.themeProvider,
  });

  final SessionProvider sessionProvider;
  final ShoppingProvider shoppingProvider;
  final ThemeProvider themeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionProvider>.value(value: sessionProvider),
        ChangeNotifierProvider<ShoppingProvider>.value(value: shoppingProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Shopping Hero',
            debugShowCheckedModeBanner: false,
            theme: AppTheme(
              selectedColor: 0,
              isDarkMode: themeProvider.isDarkMode,
            ).theme(),
            home: const LoginPage(),
          );
        },
      ),
    );
  }
}