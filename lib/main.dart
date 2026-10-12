// lib/main.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/database.dart';
import 'providers/memo_provider.dart';
import 'providers/theme_provider.dart';
import 'ui/screens/home_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final database = AppDatabase();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => MemoProvider(database)),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
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
      // Define o tema claro (Light Theme)
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          surface: Colors.white,
        ),
        scaffoldBackgroundColor: Colors.white,
      ),
      // Define o tema escuro (Dark Theme)
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blueGrey,
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: Colors.grey[900],
      ),
      themeMode: themeProvider.themeMode,
      home: const HomeScreen(),
    );
  }
}
