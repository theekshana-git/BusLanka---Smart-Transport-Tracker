import 'package:flutter/material.dart';
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    await Future.delayed(const Duration(seconds: 3));

    User? user = FirebaseAuth.instance.currentUser;

    if (!mounted) return;

    if (user == null) {
      // Not logged in → go to role selection
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const SelectRolePage()),
      );
    } else {
      // Logged in → fetch role from Firestore
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (!doc.exists) {
        await FirebaseAuth.instance.signOut();
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SelectRolePage()),
        );
        return;
      }

      String role = doc['role'];

      if (role == "admin") {
        Navigator.pushReplacementNamed(context, "/admin");
      } else if (role == "driver") {
        Navigator.pushReplacementNamed(context, "/driver");
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SelectRolePage()),
        );
      }
    }
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