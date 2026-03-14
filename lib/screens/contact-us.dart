import 'package:flutter/material.dart';
import 'role.dart';

class ContactUsPage extends StatelessWidget {
  const ContactUsPage({super.key});

  static const Color primaryBlue = Color(0xFF112D75);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      /// --- MATCHED APP BAR WITH WHITE ICON LOGOUT ---
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,
        title: _appBarTitle(),
        actions: [_logoutButton(context)], // Updated method
      ),
      // Column approach maintains top-down layout
      body: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 30),

                  /// --- CONTACT INFO CARD ---
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 25),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                        vertical: 40,
                        horizontal: 30,
                      ),
                      decoration: BoxDecoration(
                        color: primaryBlue,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Column(
                        children: [
                          const Text(
                            "Contact us",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const Text(
                            "We’re here to help you",
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 40),
                          _contactDetail("Phone number", "+94 71 xxx xxxx"),
                          const SizedBox(height: 25),
                          _contactDetail("Email", "xxxxxxx@mail.com"),
                          const SizedBox(height: 25),
                          _contactDetail("Location", "Company location"),
                        ],
                      ),
                    ),
                  ),
                  // Extra space at bottom of scrollable area
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),

          // --- FOOTER REMOVED FROM HERE ---
        ],
      ),
    );
  }

  /// Helper for the contact info rows
  Widget _contactDetail(String title, String value) {
    return SizedBox(
      width: double.infinity,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  /// --- APP BAR UI COMPONENTS ---
  Widget _appBarTitle() {
    return Row(
      children: [
        Image.asset(
          'assets/white.png',
          height: 50,
          errorBuilder: (c, e, s) =>
              const Icon(Icons.bus_alert, color: Colors.white, size: 40),
        ),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Bus Lanka',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            Text(
              'Hi, Passenger',
              style: TextStyle(fontSize: 12, color: Colors.white70),
            ),
          ],
        ),
      ],
    );
  }

  /// --- UPDATED: White Icon Only Logout Button ---
  Widget _logoutButton(BuildContext context) {
    return IconButton(
      // Padding matches typical feedback page alignment
      padding: const EdgeInsets.only(right: 20),
      icon: const Icon(
        Icons.logout,
        color: Colors.white, // Setting icon to white
        size: 26, // Adjusting size to be prominent
      ),
      onPressed: () => Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (c) => const SelectRolePage()),
      ),
    );
  }
}
