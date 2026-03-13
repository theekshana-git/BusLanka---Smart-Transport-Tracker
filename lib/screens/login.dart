import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
// Import your new model
import 'package:buslanka/models/user_model.dart'; 
import 'role.dart';
import 'driver-dash.dart';

class LoginPage extends StatefulWidget {
  final String expectedRole;

  const LoginPage({super.key, required this.expectedRole});

  static const Color primaryBlue = Color(0xFF112D75);

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController userController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

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

      // 1. Resolve email from username if necessary
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

      // 2. Firebase Auth login
      UserCredential credential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(email: email, password: password);

      // 3. Fetch User Data
      var userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(credential.user!.uid)
          .get();

      if (!userDoc.exists) {
        showError("User profile not found.");
        setState(() => loading = false);
        return;
      }

      UserModel currentUser = UserModel.fromFirestore(userDoc);

      if (!mounted) return;

      // 4. Role Validation
      if (currentUser.role != widget.expectedRole) {
        await FirebaseAuth.instance.signOut();
        showError("Access denied. You are not a ${widget.expectedRole}.");
        setState(() => loading = false);
        return;
      }

      // 5. Success Navigation
      if (currentUser.role == "driver") {
       Navigator.pushReplacement(
    context,
    MaterialPageRoute(
      // CRITICAL: Pass 'email', NOT 'userController.text'
      builder: (context) => DriverDashboard(userEmail: email), 
    ),
  );
      } else if (currentUser.role == "passenger") {
        Navigator.pushReplacementNamed(context, "/passenger");
      } else if (currentUser.role == "admin") {
        Navigator.pushReplacementNamed(context, "/admin");
      }
      
    } on FirebaseAuthException catch (e) {
      showError(e.message ?? "Login failed");
    } catch (e) {
      showError("An unexpected error occurred.");
      debugPrint(e.toString());
    }

    if (mounted) setState(() => loading = false);
  }

  void showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // --- UI build method remains the same as your provided code ---
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
                      child: Image.asset('assets/logo.png', height: 120, errorBuilder: (c, e, s) => const Icon(Icons.bus_alert, size: 80, color: LoginPage.primaryBlue)),
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
                    _buildInputField('Email or Username', userController, false),
                    const SizedBox(height: 20),
                    _buildInputField(
                      'Password',
                      passwordController,
                      obscurePassword,
                      isPasswordField: true,
                      onToggleVisibility: () => setState(() => obscurePassword = !obscurePassword),
                    ),
                    const Spacer(),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 40, top: 20),
                      child: ElevatedButton(
                        onPressed: loading ? null : login,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: LoginPage.primaryBlue,
                          minimumSize: const Size(double.infinity, 55),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: loading
                            ? const CircularProgressIndicator(color: Colors.white)
                            : const Text(
                                'Login',
                                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
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

  Widget _buildInputField(String label, TextEditingController controller, bool obscure, {bool isPasswordField = false, VoidCallback? onToggleVisibility}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: LoginPage.primaryBlue)),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          obscureText: obscure,
          decoration: InputDecoration(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            suffixIcon: isPasswordField
                ? IconButton(
                    icon: Icon(obscure ? Icons.visibility_off : Icons.visibility, color: LoginPage.primaryBlue.withOpacity(0.7)),
                    onPressed: onToggleVisibility,
                  )
                : null,
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LoginPage.primaryBlue)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: LoginPage.primaryBlue, width: 2)),
          ),
        ),
      ],
    );
  }
}