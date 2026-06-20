import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// The little rounded handle shown at the top of modal bottom sheets.
class SheetGrabber extends StatelessWidget {
  const SheetGrabber({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        decoration: BoxDecoration(
          color: AppTheme.outline,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
