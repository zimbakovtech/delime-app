import 'package:flutter/foundation.dart';

/// A confirmed payment recorded between two people in a trip. Amount in EUR
/// cents. Recorded settlements are subtracted from outstanding balances.
@immutable
class SettlementRecord {
  final String id;
  final String tripId;
  final String fromPersonId;
  final String toPersonId;
  final int amountCents;
  final String? note;
  final int settledAt; // epoch millis

  const SettlementRecord({
    required this.id,
    required this.tripId,
    required this.fromPersonId,
    required this.toPersonId,
    required this.amountCents,
    this.note,
    required this.settledAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'trip_id': tripId,
    'from_person': fromPersonId,
    'to_person': toPersonId,
    'amount': amountCents,
    'note': note,
    'settled_at': settledAt,
  };

  factory SettlementRecord.fromMap(Map<String, Object?> map) =>
      SettlementRecord(
        id: map['id'] as String,
        tripId: map['trip_id'] as String,
        fromPersonId: map['from_person'] as String,
        toPersonId: map['to_person'] as String,
        amountCents: map['amount'] as int,
        note: map['note'] as String?,
        settledAt: map['settled_at'] as int,
      );
}
