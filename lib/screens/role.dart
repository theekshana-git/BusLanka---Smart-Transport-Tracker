import 'package:flutter/material.dart';
import 'package:buslanka/screens/login.dart';
import 'package:buslanka/screens/pass-dash.dart';

class SelectRolePage extends StatelessWidget {
  const SelectRolePage({super.key});

  // Define the primary dark blue color used throughout the design
  static const Color primaryBlue = Color(0xFF112D75);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SizedBox(
          width: double.infinity,
          child: Column(
            children: [
              const Spacer(flex: 3),

              // Page Title
              const Text(
                'Select Role',
                style: TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.w800,
                  color: primaryBlue,
                  letterSpacing: -0.5,
                ),
              ),

              const SizedBox(height: 60),

              // Role Buttons
              _buildRoleButton(
                'Passenger',
                onPressed: () {
                  // Navigate to the PassengerPage when the Passenger button is pressed
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PassengerPage(),
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),

              _buildRoleButton(
                'Driver',
                onPressed: () {
                  // Navigate to the LoginPage when the Driver button is pressed
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
              ),
              const SizedBox(height: 24),

              _buildRoleButton(
                'Admin',
                onPressed: () {
                  // Navigate to the LoginPage when the Driver button is pressed
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (context) => const LoginPage()),
                  );
                },
              ),

              const Spacer(flex: 4),

              // Footer Text
              const Padding(
                padding: EdgeInsets.only(bottom: 40.0),
                child: Text(
                  'To register as a driver,\nPlease contact 07x xxx xxxx.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: primaryBlue,
                    height: 1.5,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Reusable button widget to maintain design consistency
  Widget _buildRoleButton(String title, {required VoidCallback onPressed}) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        minimumSize: const Size(280, 65), // Wide and tall buttons
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20), // Rounded corners
        ),
      ),
      child: Text(
        title,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
    );
  }
}
