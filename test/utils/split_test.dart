import 'package:delime/utils/split.dart';
import 'package:flutter_test/flutter_test.dart';

int _sum(List<int> xs) => xs.fold(0, (a, b) => a + b);

void main() {
  group('allocateByWeights', () {
    test('distributes proportionally and sums to the total', () {
      expect(SplitMath.allocateByWeights(1000, [1, 1]), [500, 500]);
      expect(SplitMath.allocateByWeights(1000, [3, 1]), [750, 250]);
    });

    test('hands leftover units to the largest remainders', () {
      // 1000 by [1,1,1]: 333 each + 1 leftover to the first.
      expect(SplitMath.allocateByWeights(1000, [1, 1, 1]), [334, 333, 333]);
      // 100 by [1,1,1]: 33 each + 1 leftover.
      expect(_sum(SplitMath.allocateByWeights(100, [1, 1, 1])), 100);
    });

    test('equal weights match Money.splitEqually behaviour', () {
      expect(SplitMath.allocateByWeights(7, [1, 1, 1]), [3, 2, 2]);
    });

    test('returns all-zero for non-positive total weight', () {
      expect(SplitMath.allocateByWeights(1000, [0, 0]), [0, 0]);
    });

    test('empty weights yield empty', () {
      expect(SplitMath.allocateByWeights(1000, const []), isEmpty);
    });

    test('weighted shares always reconcile, even for awkward totals', () {
      for (final total in [0, 1, 7, 99, 100, 101, 1000, 1234, 99999]) {
        for (final weights in [
          [1],
          [1, 1],
          [1, 2],
          [2, 3, 5],
          [1, 1, 1, 1, 1, 1, 1],
          [5, 1, 1],
        ]) {
          final parts = SplitMath.allocateByWeights(total, weights);
          expect(parts.length, weights.length);
          expect(_sum(parts), total, reason: 'total=$total weights=$weights');
          expect(parts.every((p) => p >= 0), isTrue);
        }
      }
    });
  });

  group('byShares', () {
    test('non-divisible total reconciles exactly', () {
      final parts = SplitMath.byShares(1000, [1, 1, 1]);
      expect(_sum(parts), 1000);
      expect(parts, [334, 333, 333]);
    });

    test('weights of different sizes split proportionally', () {
      final parts = SplitMath.byShares(600, [1, 2, 3]);
      expect(_sum(parts), 600);
      expect(parts, [100, 200, 300]);
    });
  });

  group('byPercentages (basis points, 10000 == 100%)', () {
    test('even thirds reconcile to the cent', () {
      // 33.33% / 33.33% / 33.34% of €10.00.
      final parts = SplitMath.byPercentages(1000, [3333, 3333, 3334]);
      expect(_sum(parts), 1000);
    });

    test('50/50 of an odd total gives the leftover cent to the first', () {
      final parts = SplitMath.byPercentages(101, [5000, 5000]);
      expect(_sum(parts), 101);
      expect(parts, [51, 50]);
    });

    test('uneven percentages reconcile exactly', () {
      final parts = SplitMath.byPercentages(1000, [
        1000,
        2000,
        7000,
      ]); // 10/20/70
      expect(_sum(parts), 1000);
      expect(parts, [100, 200, 700]);
    });
  });

  group('equal', () {
    test('matches the leftover-from-the-top rule', () {
      expect(SplitMath.equal(1000, 3), [334, 333, 333]);
      expect(_sum(SplitMath.equal(9999, 7)), 9999);
    });
  });
}
