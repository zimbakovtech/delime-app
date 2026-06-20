import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/balance.dart';
import '../models/person.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/empty_state.dart';
import '../widgets/person_avatar.dart';

class SettlementScreen extends StatelessWidget {
  const SettlementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final people = state.people;
    final purchases = state.purchases;

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

    // Order balances: biggest creditor first, then debtors.
    final ordered = [...balances]
      ..sort((a, b) => b.netCents.compareTo(a.netCents));

    return Scaffold(
      appBar: AppBar(title: const Text('Settle up')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _SectionLabel(allSettled ? 'Balances' : 'The plan'),
          const SizedBox(height: 10),
          if (allSettled)
            const _AllSettledCard()
          else
            ...settlements.map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _SettlementCard(
                    settlement: s,
                    from: state.personById(s.fromPersonId)!,
                    to: state.personById(s.toPersonId)!,
                  ),
                )),
          const SizedBox(height: 24),
          const _SectionLabel('Balances'),
          const SizedBox(height: 10),
          ...ordered.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _BalanceCard(
                  balance: b,
                  person: state.personById(b.personId)!,
                ),
              )),
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
            child: const Icon(Icons.check_rounded,
                size: 36, color: AppTheme.positive),
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

  const _SettlementCard({
    required this.settlement,
    required this.from,
    required this.to,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline),
      ),
      child: Row(
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
                        child: Icon(Icons.arrow_forward,
                            size: 18, color: AppTheme.primary),
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
                    style:
                        TextStyle(color: AppTheme.textSecondary, fontSize: 12),
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
    final sign = net > 0 ? '+' : net < 0 ? '−' : '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.outline),
      ),
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
