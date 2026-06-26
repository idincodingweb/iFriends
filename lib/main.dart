import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'config/app_config.dart';
import 'theme/app_theme.dart';
import 'screens/splash_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: AppConfig.firebaseAndroidOptions,
    );
  } catch (e) {
    // Allow app to still boot in dev when Firebase keys not yet filled.
    debugPrint('Firebase init failed: $e');
  }
  runApp(const IFriendsApp());
}

class IFriendsApp extends StatelessWidget {
  const IFriendsApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iFriends',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: const SplashScreen(),
    );
  }
}
