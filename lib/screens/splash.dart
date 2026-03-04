import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'role.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  static const Color primaryBlue = Color(0xFF112D75);

  @override
  void initState() {
    super.initState();
    _handleStartup();
  }

  Future<void> _handleStartup() async {
    // 1. Show splash screen for 3 seconds
    await Future.delayed(const Duration(seconds: 3));

    // 2. FORCE LOGOUT: This fixes your "always logged in" issue
    // Every time the app starts, we clear the previous session.
    if (FirebaseAuth.instance.currentUser != null) {
      await FirebaseAuth.instance.signOut();
    }

    if (!mounted) return;

    // 3. Always navigate to role selection for a fresh start
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const SelectRolePage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SizedBox(
        width: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Spacer(flex: 3),
            Image.asset(
              'assets/logo.png',
              height: 150,
              width: 150,
              fit: BoxFit.contain,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.directions_bus,
                size: 100,
                color: primaryBlue,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Bus Lanka',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: primaryBlue,
                letterSpacing: -1.0,
              ),
            ),
            const SizedBox(height: 80),
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              strokeWidth: 4.0,
            ),
            const Spacer(flex: 4),
          ],
        ),
      ),
    );
  }
}