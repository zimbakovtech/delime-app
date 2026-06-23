import 'dart:io';

import 'package:delime/data/receipt_store.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';

/// Stores receipt images under the app documents directory (`receipts/`).
/// Files never leave the device.
class FileReceiptStore implements ReceiptStore {
  static const _uuid = Uuid();

  Future<Directory> _receiptsDir() async {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'receipts'));
    if (!dir.existsSync()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<String> import(String sourcePath) async {
    final dir = await _receiptsDir();
    final dest = p.join(dir.path, '${_uuid.v4()}${p.extension(sourcePath)}');
    await File(sourcePath).copy(dest);
    return dest;
  }

  @override
  Future<void> delete(String path) async {
    final file = File(path);
    if (file.existsSync()) await file.delete();
  }
}
