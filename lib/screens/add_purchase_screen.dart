import 'dart:io';

import 'package:delime/models/attachment.dart';
import 'package:delime/models/person.dart';
import 'package:delime/models/purchase.dart';
import 'package:delime/state/app_state.dart';
import 'package:delime/theme/app_theme.dart';
import 'package:delime/utils/categories.dart';
import 'package:delime/utils/money.dart';
import 'package:delime/utils/split.dart';
import 'package:delime/widgets/person_avatar.dart';
import 'package:delime/widgets/receipt_thumbnail.dart';
import 'package:delime/widgets/sheet_grabber.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class AddPurchaseScreen extends StatefulWidget {
  final Purchase? existing;
  const AddPurchaseScreen({super.key, this.existing});

  @override
  State<AddPurchaseScreen> createState() => _AddPurchaseScreenState();
}

class _AddPurchaseScreenState extends State<AddPurchaseScreen> {
  final _nameController = TextEditingController();
  final _amountController = TextEditingController();
  InputCurrency _currency = InputCurrency.eur;
  String _category = ExpenseCategory.fallback;

  // Payers: ordered ids of who paid, plus per-payer cents + text controllers.
  final List<String> _payerIds = [];
  final Map<String, int> _payerCents = {};
  final Map<String, TextEditingController> _payerControllers = {};

  // Split: included ids, mode, and per-person inputs for each strategy.
  final Set<String> _includedIds = {};
  SplitMode _splitMode = SplitMode.equal;
  final Map<String, int> _exactCents = {}; // exactAmounts: cents per person
  final Map<String, int> _percentBp = {}; // percentages: 1/100 of a percent
  final Map<String, int> _shares = {}; // shares: integer weights
  final Map<String, TextEditingController> _splitControllers = {};

  final ImagePicker _picker = ImagePicker();

  late final List<Person> _people;

