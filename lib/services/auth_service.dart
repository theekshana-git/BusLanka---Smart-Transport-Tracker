import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Login
  Future<String?> login(String email, String password) async {
    try {
      UserCredential credential =
          await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      String uid = credential.user!.uid;

      // Get role from Firestore
      DocumentSnapshot userDoc =
          await _firestore.collection('users').doc(uid).get();

      if (!userDoc.exists) {
        return "No role assigned to this user.";
      }

      return userDoc['role']; // returns 'admin' or 'driver'
    } on FirebaseAuthException catch (e) {
      return e.message;
    }
  }

  // Logout
  Future<void> logout() async {
    await _auth.signOut();
  }

  // Current user
  User? get currentUser => _auth.currentUser;
}