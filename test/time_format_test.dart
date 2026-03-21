import 'package:flutter_test/flutter_test.dart';

String formatTimeAgo(DateTime timestamp, DateTime now) {
  Duration diff = now.difference(timestamp);
  if (diff.inMinutes < 1) return "Just now";
  if (diff.inHours < 1) return "${diff.inMinutes}m ago";
  if (diff.inDays < 1) return "${diff.inHours}h ago";
  return "${diff.inDays}d ago";
}

void main() {
  group('Time Formatting Tests', () {
    final DateTime mockNow = DateTime(2026, 3, 20, 12, 0, 0); // Noon

    test('1. Less than a minute shows "Just now"', () {
      final inputTime = DateTime(2026, 3, 20, 11, 59, 30);
      expect(formatTimeAgo(inputTime, mockNow), "Just now");
    });

    test('2. Under an hour shows minutes', () {
      final inputTime = DateTime(2026, 3, 20, 11, 45, 0);
      expect(formatTimeAgo(inputTime, mockNow), "15m ago");
    });

    test('3. Under a day shows hours', () {
      final inputTime = DateTime(2026, 3, 20, 9, 0, 0);
      expect(formatTimeAgo(inputTime, mockNow), "3h ago");
    });
  });
}