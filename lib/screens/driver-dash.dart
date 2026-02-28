import 'package:flutter/material.dart';
import 'role.dart';

class  DriverPage extends StatelessWidget {
  const DriverPage({Key? key}) : super(key: key);

  static const Color primaryBlue = Color(0xFF112D75);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        // --- LEFT SIDE: Logo and Text ---
        title: Row(
          children: [
            // Logo
            Image.asset(
              'assets/white.png',
              height: 77,
              width: 63,
              color: Colors.white,
              errorBuilder: (context, error, stackTrace) => const Icon(
                Icons.directions_bus,
                color: Colors.white,
                size: 40,
              ),
            ),
            const SizedBox(width: 12),

            // Text Column
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Bus Lanka',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: -0.5,
                  ),
                ),
                Text(
                  'Hi, User',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: Colors.white70,
                  ),
                ),
              ],
            ),
          ],
        ),

        // --- RIGHT SIDE: Logout Button ---
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: Center(
              // Centers the button vertically in the AppBar
              child: ElevatedButton(
                onPressed: () {
                  // TODO: Add logout logic here (e.g., clear session)
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SelectRolePage(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(
                    0xFFFF3B30,
                  ), // The bright red color
                  foregroundColor: Colors.white,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12), // Rounded corners
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Log Out',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(
                      Icons.logout, // The exit icon
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),

      // The rest of the page remains empty for now
      body: const SizedBox.shrink(),
    );
  }
}
