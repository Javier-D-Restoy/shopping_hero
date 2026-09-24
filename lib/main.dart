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
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_manager_page.dart';
import 'package:shopping_hero/features/shopping_lists/presentation/screens/list_main_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializar Firebase en la app  (FIREBASE)  - Esto es obligatorio. Sin esto, Firestore no sabe a qué proyecto conectarse.
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

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
  await shoppingProvider.setCurrentUser(
    sessionProvider.uid,
    isOffline: sessionProvider.isOffline,
  );
  // Inicializamos el theme y el shopping provider pasando el estado isOffline actual
  await Future.wait([
    themeProvider.init(),
    shoppingProvider.init(isOffline: sessionProvider.isOffline),
  ]);

  if (!sessionProvider.isOffline && sessionProvider.uid != null) {
    await shoppingProvider.switchUserEnvironment(isOffline: false);
  }

  // Restauramos la última pantalla visitada (ListManager o ListMainPage) si había
  // una sesión activa, tanto online como offline.
  Widget initialScreen = const LoginPage();
  if (sessionProvider.hasActiveSession) {
    initialScreen = const ListManager();
    if (sessionProvider.lastRoute == 'listMain') {
      final lastListName = sessionProvider.lastListName;
      if (lastListName != null &&
          shoppingProvider.shoppingLists.containsKey(lastListName)) {
        initialScreen = ListMainPage(listName: lastListName);
      }
    }
  }

  runApp(
    MyApp(
      sessionProvider: sessionProvider,
      shoppingProvider: shoppingProvider,
      themeProvider: themeProvider,
      initialScreen: initialScreen,
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({
    super.key,
    required this.sessionProvider,
    required this.shoppingProvider,
    required this.themeProvider,
    required this.initialScreen,
  });

  final SessionProvider sessionProvider;
  final ShoppingProvider shoppingProvider;
  final ThemeProvider themeProvider;
  final Widget initialScreen;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SessionProvider>.value(value: sessionProvider),
        ChangeNotifierProvider<ShoppingProvider>.value(value: shoppingProvider),
        ChangeNotifierProvider<ThemeProvider>.value(value: themeProvider),
      ],
      child: AppLifecycleWrapper(
        child: Consumer<ThemeProvider>(
          builder: (context, themeProvider, _) {
            return MaterialApp(
              title: 'Shopping Hero',
              debugShowCheckedModeBanner: false,
              theme: AppTheme(
                selectedColor: 0,
                isDarkMode: themeProvider.isDarkMode,
              ).theme(),
              home: initialScreen,
            );
          },
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------
// WIDGET OBSERVADOR DEL CICLO DE VIDA (Captura minimizado o cierre)
// ------------------------------------------------------------------
class AppLifecycleWrapper extends StatefulWidget {
  final Widget child;
  const AppLifecycleWrapper({super.key, required this.child});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Si la aplicación se va a segundo plano (paused) o se cierra (detached)
    if (state == AppLifecycleState.paused || state == AppLifecycleState.detached) {
      // Forzamos la persistencia en Hive
      context.read<ShoppingProvider>().saveToStorage(mergeCloud: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
