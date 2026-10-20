import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_displaymode/flutter_displaymode.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:sherpa_onnx/sherpa_onnx.dart' as sherpa;
import 'views/home_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize sherpa-onnx native bindings for offline STT/TTS
  try {
    await sherpa.initBindingsAsync();
  } catch (e) {
    debugPrint('Failed to initialize sherpa-onnx bindings: $e');
  }

  // Enable 120Hz High Refresh Rate on supported Android devices
  if (Platform.isAndroid) {
    try {
      await FlutterDisplayMode.setHighRefreshRate();
    } catch (e) {
      debugPrint('Failed to set 120Hz display mode: $e');
    }
  }

  // Edge-to-edge transparent navigation & status bars
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
    ),
  );
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  runApp(const ProviderScope(child: VoiceNotesApp()));
}

class VoiceNotesApp extends StatelessWidget {
  const VoiceNotesApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Modern Dark Palette with Indigo accents
    final darkColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1), // Modern Indigo
      brightness: Brightness.dark,
      surface: const Color(0xFF111318),
      surfaceContainer: const Color(0xFF1A1D24),
      surfaceContainerHigh: const Color(0xFF222630),
      surfaceContainerHighest: const Color(0xFF2B303C),
    );

    final lightColorScheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF6366F1),
      brightness: Brightness.light,
    );

    return MaterialApp(
      title: 'VoiceNotes Offline',
      debugShowCheckedModeBanner: false,
      themeMode: ThemeMode.system,

      // Light Theme
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: lightColorScheme,
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
      ),

      // Dark Theme (Default preferred for audio / voice notes)
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: darkColorScheme,
        scaffoldBackgroundColor: const Color(0xFF111318),
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        appBarTheme: const AppBarTheme(
          centerTitle: false,
          backgroundColor: Color(0xFF111318),
          elevation: 0,
          scrolledUnderElevation: 1,
        ),
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: ZoomPageTransitionsBuilder(),
            TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
            TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          },
        ),
      ),

      home: const HomeView(),
    );
  }
}
