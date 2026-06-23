import 'dart:io';

import 'package:delime/models/attachment.dart';
import 'package:delime/theme/app_theme.dart';
import 'package:flutter/material.dart';

/// A small rounded receipt-photo thumbnail with a remove badge. Tapping the
/// image views it full-screen; tapping the badge removes it.
class ReceiptThumbnail extends StatelessWidget {
  final Attachment attachment;
  final VoidCallback onRemove;
  final VoidCallback onView;
  final double size;

  const ReceiptThumbnail({
    super.key,
    required this.attachment,
    required this.onRemove,
    required this.onView,
    this.size = 76,
  });

  @override
  Widget build(BuildContext context) {
    final file = File(attachment.filePath);
    return SizedBox(
      width: size + 8,
      height: size + 8,
      child: Stack(
        children: [
          Positioned(
            top: 4,
            left: 0,
            child: GestureDetector(
              onTap: onView,
              child: Container(
                width: size,
                height: size,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  color: AppTheme.surfaceHigh,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppTheme.outline),
                ),
                child: file.existsSync()
                    ? Image.file(file, fit: BoxFit.cover)
                    : const Icon(
                        Icons.broken_image_outlined,
                        color: AppTheme.textSecondary,
                      ),
              ),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            child: GestureDetector(
              onTap: onRemove,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppTheme.negative,
                ),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
