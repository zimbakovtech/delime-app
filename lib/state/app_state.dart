import 'package:delime/data/app_repository.dart';
import 'package:delime/data/receipt_store.dart';
import 'package:delime/models/attachment.dart';
import 'package:delime/models/balance.dart';
import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';
import 'package:delime/models/settlement_record.dart';
import 'package:delime/models/trip.dart';
import 'package:delime/services/settlement_service.dart';
import 'package:delime/theme/avatar_palette.dart';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';

/// Raised when an operation can't be completed for a user-facing reason
/// (e.g. deleting a person who is part of a purchase).
class AppStateException implements Exception {
  final String message;
  AppStateException(this.message);
  @override
  String toString() => message;
}

/// Lightweight per-trip rollup shown on the trips list (no need to open a trip).
@immutable
class TripSummary {
  final int memberCount;
  final int totalSpentCents;

  /// Amount still to be settled across the trip (sum of creditor nets).
  final int outstandingCents;

  const TripSummary({
    required this.memberCount,
    required this.totalSpentCents,
    required this.outstandingCents,
  });

  static const empty = TripSummary(
    memberCount: 0,
    totalSpentCents: 0,
    outstandingCents: 0,
  );
}

/// Central app state. Loads trips on startup; opening a trip scopes all people,
/// purchases, settlements and attachments to it.
class AppState extends ChangeNotifier {
  AppState(this._repo, {ReceiptStore? receipts}) : _receipts = receipts;

  final AppRepository _repo;
  final ReceiptStore? _receipts;
  static const _uuid = Uuid();

  List<Trip> _trips = [];
  final Map<String, TripSummary> _summaries = {};
  String? _currentTripId;

  List<Person> _people = [];
  List<Purchase> _purchases = [];
  List<SettlementRecord> _settlements = [];
  List<Attachment> _attachments = [];

  bool _loading = true;
  bool _simplifyDebts = true;

  // ---- Getters ---------------------------------------------------------

  bool get loading => _loading;
  bool get receiptsEnabled => _receipts != null;

  List<Trip> get trips => List.unmodifiable(_trips);
  List<Trip> get activeTrips =>
      _trips.where((t) => !t.isArchived).toList(growable: false);
  List<Trip> get archivedTrips =>
      _trips.where((t) => t.isArchived).toList(growable: false);

  TripSummary summaryFor(String tripId) =>
      _summaries[tripId] ?? TripSummary.empty;

  Trip? get currentTrip {
    for (final t in _trips) {
      if (t.id == _currentTripId) return t;
    }
    return null;
  }

  List<Person> get people => List.unmodifiable(_people);
  List<Purchase> get purchases => List.unmodifiable(_purchases);
  List<SettlementRecord> get settlementHistory =>
      List.unmodifiable(_settlements);

  bool get simplifyDebts => _simplifyDebts;
  set simplifyDebts(bool value) {
    if (_simplifyDebts == value) return;
    _simplifyDebts = value;
    notifyListeners();
  }

  Person? personById(String id) {
    for (final p in _people) {
      if (p.id == id) return p;
    }
    return null;
  }

  List<Attachment> attachmentsFor(String purchaseId) =>
      _attachments.where((a) => a.purchaseId == purchaseId).toList();

  // ---- Derived ---------------------------------------------------------

  List<Balance> get balances => SettlementService.computeBalances(
    _people,
    _purchases,
    settlements: _settlements,
  );

  List<Settlement> get settlements => _simplifyDebts
      ? SettlementService.computeSettlements(balances)
      : SettlementService.computeDirectSettlements(
          _people,
          _purchases,
          settlements: _settlements,
        );

  // ---- Loading & trip selection ---------------------------------------

  Future<void> load() async {
    _loading = true;
    notifyListeners();
    await _reloadTrips();
    _loading = false;
    notifyListeners();
  }

  Future<void> selectTrip(String tripId) async {
    _currentTripId = tripId;
    await _reloadScoped();
    notifyListeners();
  }

  /// Returns to the trips list, dropping the per-trip working set.
  void closeTrip() {
    _currentTripId = null;
    _people = [];
    _purchases = [];
    _settlements = [];
    _attachments = [];
    notifyListeners();
  }

  Future<void> _reloadTrips() async {
    _trips = await _repo.getTrips();
    _summaries.clear();
    for (final t in _trips) {
      await _refreshSummary(t.id);
    }
  }

  Future<void> _refreshSummary(String tripId) async {
    final people = await _repo.getPeople(tripId);
    final purchases = await _repo.getPurchases(tripId);
    final settlements = await _repo.getSettlements(tripId);
    final balances = SettlementService.computeBalances(
      people,
      purchases,
      settlements: settlements,
    );
    final outstanding = balances
        .where((b) => b.netCents > 0)
        .fold<int>(0, (sum, b) => sum + b.netCents);
    _summaries[tripId] = TripSummary(
      memberCount: people.length,
      totalSpentCents: purchases.fold<int>(0, (sum, p) => sum + p.totalCents),
      outstandingCents: outstanding,
    );
  }

  Future<void> _reloadScoped() async {
    final id = _currentTripId;
    if (id == null) {
      _people = [];
      _purchases = [];
      _settlements = [];
      _attachments = [];
      return;
    }
    _people = await _repo.getPeople(id);
    _purchases = await _repo.getPurchases(id);
    _settlements = await _repo.getSettlements(id);
    _attachments = await _repo.getAttachments(id);
  }

