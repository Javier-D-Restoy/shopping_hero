import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:shopping_hero/core/providers/shopping_provider.dart';
import 'package:shopping_hero/core/providers/theme_provider.dart';
import 'package:shopping_hero/core/theme/app_theme.dart';
import 'package:shopping_hero/features/auth/presentation/screens/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  final shoppingProvider = ShoppingProvider();
  final themeProvider = ThemeProvider();

  await Future.wait([
    shoppingProvider.init(),
    themeProvider.init(),
  ]);

  // printHivePath(); // SOLO COMO DEBUG | QUITAR CUANDO NO SEA NECESARIO

  runApp(
    MyApp(
      shoppingProvider: shoppingProvider,
      themeProvider: themeProvider,
    ),
  );
}

// FUNCION PARA SABER DONDE ESTA GUARDANDO LOS DATOS EN LOCAL
Future<void> printHivePath() async {
  final dir = await getApplicationDocumentsDirectory();
  print(dir.path);
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.shoppingProvider,
    required this.themeProvider,
  });

  final ShoppingProvider shoppingProvider;
  final ThemeProvider themeProvider;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ShoppingProvider>.value(value: shoppingProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) {
          return MaterialApp(
            title: 'Shopping Hero',
            debugShowCheckedModeBanner: false,
            theme: AppTheme(selectedColor: 0, isDarkMode: themeProvider.isDarkMode).theme(),
            home: LoginPage(),
          );
        },
      ),
    );
  }
}

