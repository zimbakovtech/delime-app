import 'package:intl/intl.dart';

/// All monetary values in the app are stored internally as **integer EUR cents**
/// to avoid floating-point rounding errors. EUR is the canonical currency.
///
/// MKD (Macedonian denar) is supported only as an *input/display* currency,
/// converted at a fixed rate.
class Money {
  /// Fixed conversion rate: 1 EUR = 61.5 MKD. Never changes.
  static const double mkdPerEur = 61.5;

  static final NumberFormat _eurFmt = NumberFormat('#,##0.00', 'en_US');
  static final NumberFormat _mkdFmt = NumberFormat('#,##0.00', 'en_US');

  /// Converts a EUR amount (as a double, e.g. user input "12.34") to cents.
  static int eurToCents(double eur) => (eur * 100).round();

  /// Converts an MKD amount (as a double) to EUR cents using the fixed rate.
  static int mkdToCents(double mkd) => (mkd / mkdPerEur * 100).round();

  static double centsToEur(int cents) => cents / 100.0;

  /// EUR cents -> MKD value (double).
  static double centsToMkd(int cents) => centsToEur(cents) * mkdPerEur;

  /// "€12.34"
  static String formatEur(int cents) => '€${_eurFmt.format(centsToEur(cents))}';

  /// "759.15 ден"
  static String formatMkd(int cents) =>
      '${_mkdFmt.format(centsToMkd(cents))} ден';

  /// Both currencies: "€12.34 · 759.15 ден"
  static String formatBoth(int cents) =>
      '${formatEur(cents)} · ${formatMkd(cents)}';

  /// Splits [totalCents] equally among [count] people, distributing any
  /// leftover cent so the parts always sum exactly to [totalCents].
  ///
  /// e.g. 1000 / 3 -> [334, 333, 333].
  static List<int> splitEqually(int totalCents, int count) {
    if (count <= 0) return const [];
    final base = totalCents ~/ count;
    final remainder = totalCents % count;
    return List<int>.generate(
      count,
      (i) => base + (i < remainder ? 1 : 0),
    );
  }
}

/// Currencies the user can pick from when entering an amount.
enum InputCurrency { eur, mkd }

extension InputCurrencyX on InputCurrency {
  String get label => this == InputCurrency.eur ? 'EUR' : 'MKD';
  String get symbol => this == InputCurrency.eur ? '€' : 'ден';
}