  String _requireTripId() {
    final id = _currentTripId;
    if (id == null) throw AppStateException('No trip is open.');
    return id;
  }

  // ---- Trips -----------------------------------------------------------

  Future<Trip> addTrip({
    required String name,
    required TripType type,
    required int coverColor,
    int? startDate,
    int? endDate,
    String? coverPhotoPath,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final trip = Trip(
      id: _uuid.v4(),
      name: name.trim(),
      type: type,
      coverColor: coverColor,
      startDate: startDate,
      endDate: endDate,
      coverPhotoPath: coverPhotoPath,
      createdAt: now,
      updatedAt: now,
    );
    await _repo.insertTrip(trip);
    await _reloadTrips();
    notifyListeners();
    return trip;
  }

  Future<void> saveTripEdits(Trip trip) async {
    final updated = trip.copyWith(
      updatedAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repo.updateTrip(updated);
    await _reloadTrips();
    notifyListeners();
  }

  Future<void> setTripStatus(Trip trip, TripStatus status) =>
      saveTripEdits(trip.copyWith(status: status));

  Future<void> deleteTrip(String tripId) async {
    final receipts = _receipts;
    if (receipts != null) {
      final attachments = await _repo.getAttachments(tripId);
      for (final a in attachments) {
        await receipts.delete(a.filePath);
      }
    }
    await _repo.deleteTrip(tripId);
    if (_currentTripId == tripId) closeTrip();
    await _reloadTrips();
    notifyListeners();
  }

  // ---- People ----------------------------------------------------------

  Future<void> addPerson(String name) async {
    final tripId = _requireTripId();
    final used = _people.map((p) => p.colorValue).toList();
    final person = Person(
      id: _uuid.v4(),
      name: name.trim(),
      colorValue: AvatarPalette.suggestColorValue(used),
    );
    await _repo.insertPerson(person, tripId);
    _people = await _repo.getPeople(tripId);
    await _refreshSummary(tripId);
    notifyListeners();
  }

  Future<void> updatePerson(Person person) async {
    final tripId = _requireTripId();
    await _repo.updatePerson(person);
    _people = await _repo.getPeople(tripId);
    notifyListeners();
  }

  Future<void> deletePerson(String id) async {
    final tripId = _requireTripId();
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
    _people = await _repo.getPeople(tripId);
    await _refreshSummary(tripId);
    notifyListeners();
  }

  // ---- Purchases -------------------------------------------------------

  String newPurchaseId() => _uuid.v4();

  Future<void> savePurchase(Purchase purchase) async {
    final tripId = _requireTripId();
    await _repo.savePurchase(purchase, tripId);
    _purchases = await _repo.getPurchases(tripId);
    await _refreshSummary(tripId);
    notifyListeners();
  }

  Future<void> deletePurchase(String id) async {
    final tripId = _requireTripId();
    final receipts = _receipts;
    if (receipts != null) {
      final attachments = await _repo.getAttachmentsForPurchase(id);
      for (final a in attachments) {
        await receipts.delete(a.filePath);
      }
    }
    await _repo.deletePurchase(id);
    _purchases = await _repo.getPurchases(tripId);
    _attachments = await _repo.getAttachments(tripId);
    await _refreshSummary(tripId);
    notifyListeners();
  }

  // ---- Settlements -----------------------------------------------------

  Future<void> recordSettlement({
    required String fromPersonId,
    required String toPersonId,
    required int amountCents,
    String? note,
  }) async {
    final tripId = _requireTripId();
    final record = SettlementRecord(
      id: _uuid.v4(),
      tripId: tripId,
      fromPersonId: fromPersonId,
      toPersonId: toPersonId,
      amountCents: amountCents,
      note: note,
      settledAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repo.insertSettlement(record);
    _settlements = await _repo.getSettlements(tripId);
    await _refreshSummary(tripId);
    notifyListeners();
  }

  /// Records a suggested payment as settled.
  Future<void> markSettled(Settlement settlement, {String? note}) =>
      recordSettlement(
        fromPersonId: settlement.fromPersonId,
        toPersonId: settlement.toPersonId,
        amountCents: settlement.amountCents,
        note: note,
      );

  Future<void> deleteSettlement(String id) async {
    final tripId = _requireTripId();
    await _repo.deleteSettlement(id);
    _settlements = await _repo.getSettlements(tripId);
    await _refreshSummary(tripId);
    notifyListeners();
  }

  // ---- Attachments -----------------------------------------------------

  Future<void> addReceipt(String purchaseId, String sourcePath) async {
    final tripId = _requireTripId();
    final receipts = _receipts;
    if (receipts == null) {
      throw AppStateException('Receipts are unavailable on this device.');
    }
    final stored = await receipts.import(sourcePath);
    final attachment = Attachment(
      id: _uuid.v4(),
      purchaseId: purchaseId,
      filePath: stored,
      createdAt: DateTime.now().millisecondsSinceEpoch,
    );
    await _repo.insertAttachment(attachment);
    _attachments = await _repo.getAttachments(tripId);
    notifyListeners();
  }

  Future<void> removeReceipt(Attachment attachment) async {
    final tripId = _requireTripId();
    final receipts = _receipts;
    if (receipts != null) await receipts.delete(attachment.filePath);
    await _repo.deleteAttachment(attachment.id);
    _attachments = await _repo.getAttachments(tripId);
    notifyListeners();
  }
}
