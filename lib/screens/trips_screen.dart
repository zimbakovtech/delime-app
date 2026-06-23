import 'package:delime/models/trip.dart';
import 'package:delime/screens/add_edit_trip_screen.dart';
import 'package:delime/screens/home_screen.dart';
import 'package:delime/state/app_state.dart';
import 'package:delime/theme/app_theme.dart';
import 'package:delime/widgets/empty_state.dart';
import 'package:delime/widgets/sheet_grabber.dart';
import 'package:delime/widgets/trip_card.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

/// The app's entry screen: a list of trips. Each trip opens the bottom-nav
/// shell scoped to it.
class TripsScreen extends StatelessWidget {
  const TripsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();

    if (state.loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppTheme.primary)),
      );
    }

    final active = state.activeTrips;
    final archived = state.archivedTrips;
    final hasAny = active.isNotEmpty || archived.isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Trips')),
      floatingActionButton: hasAny
          ? FloatingActionButton.extended(
              onPressed: () => _openEditor(context),
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text(
                'New trip',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            )
          : null,
      body: !hasAny
          ? EmptyState(
              icon: Icons.luggage_outlined,
              title: 'Start your first trip',
              message:
                  'A trip is a shared ledger — a holiday, a household, a night '
                  'out. Create one to add people and split expenses.',
              actionLabel: 'Create a trip',
              onAction: () => _openEditor(context),
            )
          : ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              children: [
                for (final trip in active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: TripCard(
                      trip: trip,
                      summary: state.summaryFor(trip.id),
                      onTap: () => _openTrip(context, trip),
                      onMenu: () => _showMenu(context, trip),
                    ),
                  ),
                if (archived.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const _SectionLabel('Archived'),
                  const SizedBox(height: 12),
                  for (final trip in archived)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TripCard(
                        trip: trip,
                        summary: state.summaryFor(trip.id),
                        onTap: () => _openTrip(context, trip),
                        onMenu: () => _showMenu(context, trip),
                      ),
                    ),
                ],
              ],
            ),
    );
  }

  Future<void> _openEditor(BuildContext context, {Trip? existing}) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddEditTripScreen(existing: existing),
      ),
    );
  }

  Future<void> _openTrip(BuildContext context, Trip trip) async {
    final state = context.read<AppState>();
    await state.selectTrip(trip.id);
    if (!context.mounted) return;
    await Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const HomeScreen()));
    state.closeTrip();
  }

  void _showMenu(BuildContext context, Trip trip) {
    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => _TripMenu(
        trip: trip,
        onEdit: () {
          Navigator.pop(sheetContext);
          _openEditor(context, existing: trip);
        },
        onToggleArchive: () {
          Navigator.pop(sheetContext);
          context.read<AppState>().setTripStatus(
            trip,
            trip.isArchived ? TripStatus.active : TripStatus.archived,
          );
        },
        onDelete: () {
          Navigator.pop(sheetContext);
          _confirmDelete(context, trip);
        },
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Trip trip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete trip?'),
        content: Text(
          'Delete "${trip.name}" and everything in it — people, purchases and '
          'settlements? This can\'t be undone.',
          style: const TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: AppTheme.negative),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await context.read<AppState>().deleteTrip(trip.id);
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: const TextStyle(
        color: AppTheme.textSecondary,
        fontWeight: FontWeight.w700,
        fontSize: 12,
        letterSpacing: 1.2,
      ),
    );
  }
}

class _TripMenu extends StatelessWidget {
  final Trip trip;
  final VoidCallback onEdit;
  final VoidCallback onToggleArchive;
  final VoidCallback onDelete;

  const _TripMenu({
    required this.trip,
    required this.onEdit,
    required this.onToggleArchive,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SheetGrabber(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit trip'),
              onTap: onEdit,
            ),
            ListTile(
              leading: Icon(
                trip.isArchived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              title: Text(trip.isArchived ? 'Unarchive' : 'Archive'),
              onTap: onToggleArchive,
            ),
            ListTile(
              leading: const Icon(
                Icons.delete_outline,
                color: AppTheme.negative,
              ),
              title: const Text(
                'Delete trip',
                style: TextStyle(color: AppTheme.negative),
              ),
              onTap: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
