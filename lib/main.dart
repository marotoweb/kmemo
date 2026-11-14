// lib/main.dart

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'database/database.dart';
import 'providers/memo_provider.dart';
import 'providers/theme_provider.dart';
import 'models/background_images.dart';
import 'services/kdrive_storage.dart';
import 'services/storage_repository.dart';
import 'services/webdav_storage.dart';
import 'services/link_preview_service.dart';
import 'ui/screens/home_screen.dart';
import 'l10n/app_localizations.dart';

/// Vivid amber shared by both themes so accent controls (switches, buttons,
/// selected segments) keep the same yellow in light and dark mode.
const Color kVividAmber = Color(0xFFFFC107);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // No app logging in production builds. Logcat can be read by other apps and
  // tools, and one careless log line is enough to expose the kDrive token or a
  // note's content.
  if (kReleaseMode) {
    debugPrint = (String? message, {int? wrapWidth}) {};
  }

  // Discover bundled background images before the UI is built.
  await loadNoteBackgroundImages();
  // Warm the link preview cache so cards render previews synchronously.
  await LinkPreviewService.preload();
  final database = AppDatabase();
  final kdriveStorage = KDriveStorage();
  final webdavStorage = WebDAVStorage();

  // Only the selected backend is initialised: it is the one that loads the
  // encryption passphrase into EncryptionService (both backends share it).
  final prefs = await SharedPreferences.getInstance();
  final backend = prefs.getString(kSyncBackendKey) ?? kSyncBackendKDrive;
  final isWebDav = backend == kSyncBackendWebDav;
  // Both backends load their configuration (so the settings screens can show
  // it), but only the active one pushes the passphrase into EncryptionService.
  await kdriveStorage.init(applyEncryption: !isWebDav);
  await webdavStorage.init(applyEncryption: isWebDav);
  final storage = isWebDav ? webdavStorage : kdriveStorage;
  debugPrint('[main] sync backend: ${storage.storageName}');

  runApp(
    MultiProvider(
      providers: [
        Provider<AppDatabase>.value(value: database),
        ChangeNotifierProvider(
          create: (_) => MemoProvider(database, storage: storage),
        ),
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        Provider<KDriveStorage>.value(value: kdriveStorage),
        Provider<WebDAVStorage>.value(value: webdavStorage),
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
      // Vivid amber is the primary color in both themes so switches, buttons
      // and selected controls look the same in light and dark mode. The seed
      // alone produces a muted olive in light mode and a blue accent in dark
      // mode, so the primary/onPrimary pair is overridden explicitly.
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          surface: Colors.white,
        ).copyWith(primary: kVividAmber, onPrimary: Colors.black87),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.dark,
        ),
        // Vivid amber is too light for text/borders on a white surface, so
        // text and outlined buttons use a darker amber while filled buttons
        // keep the vivid background with dark text.
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.amber.shade900),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kVividAmber,
            foregroundColor: Colors.black87,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.amber.shade900,
            side: const BorderSide(color: kVividAmber),
          ),
        ),
      ),
      // Define the dark theme
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.amber,
          brightness: Brightness.dark,
        ).copyWith(primary: kVividAmber, onPrimary: Colors.black87),
        scaffoldBackgroundColor: Colors.grey[900],
        appBarTheme: const AppBarTheme(
          systemOverlayStyle: SystemUiOverlayStyle.light,
        ),
        textButtonTheme: TextButtonThemeData(
          style: TextButton.styleFrom(foregroundColor: Colors.amber.shade300),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: kVividAmber,
            foregroundColor: Colors.black87,
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.amber.shade300,
            side: BorderSide(color: Colors.amber.shade300),
          ),
        ),
      ),
      themeMode: themeProvider.themeMode,
      locale: themeProvider.locale,
      home: HomeScreen(),
    );
  }
}
