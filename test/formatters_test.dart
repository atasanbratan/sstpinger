import 'package:flutter_test/flutter_test.dart';
import 'package:sstp_shield/core/utils/formatters.dart';

void main() {
  group('Formatters.remaining', () {
    test('null is Unknown', () {
      expect(Formatters.remaining(null), 'Unknown');
    });

    test('past date is Expired', () {
      final past = DateTime.now().subtract(const Duration(days: 1));
      expect(Formatters.remaining(past), 'Expired');
    });

    test('under a day left', () {
      final soon = DateTime.now().add(const Duration(hours: 5));
      expect(Formatters.remaining(soon), 'Less than a day left');
    });

    test('days only, under a month', () {
      final in12 = DateTime.now().add(const Duration(days: 12, hours: 1));
      expect(Formatters.remaining(in12), '12 days left');
    });

    test('singular day', () {
      final in1 = DateTime.now().add(const Duration(days: 1, hours: 1));
      expect(Formatters.remaining(in1), '1 day left');
    });

    test('months and days', () {
      final in65 = DateTime.now().add(const Duration(days: 65, hours: 1));
      expect(Formatters.remaining(in65), '2 months, 5 days left');
    });

    test('exact months, no day remainder', () {
      final in60 = DateTime.now().add(const Duration(days: 60, hours: 1));
      expect(Formatters.remaining(in60), '2 months left');
    });

    test('singular month', () {
      final in30 = DateTime.now().add(const Duration(days: 30, hours: 1));
      expect(Formatters.remaining(in30), '1 month left');
    });
  });
}
