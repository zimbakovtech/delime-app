import 'package:delime/models/balance.dart';
import 'package:delime/models/person.dart';
import 'package:delime/models/settlement_record.dart';
import 'package:delime/state/app_state.dart';
import 'package:delime/theme/app_theme.dart';
import 'package:delime/utils/money.dart';
import 'package:delime/widgets/empty_state.dart';
import 'package:delime/widgets/person_avatar.dart';
import 'package:delime/widgets/sheet_grabber.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class SettlementScreen extends StatelessWidget {
  const SettlementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final people = state.people;
    final purchases = state.purchases;
    final history = state.settlementHistory;

    if (people.isEmpty || purchases.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Settle up')),
        body: EmptyState(
          icon: Icons.handshake_outlined,
          title: 'Nothing to settle yet',
          message: people.isEmpty
              ? 'Add people and log a few purchases — Delime will work out '
                    'who owes whom.'
              : 'Once you log a purchase, the balances and the cheapest way '
                    'to settle up show up here.',
        ),
      );
    }

    final balances = state.balances;
    final settlements = state.settlements;
    final allSettled = settlements.isEmpty;

    final ordered = [...balances]
      ..sort((a, b) => b.netCents.compareTo(a.netCents));

    return Scaffold(
      appBar: AppBar(title: const Text('Settle up')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SimplifyToggle(
            value: state.simplifyDebts,
            onChanged: (v) => state.simplifyDebts = v,
          ),
          const SizedBox(height: 20),
          _SectionLabel(allSettled ? 'Balances' : 'The plan'),
          const SizedBox(height: 10),
          if (allSettled)
            const _AllSettledCard()
          else
            ...settlements.map(
              (s) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _SettlementCard(
                  settlement: s,
                  from: state.personById(s.fromPersonId)!,
                  to: state.personById(s.toPersonId)!,
                  onSettle: () => _markSettled(context, state, s),
                ),
              ),
            ),
          const SizedBox(height: 24),
          const _SectionLabel('Balances'),
          const SizedBox(height: 10),
          ...ordered.map(
            (b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _BalanceCard(
                balance: b,
                person: state.personById(b.personId)!,
              ),
            ),
          ),
          if (history.isNotEmpty) ...[
            const SizedBox(height: 24),
            const _SectionLabel('Settlement history'),
            const SizedBox(height: 10),
            ...history.map(
              (r) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _HistoryTile(
                  record: r,
                  from: state.personById(r.fromPersonId),
                  to: state.personById(r.toPersonId),
                  onDelete: () => _undoSettlement(context, state, r),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _markSettled(
    BuildContext context,
    AppState state,
    Settlement settlement,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final note = await showModalBottomSheet<String?>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MarkSettledSheet(
        settlement: settlement,
        from: state.personById(settlement.fromPersonId)!,
        to: state.personById(settlement.toPersonId)!,
      ),
    );
    if (note == null) return; // dismissed
    await state.markSettled(settlement, note: note.isEmpty ? null : note);
    messenger.showSnackBar(const SnackBar(content: Text('Payment recorded.')));
  }

  Future<void> _undoSettlement(
    BuildContext context,
    AppState state,
    SettlementRecord record,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    await state.deleteSettlement(record.id);
    messenger.showSnackBar(
      const SnackBar(content: Text('Settlement removed.')),
    );
  }
}

class _SimplifyToggle extends StatelessWidget {
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SimplifyToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Simplify debts',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value
                      ? 'Fewest possible payments.'
                      : 'Direct debtor → creditor payments.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
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

class _AllSettledCard extends StatelessWidget {
  const _AllSettledCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        gradient: const LinearGradient(
          colors: [Color(0xFF15433E), Color(0xFF123338)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: AppTheme.positive.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.positive.withValues(alpha: 0.18),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 36,
              color: AppTheme.positive,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'All square! 🎉',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Everyone\'s balance is zero. No payments needed.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _SettlementCard extends StatelessWidget {
  final Settlement settlement;
  final Person from;
  final Person to;
  final VoidCallback onSettle;

  const _SettlementCard({
    required this.settlement,
    required this.from,
    required this.to,
    required this.onSettle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              PersonAvatar(person: from, size: 42),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              from.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(horizontal: 8),
                            child: Icon(
                              Icons.arrow_forward,
                              size: 18,
                              color: AppTheme.primary,
                            ),
                          ),
                          Flexible(
                            child: Text(
                              to.name,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'pays',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              PersonAvatar(person: to, size: 42),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    Money.formatEur(settlement.amountCents),
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.positive,
                    ),
                  ),
                  Text(
                    Money.formatMkd(settlement.amountCents),
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onSettle,
              icon: const Icon(Icons.check, size: 18),
              label: const Text('Mark settled'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primary,
                side: const BorderSide(color: AppTheme.outline),
                padding: const EdgeInsets.symmetric(vertical: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  final Balance balance;
  final Person person;

  const _BalanceCard({required this.balance, required this.person});

  @override
  Widget build(BuildContext context) {
    final net = balance.netCents;
    final color = balance.isSettled
        ? AppTheme.neutral
        : balance.isCreditor
        ? AppTheme.positive
        : AppTheme.negative;
    final label = balance.isSettled
        ? 'settled'
        : balance.isCreditor
        ? 'gets back'
        : 'owes';
    final sign = net > 0
        ? '+'
        : net < 0
        ? '−'
        : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: AppTheme.cardDecoration,
      child: Column(
        children: [
          Row(
            children: [
              PersonAvatar(person: person, size: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      person.name,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                '$sign${Money.formatEur(net.abs())}',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _miniStat('Paid', balance.paidCents),
              const SizedBox(width: 8),
              _miniStat('Share', balance.owedCents),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(String label, int cents) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
              ),
            ),
            Text(
              Money.formatEur(cents),
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final SettlementRecord record;
  final Person? from;
  final Person? to;
  final VoidCallback onDelete;

  const _HistoryTile({
    required this.record,
    required this.from,
    required this.to,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final when = DateFormat(
      'd MMM yyyy',
    ).format(DateTime.fromMillisecondsSinceEpoch(record.settledAt));
    final fromName = from?.name ?? 'Someone';
    final toName = to?.name ?? 'someone';
    final note = record.note;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: AppTheme.cardDecoration,
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: AppTheme.positive.withValues(alpha: 0.16),
            ),
            child: const Icon(
              Icons.check_rounded,
              size: 20,
              color: AppTheme.positive,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$fromName paid $toName',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  note == null ? when : '$when · $note',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppTheme.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            Money.formatEur(record.amountCents),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.undo, size: 18),
            color: AppTheme.textSecondary,
            tooltip: 'Undo',
          ),
        ],
      ),
    );
  }
}

class _MarkSettledSheet extends StatefulWidget {
  final Settlement settlement;
  final Person from;
  final Person to;

  const _MarkSettledSheet({
    required this.settlement,
    required this.from,
    required this.to,
  });

  @override
  State<_MarkSettledSheet> createState() => _MarkSettledSheetState();
}

class _MarkSettledSheetState extends State<_MarkSettledSheet> {
  final _noteController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
              const Text(
                'Record payment',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  PersonAvatar(person: widget.from, size: 40),
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.arrow_forward, color: AppTheme.primary),
                  ),
                  PersonAvatar(person: widget.to, size: 40),
                  const Spacer(),
                  Text(
                    Money.formatEur(widget.settlement.amountCents),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppTheme.positive,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  hintText: 'Note (optional) — e.g. cash, Revolut',
                  prefixIcon: Icon(Icons.sticky_note_2_outlined),
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () =>
                    Navigator.pop(context, _noteController.text.trim()),
                child: const Text('Mark as settled'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
