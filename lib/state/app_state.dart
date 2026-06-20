import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

import '../data/app_repository.dart';
import '../models/balance.dart';
import '../models/person.dart';
import '../models/purchase.dart';
import '../services/settlement_service.dart';
import '../theme/avatar_palette.dart';

/// Raised when an operation can't be completed for a user-facing reason
/// (e.g. deleting a person who is part of a purchase).
class AppStateException implements Exception {
  final String message;
  AppStateException(this.message);
  @override
  String toString() => message;
}

/// Central app state. Loads everything from the repository on startup and
/// keeps in-memory lists in sync, recomputing balances/settlements on demand.
class AppState extends ChangeNotifier {
  AppState(this._repo);

  final AppRepository _repo;
  static const _uuid = Uuid();

  List<Person> _people = [];
  List<Purchase> _purchases = [];
  bool _loading = true;

  List<Person> get people => List.unmodifiable(_people);
  List<Purchase> get purchases => List.unmodifiable(_purchases);
  bool get loading => _loading;

  Person? personById(String id) {
    for (final p in _people) {
      if (p.id == id) return p;
    }
    return null;
  }

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    _people = await _repo.getPeople();
    _purchases = await _repo.getPurchases();
    _loading = false;
    notifyListeners();
  }

  // ---- People ----------------------------------------------------------

  Future<void> addPerson(String name) async {
    final used = _people.map((p) => p.colorValue).toList();
    final person = Person(
      id: _uuid.v4(),
      name: name.trim(),
      colorValue: AvatarPalette.suggestColorValue(used),
    );
    await _repo.insertPerson(person);
    _people = await _repo.getPeople();
    notifyListeners();
  }

  Future<void> updatePerson(Person person) async {
    await _repo.updatePerson(person);
    _people = await _repo.getPeople();
    notifyListeners();
  }

  Future<void> deletePerson(String id) async {
    final usage = await _repo.personUsageCount(id);
    if (usage > 0) {
      final person = personById(id);
      final name = person?.name ?? 'This person';
      throw AppStateException(
        '$name appears in $usage purchase${usage == 1 ? '' : 's'}. '
        'Remove them from those purchases first, then delete.',
      );
    }
    await _repo.deletePerson(id);
    _people = await _repo.getPeople();
    notifyListeners();
  }

  // ---- Purchases -------------------------------------------------------

  String newPurchaseId() => _uuid.v4();

  Future<void> savePurchase(Purchase purchase) async {
    await _repo.savePurchase(purchase);
    _purchases = await _repo.getPurchases();
    notifyListeners();
  }

  Future<void> deletePurchase(String id) async {
    await _repo.deletePurchase(id);
    _purchases = await _repo.getPurchases();
    notifyListeners();
  }

  // ---- Derived ---------------------------------------------------------

  List<Balance> get balances =>
      SettlementService.computeBalances(_people, _purchases);

  List<Settlement> get settlements =>
      SettlementService.computeSettlements(balances);
}
