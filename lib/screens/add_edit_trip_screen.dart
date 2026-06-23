import 'package:delime/models/trip.dart';
import 'package:delime/state/app_state.dart';
import 'package:delime/theme/app_theme.dart';
import 'package:delime/theme/avatar_palette.dart';
import 'package:delime/utils/trip_display.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

/// Create or edit a trip: name, type, cover colour and optional date range.
class AddEditTripScreen extends StatefulWidget {
  final Trip? existing;
  const AddEditTripScreen({super.key, this.existing});

  @override
  State<AddEditTripScreen> createState() => _AddEditTripScreenState();
}

class _AddEditTripScreenState extends State<AddEditTripScreen> {
  final _nameController = TextEditingController();
  late TripType _type;
  late int _coverColor;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      _type = TripType.vacation;
      final used = context
          .read<AppState>()
          .trips
          .map((t) => t.coverColor)
          .toList();
      _coverColor = AvatarPalette.suggestColorValue(used);
    } else {
      _nameController.text = existing.name;
      _type = existing.type;
      _coverColor = existing.coverColor;
      _startDate = existing.startDate == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(existing.startDate!);
      _endDate = existing.endDate == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(existing.endDate!);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSave => _nameController.text.trim().isNotEmpty;

  Future<void> _pickDate({required bool isStart}) async {
    final initial = (isStart ? _startDate : _endDate) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _startDate = picked;
        if (_endDate != null && _endDate!.isBefore(picked)) _endDate = picked;
      } else {
        _endDate = picked;
        if (_startDate != null && _startDate!.isAfter(picked)) {
          _startDate = picked;
        }
      }
    });
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    final name = _nameController.text.trim();
    final navigator = Navigator.of(context);
    final existing = widget.existing;
    if (existing == null) {
      await state.addTrip(
        name: name,
        type: _type,
        coverColor: _coverColor,
        startDate: _startDate?.millisecondsSinceEpoch,
        endDate: _endDate?.millisecondsSinceEpoch,
      );
    } else {
      await state.saveTripEdits(
        existing.copyWith(
          name: name,
          type: _type,
          coverColor: _coverColor,
          startDate: _startDate?.millisecondsSinceEpoch,
          clearStartDate: _startDate == null,
          endDate: _endDate?.millisecondsSinceEpoch,
          clearEndDate: _endDate == null,
        ),
      );
    }
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit trip' : 'New trip')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          TextField(
            controller: _nameController,
            autofocus: !isEditing,
            textCapitalization: TextCapitalization.words,
            onChanged: (_) => setState(() {}),
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
            decoration: const InputDecoration(
              hintText: 'Trip name, e.g. Greece 2026',
              prefixIcon: Icon(Icons.luggage_outlined),
            ),
          ),
          const SizedBox(height: 20),
          _label('Type'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final t in TripType.values)
                _TypeChip(
                  type: t,
                  selected: t == _type,
                  onTap: () => setState(() => _type = t),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _label('Cover colour'),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in AvatarPalette.colors)
                _ColorDot(
                  color: c,
                  selected: c.toARGB32() == _coverColor,
                  onTap: () => setState(() => _coverColor = c.toARGB32()),
                ),
            ],
          ),
          const SizedBox(height: 22),
          _label('Dates (optional)'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateField(
                  label: 'Start',
                  date: _startDate,
                  onTap: () => _pickDate(isStart: true),
                  onClear: _startDate == null
                      ? null
                      : () => setState(() => _startDate = null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateField(
                  label: 'End',
                  date: _endDate,
                  onTap: () => _pickDate(isStart: false),
                  onClear: _endDate == null
                      ? null
                      : () => setState(() => _endDate = null),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          border: Border(top: BorderSide(color: AppTheme.outline)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canSave ? _save : null,
                style: FilledButton.styleFrom(
                  disabledBackgroundColor: AppTheme.surfaceHigh,
                  disabledForegroundColor: AppTheme.textSecondary,
                ),
                child: Text(isEditing ? 'Save changes' : 'Create trip'),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _label(String text) => Text(
    text.toUpperCase(),
    style: const TextStyle(
      color: AppTheme.textSecondary,
      fontWeight: FontWeight.w700,
      fontSize: 12,
      letterSpacing: 1.1,
    ),
  );
}

class _TypeChip extends StatelessWidget {
  final TripType type;
  final bool selected;
  final VoidCallback onTap;

  const _TypeChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary.withValues(alpha: 0.16)
              : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: selected ? AppTheme.primary : AppTheme.outline,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              type.icon,
              size: 17,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 7),
            Text(
              type.label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ColorDot extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorDot({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? Colors.white : Colors.transparent,
            width: 3,
          ),
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.black, size: 22)
            : null,
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final DateTime? date;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _DateField({
    required this.label,
    required this.date,
    required this.onTap,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final text = date == null ? label : DateFormat('d MMM yyyy').format(date!);
    return Material(
      color: AppTheme.surfaceHigh,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              const Icon(
                Icons.event_outlined,
                size: 18,
                color: AppTheme.textSecondary,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: date == null
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onClear != null)
                GestureDetector(
                  onTap: onClear,
                  child: const Icon(
                    Icons.close,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
