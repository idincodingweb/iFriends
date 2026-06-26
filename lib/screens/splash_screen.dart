import 'dart:async';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'auth_gate.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AuthGate()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.vibrant),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(.15),
                  borderRadius: BorderRadius.circular(32),
                  border: Border.all(color: Colors.white, width: 3),
                ),
                child: const Icon(Icons.favorite,
                    color: Colors.white, size: 56),
              ),
              const SizedBox(height: 20),
              const Text(
                'iFriends',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Stay close to your circle',
                style: TextStyle(
                  color: Colors.white.withOpacity(.85),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
