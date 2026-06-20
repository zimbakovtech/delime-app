import 'package:flutter/material.dart';

/// A curated set of vivid, legible avatar colours. New people are assigned the
/// least-used colour so a small group gets distinct colours automatically.
class AvatarPalette {
  static const List<Color> colors = [
    Color(0xFF34D399), // emerald
    Color(0xFF60A5FA), // blue
    Color(0xFFF472B6), // pink
    Color(0xFFFBBF24), // amber
    Color(0xFFA78BFA), // violet
    Color(0xFF22D3EE), // cyan
    Color(0xFFFB7185), // rose
    Color(0xFF4ADE80), // green
    Color(0xFFF59E0B), // orange
    Color(0xFF818CF8), // indigo
  ];

  /// Picks the colour used by the fewest existing people.
  static int suggestColorValue(List<int> usedColorValues) {
    final counts = {for (final c in colors) c.toARGB32(): 0};
    for (final v in usedColorValues) {
      if (counts.containsKey(v)) counts[v] = counts[v]! + 1;
    }
    var best = colors.first.toARGB32();
    var bestCount = counts[best]!;
    for (final c in colors) {
      final n = counts[c.toARGB32()]!;
      if (n < bestCount) {
        best = c.toARGB32();
        bestCount = n;
      }
    }
    return best;
  }
}
