import 'package:flutter/material.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/api_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase Cloud
  try {
    await Supabase.initialize(
      url: ApiService.supabaseUrl,
      anonKey: ApiService.supabaseAnonKey,
    );
  } catch (e) {
    debugPrint('Supabase init note: $e');
  }

  // Auto-discover fastest reachable backend server
  await ApiService.initialize();

  runApp(const CognitoTechHubApp());
}

class CognitoTechHubApp extends StatelessWidget {
  const CognitoTechHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cognito Tech Hub',
      debugShowCheckedModeBanner: false,
      theme: CognitoTheme.lightTheme,
      builder: (context, child) {
        final mediaQuery = MediaQuery.of(context);
        // Clamp text scale between 0.85 and 1.10 so custom fonts or accessibility scaling don't break card layout
        final clampedTextScaler = mediaQuery.textScaler.clamp(
          minScaleFactor: 0.85,
          maxScaleFactor: 1.10,
        );
        return MediaQuery(
          data: mediaQuery.copyWith(textScaler: clampedTextScaler),
          child: child ?? const SizedBox(),
        );
      },
      home: const SplashScreen(),
    );
  }
}