  @override
  void initState() {
    super.initState();
    _people = context.read<AppState>().people;
    final existing = widget.existing;
    if (existing == null) {
      _amountController.text = '';
      // Default: first person pays, everyone splits equally.
      if (_people.isNotEmpty) {
        _payerIds.add(_people.first.id);
        _payerCents[_people.first.id] = 0;
      }
      _includedIds.addAll(_people.map((p) => p.id));
    } else {
      _nameController.text = existing.name;
      _category = existing.category;
      _amountController.text = Money.centsToEur(
        existing.totalCents,
      ).toStringAsFixed(2);
      for (final c in existing.payers) {
        _payerIds.add(c.personId);
        _payerCents[c.personId] = c.amountCents;
      }
      _includedIds.addAll(existing.splits.map((c) => c.personId));
      // Detect whether the saved split is a plain equal split; otherwise edit
      // it as exact amounts (percentages/shares can't be uniquely recovered).
      final equal = Money.splitEqually(
        existing.totalCents,
        existing.splits.length,
      );
      final sortedSplit = [...existing.splits]
        ..sort((a, b) => b.amountCents.compareTo(a.amountCents));
      final isEqual =
          sortedSplit.length == equal.length &&
          List.generate(
            equal.length,
            (i) => sortedSplit[i].amountCents == equal[i],
          ).every((e) => e);
      _splitMode = isEqual ? SplitMode.equal : SplitMode.exactAmounts;
      for (final c in existing.splits) {
        _exactCents[c.personId] = c.amountCents;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    for (final c in _payerControllers.values) {
      c.dispose();
    }
    for (final c in _splitControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  // ---- Derived values --------------------------------------------------

  int get _totalCents {
    final raw = double.tryParse(_amountController.text.replaceAll(',', '.'));
    if (raw == null || raw < 0) return 0;
    return _currency == InputCurrency.eur
        ? Money.eurToCents(raw)
        : Money.mkdToCents(raw);
  }

  int get _payersTotal =>
      _payerIds.fold(0, (sum, id) => sum + (_payerCents[id] ?? 0));

  List<String> get _includedOrdered => _people
      .where((p) => _includedIds.contains(p.id))
      .map((p) => p.id)
      .toList();

  /// The resolved split shares (in cents) for the current strategy. Every
  /// strategy reconciles to [_totalCents] via the leftover-unit rule.
  Map<String, int> get _splitShares {
    final ids = _includedOrdered;
    if (ids.isEmpty) return {};
    switch (_splitMode) {
      case SplitMode.equal:
        final parts = Money.splitEqually(_totalCents, ids.length);
        return {for (var i = 0; i < ids.length; i++) ids[i]: parts[i]};
      case SplitMode.exactAmounts:
        return {for (final id in ids) id: _exactCents[id] ?? 0};
      case SplitMode.percentages:
        final parts = SplitMath.byPercentages(_totalCents, [
          for (final id in ids) _percentBp[id] ?? 0,
        ]);
        return {for (var i = 0; i < ids.length; i++) ids[i]: parts[i]};
      case SplitMode.shares:
        final parts = SplitMath.byShares(_totalCents, [
          for (final id in ids) _shares[id] ?? 0,
        ]);
        return {for (var i = 0; i < ids.length; i++) ids[i]: parts[i]};
    }
  }

  int get _splitsTotal => _splitShares.values.fold(0, (sum, c) => sum + c);

  int get _percentTotalBp =>
      _includedOrdered.fold(0, (sum, id) => sum + (_percentBp[id] ?? 0));

  int get _sharesTotal =>
      _includedOrdered.fold(0, (sum, id) => sum + (_shares[id] ?? 0));

  bool get _payersValid =>
      _payerIds.isNotEmpty && _payersTotal == _totalCents && _totalCents > 0;

  bool get _splitValid {
    if (_includedIds.isEmpty || _totalCents <= 0) return false;
    switch (_splitMode) {
      case SplitMode.equal:
        return true;
      case SplitMode.exactAmounts:
        return _splitsTotal == _totalCents;
      case SplitMode.percentages:
        return _percentTotalBp == 10000;
      case SplitMode.shares:
        return _sharesTotal > 0;
    }
  }

  bool get _canSave =>
      _nameController.text.trim().isNotEmpty &&
      _totalCents > 0 &&
      _payersValid &&
      _splitValid;

  // ---- Mutations -------------------------------------------------------

  void _onAmountChanged() {
    // Single payer always mirrors the total.
    if (_payerIds.length == 1) {
      _payerCents[_payerIds.first] = _totalCents;
    }
    setState(() {});
  }

  void _togglePayer(String id) {
    setState(() {
      if (_payerIds.contains(id)) {
        if (_payerIds.length == 1) return; // keep at least one payer
        _payerIds.remove(id);
        _payerCents.remove(id);
      } else {
        _payerIds.add(id);
      }
      _reseedPayers();
    });
  }

  /// Re-distributes the total equally across the current payers and refreshes
  /// their input fields. Called whenever the payer set changes.
  void _reseedPayers() {
    final parts = Money.splitEqually(_totalCents, _payerIds.length);
    for (var i = 0; i < _payerIds.length; i++) {
      final id = _payerIds[i];
      _payerCents[id] = parts[i];
      _payerControllers[id]?.text = Money.centsToEur(
        parts[i],
      ).toStringAsFixed(2);
    }
  }

  void _toggleIncluded(String id) {
    setState(() {
      if (_includedIds.contains(id)) {
        _includedIds.remove(id);
        _exactCents.remove(id);
        _percentBp.remove(id);
        _shares.remove(id);
      } else {
        _includedIds.add(id);
      }
      _seedSplitInputs();
    });
  }

  void _setSplitMode(SplitMode mode) {
    setState(() {
      _splitMode = mode;
      _seedSplitInputs();
    });
  }

  /// Seeds the current strategy's per-person inputs (and their text fields) from
  /// an even baseline, so switching strategy or membership starts balanced.
  void _seedSplitInputs() {
    final ids = _includedOrdered;
    if (ids.isEmpty) return;
    switch (_splitMode) {
      case SplitMode.equal:
        break; // computed, no inputs
      case SplitMode.exactAmounts:
        final parts = Money.splitEqually(_totalCents, ids.length);
        for (var i = 0; i < ids.length; i++) {
          _exactCents[ids[i]] = parts[i];
          _splitControllers[ids[i]]?.text = Money.centsToEur(
            parts[i],
          ).toStringAsFixed(2);
        }
      case SplitMode.percentages:
        // Even split of 100% (10000 bp) that sums exactly.
        final parts = SplitMath.allocateByWeights(
          10000,
          List<int>.filled(ids.length, 1),
        );
        for (var i = 0; i < ids.length; i++) {
          _percentBp[ids[i]] = parts[i];
          _splitControllers[ids[i]]?.text = (parts[i] / 100).toStringAsFixed(2);
        }
      case SplitMode.shares:
        for (final id in ids) {
          _shares[id] = 1;
          _splitControllers[id]?.text = '1';
        }
    }
  }

  Future<void> _save() async {
    final state = context.read<AppState>();
    if (_payerIds.length == 1) {
      _payerCents[_payerIds.first] = _totalCents;
    }
    final purchase = Purchase(
      id: widget.existing?.id ?? state.newPurchaseId(),
      name: _nameController.text.trim(),
      totalCents: _totalCents,
      createdAt:
          widget.existing?.createdAt ?? DateTime.now().millisecondsSinceEpoch,
      category: _category,
      payers: [
        for (final id in _payerIds)
          Contribution(personId: id, amountCents: _payerCents[id] ?? 0),
      ],
      splits: [
        for (final entry in _splitShares.entries)
          Contribution(personId: entry.key, amountCents: entry.value),
      ],
    );
    await state.savePurchase(purchase);
    if (mounted) Navigator.pop(context);
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Delete purchase?'),
        content: Text(
          'Remove "${widget.existing!.name}"? This affects everyone\'s balances.',
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
    if (confirmed != true || !mounted) return;
    await context.read<AppState>().deletePurchase(widget.existing!.id);
    if (mounted) Navigator.pop(context);
  }

  // ---- UI --------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.existing != null;
    final state = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing ? 'Edit purchase' : 'New purchase'),
        actions: [
          if (isEditing)
            IconButton(
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
              color: AppTheme.negative,
              tooltip: 'Delete',
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _nameField(),
          const SizedBox(height: 16),
          _categorySection(),
          const SizedBox(height: 16),
          _amountSection(),
          const SizedBox(height: 16),
          _payersSection(),
          const SizedBox(height: 16),
          _splitSection(),
          const SizedBox(height: 16),
          if (isEditing && state.receiptsEnabled) ...[
            _receiptsSection(state),
            const SizedBox(height: 16),
          ],
        ],
      ),
      bottomNavigationBar: _saveBar(),
    );
  }

  Widget _receiptsSection(AppState state) {
    final attachments = state.attachmentsFor(widget.existing!.id);
    return _SectionCard(
      title: 'Receipts',
      subtitle: 'Photos stay on this device.',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          for (final a in attachments)
            ReceiptThumbnail(
              attachment: a,
              onRemove: () => _removeReceipt(a),
              onView: () => _viewReceipt(a),
            ),
          _AddReceiptButton(onTap: _pickReceiptSource),
        ],
      ),
    );
  }

