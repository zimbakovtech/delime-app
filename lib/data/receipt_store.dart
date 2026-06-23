/// Persists receipt image files on the device. Kept behind an interface so
/// [AppState] stays free of `dart:io` / plugin dependencies and remains unit
/// testable. The concrete [FileReceiptStore] copies picked images into the app
/// documents directory; nothing ever leaves the device.
abstract class ReceiptStore {
  /// Copies the image at [sourcePath] into persistent app storage and returns
  /// the new on-device path.
  Future<String> import(String sourcePath);

  /// Removes a previously [import]ed file. Missing files are ignored.
  Future<void> delete(String path);
}
