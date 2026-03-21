import 'package:flutter_test/flutter_test.dart';

String calculateStatus(double distance, double angleDiff, bool isGettingCloser) {
  if (distance > 3000) return "Away";
  if (distance < 50) return "Arrived";
  
  bool isFacingUser = angleDiff <= 45;

  if (isGettingCloser && isFacingUser) {
    return "Approaching";
  } else if (!isGettingCloser && distance < 1000) {
    return "Bus Passed";
  } else {
    return "Away";
  }
}

void main() {
  group('Bus Lanka Dynamic Status Engine Tests', () {
    
    test('1. Bus is outside geofence (> 3km)', () {
      expect(calculateStatus(3500, 10, true), "Away");
    });

    test('2. Bus is arriving (< 50m)', () {
      expect(calculateStatus(30, 0, true), "Arrived");
    });

    test('3. Bus is approaching (within 3km, facing user, getting closer)', () {
      expect(calculateStatus(1500, 20, true), "Approaching");
    });

    test('4. Bus has passed (distance increasing, within 1km)', () {
      expect(calculateStatus(800, 120, false), "Bus Passed");
    });
    
  });
}