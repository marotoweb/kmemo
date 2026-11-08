// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'database/database.dart';
import 'providers/memo_provider.dart';
import 'providers/theme_provider.dart';
import 'models/background_images.dart';
import 'services/kdrive_storage.dart';
import 'ui/screens/home_screen.dart';
import 'l10n/app_localizations.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Discover bundled background images before the UI is built.
  await loadNoteBackgroundImages();
  final database = AppDatabase();
  final storage = KDriveStorage();
  // Load saved configuration (token, drive) before creating the provider
  await storage.init();

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider(
          create: (_) => MemoProvider(database, storage: storage),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<KDriveStorage>.value(value: storage),
      ],
      child: const KMemoApp(),
    ),
  );
}

class KMemoApp extends StatelessWidget {
  const KMemoApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'kmemo',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Define the light theme
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
      ),
      // Define the dark theme
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
      ),
      themeMode: themeProvider.themeMode,
      locale: themeProvider.locale,
      home: HomeScreen(),
    );
  }
}
