import 'package:flutter/material.dart';
import 'dart:async';
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
    _navigateToNextPage();
  }

  // Timer logic for the splash screen
  void _navigateToNextPage() {
    Timer(const Duration(seconds: 3), () {
      // Replace 'SelectRolePage' with whichever page you want to show first
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => const SelectRolePage()),
      );
    });
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

            // --- LOGO ---
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

            // --- TITLE TEXT ---
            const Text(
              'Bus Lanka',
              style: TextStyle(
                fontSize: 48,
                fontWeight: FontWeight.w800,
                color: primaryBlue,
                letterSpacing:
                    -1.0, // Tightly spaces the letters like in your design
              ),
            ),

            const SizedBox(height: 80), // Space between text and loading circle
            // --- LOADING INDICATOR ---
            const CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(primaryBlue),
              strokeWidth: 4.0, // Makes the loading circle a bit thicker
            ),

            const Spacer(flex: 4),
          ],
        ),
      ),
    );
  }
}
