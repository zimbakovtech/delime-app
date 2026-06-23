import 'package:flutter/foundation.dart';

/// A local receipt photo attached to a purchase. The image lives on device
/// storage; only its [filePath] is persisted. Nothing leaves the device.
@immutable
class Attachment {
  final String id;
  final String purchaseId;
  final String filePath;
  final int createdAt; // epoch millis

  const Attachment({
    required this.id,
    required this.purchaseId,
    required this.filePath,
    required this.createdAt,
  });

  Map<String, Object?> toMap() => {
    'id': id,
    'purchase_id': purchaseId,
    'file_path': filePath,
    'created_at': createdAt,
  };

  factory Attachment.fromMap(Map<String, Object?> map) => Attachment(
    id: map['id'] as String,
    purchaseId: map['purchase_id'] as String,
    filePath: map['file_path'] as String,
    createdAt: map['created_at'] as int,
  );
}
