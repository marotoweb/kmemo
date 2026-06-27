// lib/main.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'database/database.dart';
import 'providers/memo_provider.dart';
import 'ui/screens/home_screen.dart';

void main() async {
  // Garante que os bindings do Flutter estão prontos antes de inicializar a BD
  WidgetsFlutterBinding.ensureInitialized();

  // Inicializa a instância central do AppDatabase (Drift/SQLite)
  final database = AppDatabase();

  runApp(
    MultiProvider(
      providers: [
        // Injeta o AppDatabase no Provider para que possa ser usado por toda a app
        Provider<AppDatabase>.value(value: database),

        // Inicializa o MemoProvider passando a instância da base de dados do Drift
        ChangeNotifierProvider<MemoProvider>(
          create: (_) => MemoProvider(database),
        ),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'kMemo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}
