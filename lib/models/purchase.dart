import 'package:flutter/foundation.dart';

/// A single person's contribution to a purchase — either money they *paid*
/// or the share of the cost they *owe*. Amount is in EUR cents.
@immutable
class Contribution {
  final String personId;
  final int amountCents;

  const Contribution({required this.personId, required this.amountCents});

  Contribution copyWith({String? personId, int? amountCents}) => Contribution(
    personId: personId ?? this.personId,
    amountCents: amountCents ?? this.amountCents,
  );
}

/// A named expense. The [totalCents] must equal both the sum of [payers]
/// amounts and the sum of [splits] amounts (validated before saving).
@immutable
class Purchase {
  final String id;
  final String name;
  final int totalCents;
  final int createdAt; // epoch millis

  /// Expense category — a built-in label (see `utils/categories.dart`) or a
  /// custom free-text string. Defaults to `Other`.
  final String category;

  /// Who handed over the money, and how much each paid.
  final List<Contribution> payers;

  /// Who the cost is divided among, and each person's share.
  final List<Contribution> splits;

  const Purchase({
    required this.id,
    required this.name,
    required this.totalCents,
    required this.createdAt,
    this.category = 'Other',
    required this.payers,
    required this.splits,
  });

  int get payersTotal => payers.fold(0, (sum, c) => sum + c.amountCents);

  int get splitsTotal => splits.fold(0, (sum, c) => sum + c.amountCents);

  Purchase copyWith({
    String? name,
    int? totalCents,
    String? category,
    List<Contribution>? payers,
    List<Contribution>? splits,
  }) => Purchase(
    id: id,
    name: name ?? this.name,
    totalCents: totalCents ?? this.totalCents,
    createdAt: createdAt,
    category: category ?? this.category,
    payers: payers ?? this.payers,
    splits: splits ?? this.splits,
  );

  Map<String, Object?> toMap() => {
    'id': id,
    'name': name,
    'total': totalCents,
    'created_at': createdAt,
    'category': category,
  };

  factory Purchase.fromMap(
    Map<String, Object?> map, {
    required List<Contribution> payers,
    required List<Contribution> splits,
  }) => Purchase(
    id: map['id'] as String,
    name: map['name'] as String,
    totalCents: map['total'] as int,
    createdAt: map['created_at'] as int,
    category: (map['category'] as String?) ?? 'Other',
    payers: payers,
    splits: splits,
  );
}
