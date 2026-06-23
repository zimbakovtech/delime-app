import 'package:delime/utils/money.dart';

/// How a purchase total is divided among people.
enum SplitMode { equal, exactAmounts, percentages, shares }

/// Pure split-strategy math. Every strategy reconciles **exactly** to the total
/// by distributing leftover minor units with the largest-remainder rule, so the
/// per-person shares always sum back to [totalCents]. No floating point is used
/// for the stored result.
///
/// Named `SplitMath` (not `Split`) to avoid colliding with Flutter's `Split`
/// animation curve.
class SplitMath {
  /// Distributes [totalCents] across [weights] in proportion to each weight.
  /// Leftover minor units go to the entries with the largest fractional
  /// remainder (ties broken by lower index), so the parts sum exactly to the
  /// total. Returns all-zero when the total weight is not positive.
  ///
  /// This is the shared engine behind [byShares] and [byPercentages]; with all
  /// weights equal it reproduces [Money.splitEqually].
  static List<int> allocateByWeights(int totalCents, List<int> weights) {
    final n = weights.length;
    if (n == 0) return const [];
    final totalWeight = weights.fold<int>(0, (a, b) => a + b);
    if (totalWeight <= 0) return List<int>.filled(n, 0);

    final base = List<int>.filled(n, 0);
    final remainders = List<int>.filled(n, 0);
    var allocated = 0;
    for (var i = 0; i < n; i++) {
      final numerator = totalCents * weights[i];
      base[i] = numerator ~/ totalWeight;
      remainders[i] = numerator % totalWeight;
      allocated += base[i];
    }

    // Leftover is an integer in [0, n-1] for non-negative inputs.
    final leftover = totalCents - allocated;
    final order = List<int>.generate(n, (i) => i)
      ..sort((a, b) {
        final byRemainder = remainders[b].compareTo(remainders[a]);
        return byRemainder != 0 ? byRemainder : a.compareTo(b);
      });
    for (var k = 0; k < leftover && k < n; k++) {
      base[order[k]] += 1;
    }
    return base;
  }

  /// Equal split across [count] people (leftover unit one-per-person).
  static List<int> equal(int totalCents, int count) =>
      Money.splitEqually(totalCents, count);

  /// Split by integer [shares] (weights). Parts sum exactly to [totalCents].
  static List<int> byShares(int totalCents, List<int> shares) =>
      allocateByWeights(totalCents, shares);

  /// Split by [percentBasisPoints] — hundredths of a percent, so `10000` is
  /// 100%. Parts sum exactly to [totalCents]. (Basis points keep the input
  /// integer, e.g. 33.33% → 3333, preserving the no-floating-point rule.)
  static List<int> byPercentages(
    int totalCents,
    List<int> percentBasisPoints,
  ) => allocateByWeights(totalCents, percentBasisPoints);
}
