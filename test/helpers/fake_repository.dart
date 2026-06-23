import 'package:delime/data/app_repository.dart';
import 'package:delime/models/attachment.dart';
import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';
import 'package:delime/models/settlement_record.dart';
import 'package:delime/models/trip.dart';

/// In-memory [AppRepository] stand-in for state/widget tests. Mirrors the
/// observable behaviour of the real repository (trip scoping, sort order,
/// usage counting, upsert-on-save, cascade-on-delete) without touching SQLite.
class FakeRepository implements AppRepository {
  final List<Trip> _trips = [];
  final Map<String, List<Person>> _people = {}; // tripId -> people
  final Map<String, List<Purchase>> _purchases = {}; // tripId -> purchases
  final List<SettlementRecord> _settlements = [];
  final List<Attachment> _attachments = [];

  // ---- Trips -----------------------------------------------------------

  @override
  Future<List<Trip>> getTrips() async =>
      [..._trips]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  @override
  Future<void> insertTrip(Trip trip) async => _trips.add(trip);

  @override
  Future<void> updateTrip(Trip trip) async {
    final i = _trips.indexWhere((e) => e.id == trip.id);
    if (i >= 0) _trips[i] = trip;
  }

  @override
  Future<void> deleteTrip(String id) async {
    _trips.removeWhere((e) => e.id == id);
    final purchaseIds = (_purchases.remove(id) ?? []).map((p) => p.id).toSet();
    _people.remove(id);
    _settlements.removeWhere((s) => s.tripId == id);
    _attachments.removeWhere((a) => purchaseIds.contains(a.purchaseId));
  }

  // ---- People ----------------------------------------------------------

  @override
  Future<List<Person>> getPeople(String tripId) async {
    return [...?_people[tripId]]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  @override
  Future<void> insertPerson(Person person, String tripId) async =>
      (_people[tripId] ??= []).add(person);

  @override
  Future<void> updatePerson(Person person) async {
    for (final list in _people.values) {
      final i = list.indexWhere((e) => e.id == person.id);
      if (i >= 0) {
        list[i] = person;
        return;
      }
    }
  }

  @override
  Future<void> deletePerson(String id) async {
    for (final list in _people.values) {
      list.removeWhere((e) => e.id == id);
    }
  }

  @override
  Future<int> personUsageCount(String personId) async {
    final ids = <String>{};
    for (final purchases in _purchases.values) {
      for (final purchase in purchases) {
        final used =
            purchase.payers.any((c) => c.personId == personId) ||
            purchase.splits.any((c) => c.personId == personId);
        if (used) ids.add(purchase.id);
      }
    }
    return ids.length;
  }

  // ---- Purchases -------------------------------------------------------

  @override
  Future<List<Purchase>> getPurchases(String tripId) async {
    return [...?_purchases[tripId]]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  @override
  Future<void> savePurchase(Purchase purchase, String tripId) async {
    final list = _purchases[tripId] ??= [];
    final i = list.indexWhere((e) => e.id == purchase.id);
    if (i >= 0) {
      list[i] = purchase;
    } else {
      list.add(purchase);
    }
  }

  @override
  Future<void> deletePurchase(String id) async {
    for (final list in _purchases.values) {
      list.removeWhere((e) => e.id == id);
    }
    _attachments.removeWhere((a) => a.purchaseId == id);
  }

  // ---- Settlements -----------------------------------------------------

  @override
  Future<List<SettlementRecord>> getSettlements(String tripId) async {
    return _settlements.where((s) => s.tripId == tripId).toList()
      ..sort((a, b) => b.settledAt.compareTo(a.settledAt));
  }

  @override
  Future<void> insertSettlement(SettlementRecord record) async =>
      _settlements.add(record);

  @override
  Future<void> deleteSettlement(String id) async =>
      _settlements.removeWhere((s) => s.id == id);

  // ---- Attachments -----------------------------------------------------

  @override
  Future<List<Attachment>> getAttachments(String tripId) async {
    final purchaseIds = (_purchases[tripId] ?? []).map((p) => p.id).toSet();
    return _attachments
        .where((a) => purchaseIds.contains(a.purchaseId))
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<List<Attachment>> getAttachmentsForPurchase(String purchaseId) async {
    return _attachments.where((a) => a.purchaseId == purchaseId).toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
  }

  @override
  Future<void> insertAttachment(Attachment attachment) async =>
      _attachments.add(attachment);

  @override
  Future<void> deleteAttachment(String id) async =>
      _attachments.removeWhere((a) => a.id == id);
}