  Future<void> _pickReceiptSource() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            const SheetGrabber(),
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null || !mounted) return;
    await _addReceipt(source);
  }

  Future<void> _addReceipt(ImageSource source) async {
    final state = context.read<AppState>();
    final messenger = ScaffoldMessenger.of(context);
    final XFile? file = await _picker.pickImage(source: source, maxWidth: 2000);
    if (file == null) return;
    try {
      await state.addReceipt(widget.existing!.id, file.path);
    } on Object {
      messenger.showSnackBar(
        const SnackBar(content: Text('Couldn\'t attach that photo.')),
      );
    }
  }

  Future<void> _removeReceipt(Attachment attachment) async {
    await context.read<AppState>().removeReceipt(attachment);
  }

  void _viewReceipt(Attachment attachment) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(16),
        child: GestureDetector(
          onTap: () => Navigator.pop(ctx),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: InteractiveViewer(
              child: Image.file(File(attachment.filePath)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _nameField() {
    return TextField(
      controller: _nameController,
      textCapitalization: TextCapitalization.sentences,
      onChanged: (_) => setState(() {}),
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
      decoration: const InputDecoration(
        hintText: 'What was it? e.g. Dinner, Taxi, Groceries',
        prefixIcon: Icon(Icons.label_outline),
      ),
    );
  }

  Widget _categorySection() {
    final isCustom = !ExpenseCategory.isBuiltIn(_category);
    return _SectionCard(
      title: 'Category',
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in ExpenseCategory.builtIns)
            _CategoryChoiceChip(
              label: c,
              icon: ExpenseCategory.iconFor(c),
              selected: _category == c,
              onTap: () => setState(() => _category = c),
            ),
          _CategoryChoiceChip(
            label: isCustom ? _category : 'Custom…',
            icon: Icons.sell_outlined,
            selected: isCustom,
            onTap: _promptCustomCategory,
          ),
        ],
      ),
    );
  }

  Future<void> _promptCustomCategory() async {
    final controller = TextEditingController(
      text: ExpenseCategory.isBuiltIn(_category) ? '' : _category,
    );
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.surface,
        title: const Text('Custom category'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'e.g. Souvenirs'),
          onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: const Text('Use'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result != null && result.isNotEmpty) {
      setState(() => _category = result);
    }
  }

  Widget _amountSection() {
    final showMkdHint = _currency == InputCurrency.mkd && _totalCents > 0;
    final showEurHint = _currency == InputCurrency.eur && _totalCents > 0;
    return _SectionCard(
      title: 'Amount',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  onChanged: (_) => _onAmountChanged(),
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                  decoration: InputDecoration(
                    hintText: '0.00',
                    prefixText: _currency == InputCurrency.eur ? '€ ' : '',
                    suffixText: _currency == InputCurrency.mkd ? ' ден' : '',
                    prefixStyle: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              _currencyToggle(),
            ],
          ),
          const SizedBox(height: 10),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 150),
            child: showMkdHint
                ? _hintChip(
                    key: const ValueKey('mkd'),
                    icon: Icons.swap_horiz,
                    text:
                        '= ${Money.formatEur(_totalCents)} '
                        '(at 1 € = 61.5 ден)',
                  )
                : showEurHint
                ? _hintChip(
                    key: const ValueKey('eur'),
                    icon: Icons.swap_horiz,
                    text: '= ${Money.formatMkd(_totalCents)}',
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _hintChip({
    required Key key,
    required IconData icon,
    required String text,
  }) {
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppTheme.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: const TextStyle(
              color: AppTheme.primary,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }

  Widget _currencyToggle() {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
        children: [
          for (final c in InputCurrency.values)
            GestureDetector(
              onTap: () => setState(() {
                _currency = c;
                _onAmountChanged();
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _currency == c ? AppTheme.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Text(
                  c.label,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: _currency == c
                        ? AppTheme.onPrimary
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _payersSection() {
    final multi = _payerIds.length > 1;
    final remaining = _totalCents - _payersTotal;
    return _SectionCard(
      title: 'Paid by',
      subtitle: multi
          ? 'Enter how much each person paid.'
          : 'Tap to add more payers if the bill was shared.',
      trailing: _payerIds.isEmpty
          ? null
          : _statusBadge(_payersValid, remaining),
      child: Column(
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final person in _people)
                _PersonChip(
                  person: person,
                  selected: _payerIds.contains(person.id),
                  onTap: () => _togglePayer(person.id),
                ),
            ],
          ),
          if (multi) ...[
            const SizedBox(height: 16),
            for (final id in _payerIds)
              _amountRow(
                person: _people.firstWhere((p) => p.id == id),
                controller: _controllerFor(_payerControllers, id, _payerCents),
                onChanged: (cents) => setState(() => _payerCents[id] = cents),
              ),
          ],
        ],
      ),
    );
  }

  Widget _splitSection() {
    final shares = _splitShares;
    return _SectionCard(
      title: 'Split between',
      subtitle: _splitSubtitle,
      trailing: _splitTrailingBadge(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _splitModeToggle(),
          const SizedBox(height: 14),
          for (final person in _people)
            _SplitRow(
              person: person,
              included: _includedIds.contains(person.id),
              mode: _splitMode,
              shareCents: shares[person.id] ?? 0,
              controller:
                  _splitMode != SplitMode.equal &&
                      _includedIds.contains(person.id)
                  ? _splitControllerFor(person.id)
                  : null,
              onToggle: () => _toggleIncluded(person.id),
              onChanged: (value) => _onSplitInputChanged(person.id, value),
            ),
        ],
      ),
    );
  }

  String get _splitSubtitle => switch (_splitMode) {
    SplitMode.equal =>
      'Shared equally. Tap a person to include or exclude them.',
    SplitMode.exactAmounts => 'Enter each person\'s exact amount.',
    SplitMode.percentages => 'Enter each person\'s share. Must total 100%.',
    SplitMode.shares => 'Enter weights — a bigger weight pays more.',
  };

  Widget? _splitTrailingBadge() {
    switch (_splitMode) {
      case SplitMode.equal:
        return null;
      case SplitMode.exactAmounts:
        return _statusBadge(_splitValid, _totalCents - _splitsTotal);
      case SplitMode.percentages:
        final remainingBp = 10000 - _percentTotalBp;
        if (remainingBp == 0) {
          return const _Badge(
            icon: Icons.check_circle,
            text: '100%',
            color: AppTheme.positive,
          );
        }
        final over = remainingBp < 0;
        return _Badge(
          icon: over ? Icons.error_outline : Icons.pending_outlined,
          text: over
              ? '${_formatPercent(-remainingBp)}% over'
              : '${_formatPercent(remainingBp)}% left',
          color: over ? AppTheme.negative : AppTheme.neutral,
        );
      case SplitMode.shares:
        return _Badge(
          icon: _splitValid ? Icons.check_circle : Icons.pending_outlined,
          text: _splitValid ? '$_sharesTotal total' : 'Set weights',
          color: _splitValid ? AppTheme.positive : AppTheme.neutral,
        );
    }
  }

  static String _formatPercent(int basisPoints) {
    final value = basisPoints / 100;
    return value == value.roundToDouble()
        ? value.toStringAsFixed(0)
        : value.toStringAsFixed(2);
  }

  Widget _splitModeToggle() {
    const modes = <(SplitMode, String, IconData)>[
      (SplitMode.equal, 'Equal', Icons.balance),
      (SplitMode.exactAmounts, 'Exact', Icons.euro),
      (SplitMode.percentages, 'Percent', Icons.percent),
      (SplitMode.shares, 'Shares', Icons.pie_chart_outline),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final (mode, label, icon) in modes)
          _CategoryChoiceChip(
            label: label,
            icon: icon,
            selected: _splitMode == mode,
            onTap: () => _setSplitMode(mode),
          ),
      ],
    );
  }

  void _onSplitInputChanged(String id, double value) {
    setState(() {
      switch (_splitMode) {
        case SplitMode.equal:
          break;
        case SplitMode.exactAmounts:
          _exactCents[id] = Money.eurToCents(value);
        case SplitMode.percentages:
          _percentBp[id] = (value * 100).round();
        case SplitMode.shares:
          final w = value.round();
          _shares[id] = w < 0 ? 0 : w;
      }
    });
  }

  /// A split input controller, seeded once from the current strategy's value.
  TextEditingController _splitControllerFor(String id) {
    return _splitControllers.putIfAbsent(id, () {
      final text = switch (_splitMode) {
        SplitMode.equal => '',
        SplitMode.exactAmounts => Money.centsToEur(
          _exactCents[id] ?? 0,
        ).toStringAsFixed(2),
        SplitMode.percentages => ((_percentBp[id] ?? 0) / 100).toStringAsFixed(
          2,
        ),
        SplitMode.shares => '${_shares[id] ?? 0}',
      };
      return TextEditingController(text: text);
    });
  }

  // A text controller that lives for the field's lifetime, seeded once.
  TextEditingController _controllerFor(
    Map<String, TextEditingController> store,
    String id,
    Map<String, int> cents,
  ) {
    return store.putIfAbsent(id, () {
      final c = TextEditingController(
        text: Money.centsToEur(cents[id] ?? 0).toStringAsFixed(2),
      );
      return c;
    });
  }

  Widget _amountRow({
    required Person person,
    required TextEditingController controller,
    required ValueChanged<int> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          PersonAvatar(person: person, size: 36),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              person.name,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.textPrimary,
              ),
            ),
          ),
          SizedBox(
            width: 110,
            child: _EurField(controller: controller, onChanged: onChanged),
          ),
        ],
      ),
    );
  }

  Widget _statusBadge(bool valid, int remainingCents) {
    if (valid) {
      return const _Badge(
        icon: Icons.check_circle,
        text: 'Balanced',
        color: AppTheme.positive,
      );
    }
    final over = remainingCents < 0;
    return _Badge(
      icon: over ? Icons.error_outline : Icons.pending_outlined,
      text: over
          ? '${Money.formatEur(-remainingCents)} over'
          : '${Money.formatEur(remainingCents)} left',
      color: over ? AppTheme.negative : AppTheme.neutral,
    );
  }

  Widget _saveBar() {
    final problems = _problems();
    return Container(
      decoration: const BoxDecoration(
        color: AppTheme.surface,
        border: Border(top: BorderSide(color: AppTheme.outline)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (problems != null) ...[
                Row(
                  children: [
                    const Icon(
                      Icons.info_outline,
                      size: 16,
                      color: AppTheme.neutral,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        problems,
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _canSave ? _save : null,
                  style: FilledButton.styleFrom(
                    disabledBackgroundColor: AppTheme.surfaceHigh,
                    disabledForegroundColor: AppTheme.textSecondary,
                  ),
                  child: Text(
                    widget.existing != null ? 'Save changes' : 'Save purchase',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// A short, friendly description of what's stopping a save, or null if ready.
  String? _problems() {
    if (_nameController.text.trim().isEmpty) {
      return 'Give the purchase a name.';
    }
    if (_totalCents <= 0) return 'Enter the total amount.';
    if (!_payersValid) {
      final diff = _totalCents - _payersTotal;
      return diff > 0
          ? 'Payers are ${Money.formatEur(diff)} short of the total.'
          : 'Payers exceed the total by ${Money.formatEur(-diff)}.';
    }
    if (_includedIds.isEmpty) {
      return 'Include at least one person in the split.';
    }
    if (!_splitValid) {
      switch (_splitMode) {
        case SplitMode.percentages:
          final diff = 10000 - _percentTotalBp;
          return diff > 0
              ? 'Percentages are ${_formatPercent(diff)}% short of 100%.'
              : 'Percentages exceed 100% by ${_formatPercent(-diff)}%.';
        case SplitMode.shares:
          return 'Give at least one person a weight.';
        case SplitMode.exactAmounts:
        case SplitMode.equal:
          final diff = _totalCents - _splitsTotal;
          return diff > 0
              ? 'Split is ${Money.formatEur(diff)} short of the total.'
              : 'Split exceeds the total by ${Money.formatEur(-diff)}.';
      }
    }
    return null;
  }
}

// ---- Small building blocks --------------------------------------------

class _SectionCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;

  const _SectionCard({
    required this.title,
    this.subtitle,
    this.trailing,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              ?trailing,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
          ],
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Badge({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            text,
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

class _AddReceiptButton extends StatelessWidget {
  final VoidCallback onTap;
  const _AddReceiptButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 76,
        height: 76,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.outline),
        ),
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_a_photo_outlined, color: AppTheme.primary),
            SizedBox(height: 4),
            Text(
              'Add',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryChoiceChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  const _CategoryChoiceChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
              icon,
              size: 16,
              color: selected ? AppTheme.primary : AppTheme.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
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

class _PersonChip extends StatelessWidget {
  final Person person;
  final bool selected;
  final VoidCallback onTap;

  const _PersonChip({
    required this.person,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.fromLTRB(6, 6, 14, 6),
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
            PersonAvatar(person: person, size: 28),
            const SizedBox(width: 8),
            Text(
              person.name,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: selected ? AppTheme.textPrimary : AppTheme.textSecondary,
              ),
            ),
            if (selected) ...[
              const SizedBox(width: 6),
              const Icon(Icons.check_circle, size: 16, color: AppTheme.primary),
            ],
          ],
        ),
      ),
    );
  }
}

class _SplitRow extends StatelessWidget {
  final Person person;
  final bool included;
  final SplitMode mode;
  final int shareCents;
  final TextEditingController? controller;
  final VoidCallback onToggle;

  /// Reports the raw entered number (euros / percent / weight, per [mode]).
  final ValueChanged<double> onChanged;

  const _SplitRow({
    required this.person,
    required this.included,
    required this.mode,
    required this.shareCents,
    required this.controller,
    required this.onToggle,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          GestureDetector(
            onTap: onToggle,
            child: Opacity(
              opacity: included ? 1 : 0.4,
              child: PersonAvatar(person: person, size: 36),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: GestureDetector(
              onTap: onToggle,
              behavior: HitTestBehavior.opaque,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    person.name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: included
                          ? AppTheme.textPrimary
                          : AppTheme.textSecondary,
                    ),
                  ),
                  // Show the resolved € share beneath weighted/percentage inputs.
                  if (included &&
                      (mode == SplitMode.percentages ||
                          mode == SplitMode.shares))
                    Text(
                      '= ${Money.formatEur(shareCents)}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!included)
            TextButton(
              onPressed: onToggle,
              style: TextButton.styleFrom(
                foregroundColor: AppTheme.textSecondary,
                minimumSize: const Size(0, 36),
              ),
              child: const Text('Excluded'),
            )
          else if (mode == SplitMode.equal)
            Text(
              Money.formatEur(shareCents),
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimary,
              ),
            )
          else
            SizedBox(
              width: 104,
              child: _NumberField(
                controller: controller!,
                prefixText: mode == SplitMode.exactAmounts ? '€' : null,
                suffixText: switch (mode) {
                  SplitMode.percentages => '%',
                  SplitMode.shares => '×',
                  _ => null,
                },
                allowDecimal: mode != SplitMode.shares,
                onChanged: onChanged,
              ),
            ),
        ],
      ),
    );
  }
}

/// A compact numeric input that reports the parsed value (0 when empty/invalid).
class _NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String? prefixText;
  final String? suffixText;
  final bool allowDecimal;
  final ValueChanged<double> onChanged;

  const _NumberField({
    required this.controller,
    required this.prefixText,
    required this.suffixText,
    required this.allowDecimal,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimal),
      textAlign: TextAlign.end,
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          allowDecimal ? RegExp(r'[0-9.,]') : RegExp(r'[0-9]'),
        ),
      ],
      onChanged: (v) => onChanged(double.tryParse(v.replaceAll(',', '.')) ?? 0),
      style: const TextStyle(fontWeight: FontWeight.w700),
      decoration: InputDecoration(
        isDense: true,
        prefixText: prefixText,
        suffixText: suffixText,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 10,
          vertical: 10,
        ),
      ),
    );
  }
}

/// A compact EUR amount input that reports parsed cents on change.
class _EurField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<int> onChanged;

  const _EurField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.end,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: (v) {
        final raw = double.tryParse(v.replaceAll(',', '.')) ?? 0;
        onChanged(Money.eurToCents(raw));
      },
      style: const TextStyle(fontWeight: FontWeight.w700),
      decoration: const InputDecoration(
        isDense: true,
        prefixText: '€',
        contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      ),
    );
  }
}
