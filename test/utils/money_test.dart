import 'package:delime/utils/money.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('conversion to cents', () {
    test('EUR rounds to the nearest cent', () {
      expect(Money.eurToCents(2.5), 250);
      expect(Money.eurToCents(0), 0);
      expect(Money.eurToCents(12.345), 1235); // rounds up
      expect(Money.eurToCents(12.344), 1234); // rounds down
    });

    test('MKD converts at the fixed 1 EUR = 61.5 MKD rate', () {
      expect(Money.mkdPerEur, 61.5);
      expect(Money.mkdToCents(61.5), 100);
      expect(Money.mkdToCents(123), 200);
      expect(Money.mkdToCents(0), 0);
    });
  });

  group('conversion from cents', () {
    test('cents to EUR / MKD', () {
      expect(Money.centsToEur(250), 2.5);
      expect(Money.centsToMkd(100), 61.5);
    });
  });

  group('formatting', () {
    test('EUR uses the € symbol and two decimals', () {
      expect(Money.formatEur(1234), '€12.34');
      expect(Money.formatEur(0), '€0.00');
      expect(Money.formatEur(100000), '€1,000.00');
    });

    test('MKD uses the ден suffix', () {
      expect(Money.formatMkd(100), '61.50 ден');
      expect(Money.formatMkd(0), '0.00 ден');
    });

    test('both currencies in one string', () {
      expect(Money.formatBoth(250), '€2.50 · 153.75 ден');
    });
  });

  group('splitEqually', () {
    test('distributes leftover cents one-per-person from the top', () {
      expect(Money.splitEqually(1000, 3), [334, 333, 333]);
      expect(Money.splitEqually(7, 3), [3, 2, 2]);
      expect(Money.splitEqually(5, 2), [3, 2]);
    });

    test('divides evenly when possible', () {
      expect(Money.splitEqually(100, 4), [25, 25, 25, 25]);
    });

    test('the parts always sum back to the total', () {
      for (final total in [0, 1, 99, 100, 1000, 9999]) {
        for (final n in [1, 2, 3, 4, 7]) {
          final parts = Money.splitEqually(total, n);
          expect(parts.length, n);
          expect(
            parts.reduce((a, b) => a + b),
            total,
            reason: 'total=$total n=$n',
          );
        }
      }
    });

    test('zero total yields all-zero shares', () {
      expect(Money.splitEqually(0, 3), [0, 0, 0]);
    });

    test('non-positive count yields an empty list', () {
      expect(Money.splitEqually(100, 0), isEmpty);
      expect(Money.splitEqually(100, -1), isEmpty);
    });
  });

  group('InputCurrency', () {
    test('labels and symbols', () {
      expect(InputCurrency.eur.label, 'EUR');
      expect(InputCurrency.eur.symbol, '€');
      expect(InputCurrency.mkd.label, 'MKD');
      expect(InputCurrency.mkd.symbol, 'ден');
    });
  });
}
