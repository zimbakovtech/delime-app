import 'package:delime/data/app_repository.dart';
import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';

/// In-memory [AppRepository] stand-in for state/widget tests. Mirrors the
/// observable behaviour of the real repository (sort order, usage counting,
/// upsert-on-save) without touching SQLite.
class FakeRepository implements AppRepository {
  final List<Person> _people = [];
  final List<Purchase> _purchases = [];

  @override
  Future<List<Person>> getPeople() async {
    final sorted = [..._people]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return sorted;
  }

  @override
  Future<void> insertPerson(Person person) async => _people.add(person);

  @override
  Future<void> updatePerson(Person person) async {
    final i = _people.indexWhere((e) => e.id == person.id);
    if (i >= 0) _people[i] = person;
  }

  @override
  Future<void> deletePerson(String id) async =>
      _people.removeWhere((e) => e.id == id);

  @override
  Future<int> personUsageCount(String personId) async {
    final ids = <String>{};
    for (final purchase in _purchases) {
      final used =
          purchase.payers.any((c) => c.personId == personId) ||
          purchase.splits.any((c) => c.personId == personId);
      if (used) ids.add(purchase.id);
    }
    return ids.length;
  }

  @override
  Future<List<Purchase>> getPurchases() async {
    final sorted = [..._purchases]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  @override
  Future<void> savePurchase(Purchase purchase) async {
    final i = _purchases.indexWhere((e) => e.id == purchase.id);
    if (i >= 0) {
      _purchases[i] = purchase;
    } else {
      _purchases.add(purchase);
    }
  }

  @override
  Future<void> deletePurchase(String id) async =>
      _purchases.removeWhere((e) => e.id == id);
}
