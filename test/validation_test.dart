import 'package:flutter_test/flutter_test.dart';

String? validateDriverPassword(String password, String confirmPassword) {
  if (password.length < 6) return "Password must be at least 6 characters";
  if (password != confirmPassword) return "Passwords do not match";
  return null; // Null means valid
}

void main() {
  group('Admin Driver Registration Validation', () {
    
    test('1. Reject passwords under 6 characters', () {
      expect(validateDriverPassword("12345", "12345"), "Password must be at least 6 characters");
    });

    test('2. Reject mismatched passwords', () {
      expect(validateDriverPassword("securePass1", "securePass2"), "Passwords do not match");
    });

    test('3. Accept valid, matching passwords', () {
      expect(validateDriverPassword("securePass1", "securePass1"), null);
    });
    
  });
}