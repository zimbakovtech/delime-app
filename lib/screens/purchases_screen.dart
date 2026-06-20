import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/person.dart';
import '../models/purchase.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../utils/money.dart';
import '../widgets/empty_state.dart';
import '../widgets/person_avatar.dart';
import 'add_purchase_screen.dart';

class PurchasesScreen extends StatelessWidget {
  const PurchasesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<AppState>();
    final purchases = state.purchases;
    final hasPeople = state.people.isNotEmpty;

    final totalCents =
        purchases.fold<int>(0, (sum, p) => sum + p.totalCents);

    return Scaffold(
      floatingActionButton: purchases.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openAdd(context, hasPeople),
              backgroundColor: AppTheme.primary,
              foregroundColor: AppTheme.onPrimary,
              icon: const Icon(Icons.add),
              label: const Text('Add purchase',
                  style: TextStyle(fontWeight: FontWeight.w700)),
            ),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            backgroundColor: AppTheme.background,
            title: const Text('Purchases'),
          ),
          if (purchases.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: hasPeople
                  ? EmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'No purchases yet',
                      message:
                          'Log your first expense — who paid, and how the '
                          'cost is shared. Delime does the maths.',
                      actionLabel: 'Add a purchase',
                      onAction: () => _openAdd(context, hasPeople),
                    )
                  : const EmptyState(
                      icon: Icons.group_add_outlined,
                      title: 'Add people first',
                      message:
                          'Before logging purchases, head to the People tab '
                          'and add everyone on the trip.',
                    ),
            )
          else ...[
            SliverToBoxAdapter(
              child: _TotalHeader(
                  count: purchases.length, totalCents: totalCents),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
              sliver: SliverList.separated(
                itemCount: purchases.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final purchase = purchases[i];
                  return _PurchaseCard(
                    purchase: purchase,
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            AddPurchaseScreen(existing: purchase),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }

  void _openAdd(BuildContext context, bool hasPeople) {
    if (!hasPeople) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add some people first.')),
      );
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddPurchaseScreen()),
    );
  }
}

class _TotalHeader extends StatelessWidget {
  final int count;
  final int totalCents;

  const _TotalHeader({required this.count, required this.totalCents});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF15433E), Color(0xFF13343A)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: AppTheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Total spent',
                  style: TextStyle(
                    color: AppTheme.primary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    letterSpacing: 0.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  Money.formatEur(totalCents),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  Money.formatMkd(totalCents),
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const Spacer(),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(30),
              ),
              child: Text(
                '$count item${count == 1 ? '' : 's'}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PurchaseCard extends StatelessWidget {
  final Purchase purchase;
  final VoidCallback onTap;

  const _PurchaseCard({required this.purchase, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final state = context.read<AppState>();
    final payerNames = purchase.payers
        .map((c) => state.personById(c.personId)?.name)
        .whereType<String>()
        .toList();
    final splitPeople = purchase.splits
        .map((c) => state.personById(c.personId))
        .whereType<Person>()
        .toList();

    final paidBy = payerNames.isEmpty
        ? 'Unknown'
        : payerNames.length <= 2
            ? payerNames.join(' & ')
            : '${payerNames.take(1).join()} +${payerNames.length - 1}';

    return Material(
      color: AppTheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      purchase.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        Money.formatEur(purchase.totalCents),
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                      Text(
                        Money.formatMkd(purchase.totalCents),
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppTheme.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  AvatarCluster(people: splitPeople, size: 26),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Paid by $paidBy · split ${splitPeople.length} '
                      'way${splitPeople.length == 1 ? '' : 's'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
