import 'package:delime/data/receipt_store.dart';

/// In-memory [ReceiptStore] for tests. Records imports/deletes and returns a
/// deterministic "stored" path without touching the filesystem.
class FakeReceiptStore implements ReceiptStore {
  final List<String> imported = [];
  final List<String> deleted = [];

  @override
  Future<String> import(String sourcePath) async {
    imported.add(sourcePath);
    return '/receipts/${imported.length}_${sourcePath.split('/').last}';
  }

  @override
  Future<void> delete(String path) async => deleted.add(path);
}
