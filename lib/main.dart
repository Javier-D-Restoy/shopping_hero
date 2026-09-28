import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
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

  // 1. Inicializar Firebase
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  // 2. Inicializar Hive
  final Directory appSupportDir = await getApplicationSupportDirectory();
  final Directory hiveDir = Directory(appSupportDir.path);

  if (!await hiveDir.exists()) {
    await hiveDir.create(recursive: true);
  }

  await Hive.initFlutter(hiveDir.path);

  final sessionProvider = SessionProvider();
  final shoppingProvider = ShoppingProvider();
  final themeProvider = ThemeProvider();

  // 3. Inicializar el estado guardado de la sesión en Hive
  await sessionProvider.init();

  // --- CORRECCIÓN CLAVE TRAS REINSTALACIÓN ---
  // Si en Hive NO hay una sesión activa registrada pero Firebase Auth conserva un usuario en el Keychain/KeyStore,
  // forzamos el cierre de sesión en Firebase para empezar totalmente limpios desde LoginPage.
  if (!sessionProvider.hasActiveSession) {
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }
  }

  // 4. Configurar ShoppingProvider con los datos de sesión resueltos
  await shoppingProvider.setCurrentUser(
    sessionProvider.uid,
    isOffline: sessionProvider.isOffline,
  );

  await Future.wait([
    themeProvider.init(),
    shoppingProvider.init(isOffline: sessionProvider.isOffline),
  ]);

  // 5. Determinar la pantalla inicial en función del estado real guardado
  Widget initialScreen = const LoginPage();

  if (sessionProvider.hasActiveSession) {
    // Si la sesión era Online, sincronizamos las listas
    if (!sessionProvider.isOffline && sessionProvider.uid != null) {
      await shoppingProvider.switchUserEnvironment(isOffline: false);
    }

    initialScreen = const ListManager();

    // Redirección si se quedó dentro de una lista concreta
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
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached) {
      context.read<ShoppingProvider>().saveToStorage(mergeCloud: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
