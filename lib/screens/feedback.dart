import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // ADDED FIRESTORE IMPORT

class FeedbackPage extends StatelessWidget {
  FeedbackPage({super.key});

  final TextEditingController nameController = TextEditingController();
  final TextEditingController feedbackController = TextEditingController();

  static const Color primaryBlue = Color(0xFF112D75);
  final Color borderBlue = const Color(0xFF2E5AAC);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        backgroundColor: primaryBlue,
        elevation: 0,
        toolbarHeight: 80,
        automaticallyImplyLeading: false,

        /// --- APP BAR LOGO & TEXT ---
        title: Row(
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
        ),
        actions: [
          /// --- CLEAN LOGOUT BUTTON ---
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Icons.logout, color: Colors.white, size: 26),
            tooltip: 'Log Out',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          return SingleChildScrollView(
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: IntrinsicHeight(
                child: Column(
                  children: [
                    const SizedBox(height: 40),
                    const Text(
                      "Give us a feedback",
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 30),

                    /// NAME FIELD
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: TextField(
                        controller: nameController,
                        decoration: _inputDecoration("Your Name (Optional)", 25),
                      ),
                    ),
                    const SizedBox(height: 20),

                    /// FEEDBACK FIELD
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 25),
                      child: TextField(
                        controller: feedbackController,
                        maxLines: 6,
                        decoration: _inputDecoration("Your feedback...", 20),
                      ),
                    ),
                    const SizedBox(height: 35),

                    /// SUBMIT BUTTON
                    SizedBox(
                      width: 240,
                      height: 55,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF002D72), 
                          foregroundColor: Colors.white,
                          elevation: 4,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        // --- UPDATED DATABASE LOGIC HERE ---
                        onPressed: () async {
                          String name = nameController.text.trim();
                          String feedback = feedbackController.text.trim();

                          // 1. Check if feedback is empty
                          if (feedback.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text("Please enter a message first!"),
                                backgroundColor: Colors.orange,
                              ),
                            );
                            return;
                          }

                          // 2. If name is empty, set as Anonymous
                          if (name.isEmpty) {
                            name = "Anonymous";
                          }

                          try {
                            // 3. Send to Firestore
                            await FirebaseFirestore.instance.collection('feedbacks').add({
                              'name': name,
                              'message': feedback,
                              'timestamp': FieldValue.serverTimestamp(),
                            });

                            // 4. Clear the text fields
                            nameController.clear();
                            feedbackController.clear();

                            // 5. Show Success Message
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text("Feedback submitted successfully! Thank you."),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            }
                          } catch (e) {
                            // Catch any database errors
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text("Error submitting feedback: $e"),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        child: const Text(
                          "Submit Feedback",
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),

                    // Fills space to push the About section to the bottom
                    const Spacer(),
                    const SizedBox(height: 50),

                    /// ABOUT US CONTAINER
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.fromLTRB(30, 45, 30, 60),
                      color: primaryBlue,
                      child: const Column(
                        children: [
                          Text(
                            "About Us",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 20),
                          Text(
                            "Bus Lanka is a real-time bus tracking system designed to maximize public transportation in Sri Lanka. We bridge the gap between commuters and buses by providing live tracking and accurate arrival times (ETA) on any device.",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 15,
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  /// Reusable InputDecoration for the text fields
  InputDecoration _inputDecoration(String hint, double radius) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: borderBlue, width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(radius),
        borderSide: BorderSide(color: borderBlue, width: 2.2),
      ),
    );
  }
}