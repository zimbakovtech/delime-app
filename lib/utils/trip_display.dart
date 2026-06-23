import 'package:delime/models/trip.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// Display helpers for trips: a label and icon per [TripType], and a friendly
/// rendering of the optional date range.
extension TripTypeDisplay on TripType {
  String get label => switch (this) {
    TripType.vacation => 'Vacation',
    TripType.household => 'Household',
    TripType.couple => 'Couple',
    TripType.event => 'Event',
    TripType.other => 'Other',
  };

  IconData get icon => switch (this) {
    TripType.vacation => Icons.beach_access,
    TripType.household => Icons.home_outlined,
    TripType.couple => Icons.favorite_outline,
    TripType.event => Icons.celebration_outlined,
    TripType.other => Icons.luggage_outlined,
  };
}

/// A compact date-range string, or null when no dates are set.
String? formatTripDates(int? startMillis, int? endMillis) {
  final start = startMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(startMillis);
  final end = endMillis == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(endMillis);
  if (start == null && end == null) return null;

  final dayMonth = DateFormat('d MMM');
  final dayMonthYear = DateFormat('d MMM yyyy');
  if (start != null && end != null) {
    final sameYear = start.year == end.year;
    final left = sameYear ? dayMonth.format(start) : dayMonthYear.format(start);
    return '$left – ${dayMonthYear.format(end)}';
  }
  return dayMonthYear.format((start ?? end)!);
}
