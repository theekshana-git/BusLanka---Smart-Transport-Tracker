import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  static const Color primaryBlue = Color(0xFF112D75);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false;

  Future<void> login() async {
    String userInput = userController.text.trim();
    String password = passwordController.text.trim();

    if (userInput.isEmpty || password.isEmpty) {
      showError("Enter credentials");
      return;
    }

    setState(() => loading = true);

    try {
      String email = userInput;

      // If user typed username instead of email
      if (!userInput.contains("@")) {
        var query = await FirebaseFirestore.instance
            .collection('users')
            .where('username', isEqualTo: userInput)
            .limit(1)
            .get();

        if (query.docs.isEmpty) {
          showError("User not found");
          setState(() => loading = false);
          return;
        }

        email = query.docs.first['email'];
      }

      // Firebase login
      UserCredential credential =
          await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      // get role
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      String role = userDoc['role'];

      if (!mounted) return;

      if (role == "admin") {
        Navigator.pushReplacementNamed(context, "/admin");
      } else if (role == "driver") {
        Navigator.pushReplacementNamed(context, "/driver");
      } else {
        showError("Invalid role");
      }
    } on FirebaseAuthException catch (e) {
      showError(e.message ?? "Login failed");
    }

    setState(() => loading = false);
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),

                    Align(
                      alignment: Alignment.center,
                      child: Image.asset(
                        'assets/logo.png',
                        height: 120,
                      ),
                    ),
                    const SizedBox(height: 16),

                    const Text(
                      'Login',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.w800,
                        color: LoginPage.primaryBlue,
                      ),
                    ),

                    const SizedBox(height: 50),

                    _buildInputField(
                        'Email or Username', userController, false),

                    const SizedBox(height: 20),

                    _buildInputField(
                        'Password', passwordController, true),

                    const Spacer(),

                    Padding(
                      padding: const EdgeInsets.only(bottom: 40, top: 20),
                      child: ElevatedButton(
                        onPressed: loading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LoginPage.primaryBlue,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: loading
                            ? const CircularProgressIndicator(
                                color: Colors.white)
                            : const Text(
                                'Login',
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInputField(
      String label, TextEditingController controller, bool obscure) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: const TextStyle(
                fontWeight: FontWeight.w600,
                color: LoginPage.primaryBlue)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: LoginPage.primaryBlue),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(
                  color: LoginPage.primaryBlue, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}