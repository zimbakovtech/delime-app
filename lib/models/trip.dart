import 'package:flutter/foundation.dart';

/// The kind of shared ledger a trip represents. Drives the icon shown in the
/// trips list. Stored by [name].
enum TripType { vacation, household, couple, event, other }

/// Whether a trip is current or tucked away. Archived trips stay fully intact
/// and migratable; they're just hidden from the active list.
enum TripStatus { active, archived }

extension TripTypeX on TripType {
  /// The value persisted in SQLite.
  String get storageValue => name;

  static TripType fromStorage(String? value) => TripType.values.firstWhere(
    (t) => t.name == value,
    orElse: () => TripType.other,
  );
}

extension TripStatusX on TripStatus {
  String get storageValue => name;

  static TripStatus fromStorage(String? value) => TripStatus.values.firstWhere(
    (s) => s.name == value,
    orElse: () => TripStatus.active,
  );
}

/// A first-class trip: the unit that owns people, purchases and settlements.
/// All amounts within a trip are in the trip's [baseCurrency] (EUR for now).
@immutable
class Trip {
  final String id;
  final String name;
  final TripType type;

  /// ISO currency code. Single-currency (always `EUR`) until a later phase.
  final String baseCurrency;

  /// Optional trip date range, epoch millis.
  final int? startDate;
  final int? endDate;

  /// ARGB cover colour, drawn from the avatar palette.
  final int coverColor;

  /// Optional local path to a cover photo on the device.
  final String? coverPhotoPath;

  final TripStatus status;
  final int createdAt; // epoch millis
  final int updatedAt; // epoch millis

  const Trip({
    required this.id,
    required this.name,
    required this.type,
    this.baseCurrency = 'EUR',
    this.startDate,
    this.endDate,
    required this.coverColor,
    this.coverPhotoPath,
    this.status = TripStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isArchived => status == TripStatus.archived;

  Trip copyWith({
    String? name,
    TripType? type,
    String? baseCurrency,
    int? startDate,
    bool clearStartDate = false,
    int? endDate,
    bool clearEndDate = false,
    int? coverColor,
    String? coverPhotoPath,
    bool clearCoverPhoto = false,
    TripStatus? status,
    int? updatedAt,
  }) => Trip(
    id: id,
    name: name ?? this.name,
    type: type ?? this.type,
    baseCurrency: baseCurrency ?? this.baseCurrency,
    startDate: clearStartDate ? null : (startDate ?? this.startDate),
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    coverColor: coverColor ?? this.coverColor,
    coverPhotoPath: clearCoverPhoto
        ? null
        : (coverPhotoPath ?? this.coverPhotoPath),
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'type': type.storageValue,
    'base_currency': baseCurrency,
    'start_date': startDate,
    'end_date': endDate,
    'cover_color': coverColor,
    'cover_photo_path': coverPhotoPath,
    'status': status.storageValue,
    'created_at': createdAt,
    'updated_at': updatedAt,
  };

  factory Trip.fromMap(Map<String, Object?> map) => Trip(
    id: map['id'] as String,
    name: map['name'] as String,
    type: TripTypeX.fromStorage(map['type'] as String?),
    baseCurrency: (map['base_currency'] as String?) ?? 'EUR',
    startDate: map['start_date'] as int?,
    endDate: map['end_date'] as int?,
    coverColor: map['cover_color'] as int,
    coverPhotoPath: map['cover_photo_path'] as String?,
    status: TripStatusX.fromStorage(map['status'] as String?),
    createdAt: map['created_at'] as int,
    updatedAt: map['updated_at'] as int,
  );

  @override
  bool operator ==(Object other) => other is Trip && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
