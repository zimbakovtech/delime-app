import 'dart:io';

import 'package:delime/models/trip.dart';
import 'package:delime/state/app_state.dart';
import 'package:delime/theme/app_theme.dart';
import 'package:delime/utils/money.dart';
import 'package:delime/utils/trip_display.dart';
import 'package:flutter/material.dart';

/// A tappable trip summary card: cover band, name, type/date/member meta and a
/// net-balance pill. Used on the trips list.
class TripCard extends StatelessWidget {
  final Trip trip;
  final TripSummary summary;
  final VoidCallback onTap;
  final VoidCallback onMenu;

  const TripCard({
    super.key,
    required this.trip,
    required this.summary,
    required this.onTap,
    required this.onMenu,
  });

  @override
  Widget build(BuildContext context) {
    final cover = Color(trip.coverColor);
    final dates = formatTripDates(trip.startDate, trip.endDate);
    final meta = <String>[
      trip.type.label,
      ?dates,
      '${summary.memberCount} '
          'member${summary.memberCount == 1 ? '' : 's'}',
    ].join(' · ');

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(AppTheme.radius),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _cover(cover),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 8, 14),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          meta,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 10),
                        _netPill(),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onMenu,
                    icon: const Icon(Icons.more_vert),
                    color: AppTheme.textSecondary,
                    tooltip: 'Trip options',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _cover(Color cover) {
    final photoPath = trip.coverPhotoPath;
    return SizedBox(
      height: 76,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photoPath != null && File(photoPath).existsSync())
            Image.file(File(photoPath), fit: BoxFit.cover)
          else
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [cover, Color.lerp(cover, Colors.black, 0.4)!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
            ),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.28),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(trip.type.icon, size: 20, color: Colors.white),
            ),
          ),
          if (trip.isArchived)
            Positioned(
              top: 12,
              right: 12,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Archived',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _netPill() {
    final settled = summary.outstandingCents == 0;
    final color = settled ? AppTheme.positive : AppTheme.neutral;
    final label = settled
        ? 'All settled'
        : '${Money.formatEur(summary.outstandingCents)} to settle';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            settled
                ? Icons.check_circle
                : Icons.account_balance_wallet_outlined,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
