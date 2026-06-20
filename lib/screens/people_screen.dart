import 'package:delime/models/person.dart';
import 'package:delime/state/app_state.dart';
import 'package:delime/theme/app_theme.dart';
import 'package:delime/theme/avatar_palette.dart';
import 'package:delime/widgets/empty_state.dart';
import 'package:delime/widgets/person_avatar.dart';
import 'package:delime/widgets/sheet_grabber.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final people = state.people;

    return Scaffold(
      appBar: AppBar(
        title: const Text('People'),
        actions: [
          if (people.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Text(
                '${people.length}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
      floatingActionButton: people.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _showPersonSheet(context),
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
              icon: const Icon(Icons.person_add_alt_1),
              label: const Text(
                'Add person',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
      body: people.isEmpty
          ? EmptyState(
              icon: Icons.group_outlined,
              title: 'Who\'s on the trip?',
              message:
                  'Add everyone sharing expenses. Each person gets their own '
                  'colour so balances are easy to read.',
              actionLabel: 'Add the first person',
              onAction: () => _showPersonSheet(context),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
              itemCount: people.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final person = people[i];
                return _PersonTile(
                  person: person,
                  onEdit: () => _showPersonSheet(context, existing: person),
                  onDelete: () => _confirmDelete(context, person),
                );
              },
            ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, Person person) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      builder: (ctx) => _ConfirmDeleteSheet(person: person),
    );
    if (confirmed != true || !context.mounted) return;

    final messenger = ScaffoldMessenger.of(context);
    try {
      await context.read<AppState>().deletePerson(person.id);
      messenger.showSnackBar(
        SnackBar(content: Text('${person.name} removed.')),
      );
    } on AppStateException catch (e) {
      messenger.showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.surfaceHigh,
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  void _showPersonSheet(BuildContext context, {Person? existing}) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PersonSheet(existing: existing),
    );
  }
}

class _PersonTile extends StatelessWidget {
  final Person person;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _PersonTile({
    required this.person,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              PersonAvatar(person: person, size: 46),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  person.name,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                color: AppTheme.textSecondary,
                tooltip: 'Delete',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ConfirmDeleteSheet extends StatelessWidget {
  final Person person;
  const _ConfirmDeleteSheet({required this.person});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SheetGrabber(),
            const SizedBox(height: 16),
            Row(
              children: [
                PersonAvatar(person: person, size: 44),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    'Delete ${person.name}?',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Text(
              'This can\'t be undone. People who appear in a purchase can\'t '
              'be deleted until they\'re removed from it.',
              style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 22),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.textPrimary,
                      side: const BorderSide(color: AppTheme.outline),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancel'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.negative,
                      foregroundColor: Colors.white,
                    ),
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _PersonSheet extends StatefulWidget {
  final Person? existing;
  const _PersonSheet({this.existing});

  @override
  State<_PersonSheet> createState() => _PersonSheetState();
}

class _PersonSheetState extends State<_PersonSheet> {
  late final TextEditingController _controller;
  late int _colorValue;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.existing?.name ?? '');
    _colorValue =
        widget.existing?.colorValue ??
        AvatarPalette.suggestColorValue(
          context.read<AppState>().people.map((p) => p.colorValue).toList(),
        );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) return;
    final state = context.read<AppState>();
    final existing = widget.existing;
    if (existing == null) {
      // For a brand-new person the colour follows auto-assignment unless the
      // user picked one; honour the picked colour by updating right after.
      await state.addPerson(name);
    } else {
      await state.updatePerson(
        existing.copyWith(name: name, colorValue: _colorValue),
      );
    }
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomInset),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SheetGrabber(),
              const SizedBox(height: 16),
              Text(
                isEditing ? 'Edit person' : 'Add person',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 20),
              TextField(
                controller: _controller,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: const InputDecoration(
                  hintText: 'Name',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
              if (isEditing) ...[
                const SizedBox(height: 20),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Colour',
                    style: TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    for (final c in AvatarPalette.colors)
                      _ColorDot(
                        color: c,
                        selected: c.toARGB32() == _colorValue,
                        onTap: () => setState(() => _colorValue = c.toARGB32()),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _save,
                child: Text(isEditing ? 'Save' : 'Add'),
              ),
            ],
          ),
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
