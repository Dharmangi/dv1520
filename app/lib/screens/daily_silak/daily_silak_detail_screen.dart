import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/currency.dart';
import '../../models/daily_silak.dart';
import '../../models/outstanding_entry.dart';
import '../../providers/daily_silak_provider.dart';
import '../../providers/outstanding_provider.dart';
import 'add_daily_silak_entry_sheet.dart';
import 'settle_outstanding_sheet.dart';

class DailySilakDetailScreen extends ConsumerWidget {
  const DailySilakDetailScreen({super.key, required this.date});

  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncSilak = ref.watch(dailySilakByDateProvider(date));
    final asyncOutstanding = ref.watch(outstandingProvider(date));
    final displayDate = DateFormat('dd MMM yyyy, EEEE').format(DateTime.parse(date));

    return Scaffold(
      appBar: AppBar(
        title: Text(displayDate),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: asyncSilak.hasValue
                ? () async {
                    await ref.read(dailySilakByDateProvider(date).notifier).sync();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Refreshed')),
                      );
                    }
                  }
                : null,
          ),
        ],
      ),
      body: asyncSilak.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (silak) => asyncOutstanding.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
          data: (outstanding) {
            // Total debit = today's paid entries + outstanding pending + havala pending
            final todayPaid = silak.totalPaid;
            final outstandingTotal = outstanding.outstandingEntries.fold(0, (s, e) => s + e.pendingAmount);
            final havalaTotal = outstanding.havalaPending.fold(0, (s, e) => s + e.totalPending);
            final totalDebit = todayPaid + outstandingTotal + havalaTotal;
            // Total credit = today's manual received + havala credits (settled/paid havalas today)
            final havalaCreditsTotal = outstanding.havalaCredits.fold(0, (s, e) => s + e.totalAmount);
            final totalCredit = silak.totalReceived + havalaCreditsTotal;
            final netBalance = totalCredit - totalDebit;

            return Column(
              children: [
                // Summary bar
                _SummaryBar(totalCredit: totalCredit, totalDebit: totalDebit, netBalance: netBalance),

                // Column headers
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  child: Row(
                    children: [
                      Expanded(child: _ColHeader(label: 'CREDIT', icon: Icons.arrow_downward, color: Colors.green.shade700)),
                      const SizedBox(width: 8),
                      Expanded(child: _ColHeader(label: 'DEBIT', icon: Icons.arrow_upward, color: Colors.red.shade700)),
                    ],
                  ),
                ),

                // Two column content
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Credit column — today's received entries + havala credits
                      Expanded(
                        child: _CreditColumn(
                          silak: silak,
                          havalaCredits: outstanding.havalaCredits,
                          date: date,
                          ref: ref,
                        ),
                      ),
                      Container(width: 1, color: Theme.of(context).dividerColor),
                      // Debit column — today's paid + outstanding + havala pending
                      Expanded(
                        child: _DebitColumn(
                          silak: silak,
                          outstanding: outstanding,
                          date: date,
                          ref: ref,
                        ),
                      ),
                    ],
                  ),
                ),

                // Net balance footer
                _NetBalanceFooter(netBalance: netBalance),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ── Credit column (received entries for today + havala credits) ──────────────
class _CreditColumn extends StatelessWidget {
  const _CreditColumn({required this.silak, required this.havalaCredits, required this.date, required this.ref});
  final DailySilak silak;
  final List<HavalaCreditSummary> havalaCredits;
  final String date;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final entries = silak.receivedEntries;
    final hasAnything = entries.isNotEmpty || havalaCredits.isNotEmpty;

    if (!hasAnything) {
      return const _EmptyState(text: 'No credit\nentries today');
    }

    return ListView(
      padding: const EdgeInsets.all(6),
      children: [
        // Havala credits — havalas paid/settled today
        if (havalaCredits.isNotEmpty) ...[
          _SectionLabel(label: 'Havala Received', color: Colors.green.shade800),
          ...havalaCredits.map((h) => _EntryCard(
                name: h.personName,
                amount: h.totalAmount,
                note: 'Havala payment received',
                color: Colors.green.shade800,
                canEdit: false,
              )),
        ],
        // Manual received entries
        if (entries.isNotEmpty) ...[
          if (havalaCredits.isNotEmpty) _SectionLabel(label: 'Other Received', color: Colors.green.shade700),
          ...entries.map((entry) => _EntryCard(
                name: entry.personName,
                amount: entry.amount,
                note: entry.note,
                color: Colors.green.shade700,
                canEdit: !entry.isFromHavala,
                onEdit: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AddDailySilakEntrySheet(
                    date: date,
                    initialType: 'received',
                    editEntry: entry,
                    silakId: silak.id,
                    allowDateChange: true,
                  ),
                ),
                onDelete: () async {
                  final confirmed = await _confirmDialog(context, entry.personName);
                  if (confirmed == true) {
                    await ref.read(dailySilakByDateProvider(date).notifier).removeEntry(silak.id, entry.id);
                  }
                },
              )),
        ],
      ],
    );
  }
}

// ── Debit column (today paid + outstanding + havala pending) ─────────────────
class _DebitColumn extends StatelessWidget {
  const _DebitColumn({required this.silak, required this.outstanding, required this.date, required this.ref});
  final DailySilak silak;
  final OutstandingListResult outstanding;
  final String date;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    final todayPaid = silak.paidEntries;
    final outstandingEntries = outstanding.outstandingEntries;
    final havalaPending = outstanding.havalaPending;

    final hasAnything = todayPaid.isNotEmpty || outstandingEntries.isNotEmpty || havalaPending.isNotEmpty;
    if (!hasAnything) {
      return const _EmptyState(text: 'No debit\nentries');
    }

    return ListView(
      padding: const EdgeInsets.all(6),
      children: [
        // Outstanding entries (persistent, carry forward daily)
        if (outstandingEntries.isNotEmpty) ...[
          _SectionLabel(label: 'Outstanding', color: Colors.red.shade700),
          ...outstandingEntries.map((e) => _OutstandingCard(entry: e, ref: ref, date: date)),
        ],

        // Havala pending amounts
        if (havalaPending.isNotEmpty) ...[
          _SectionLabel(label: 'Havala Pending', color: Colors.orange.shade700),
          ...havalaPending.map((h) => _EntryCard(
                name: h.personName,
                amount: h.totalPending,
                note: '${h.havalaCount} havala(s) pending',
                color: Colors.orange.shade700,
                canEdit: false,
              )),
        ],

        // Today's manual paid entries
        if (todayPaid.isNotEmpty) ...[
          _SectionLabel(label: "Today's Paid", color: Colors.red.shade800),
          ...todayPaid.map((entry) => _EntryCard(
                name: entry.personName,
                amount: entry.amount,
                note: entry.note,
                color: Colors.red.shade700,
                canEdit: !entry.isFromHavala,
                onEdit: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => AddDailySilakEntrySheet(
                    date: date,
                    initialType: 'paid',
                    editEntry: entry,
                    silakId: silak.id,
                    allowDateChange: true,
                  ),
                ),
                onDelete: () async {
                  final confirmed = await _confirmDialog(context, entry.personName);
                  if (confirmed == true) {
                    await ref.read(dailySilakByDateProvider(date).notifier).removeEntry(silak.id, entry.id);
                  }
                },
              )),
        ],
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inbox_outlined, size: 28, color: Theme.of(context).colorScheme.outline),
            const SizedBox(height: 6),
            Text(text, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline)),
          ],
        ),
      ),
    );
  }
}

// ── Outstanding card with settle button ──────────────────────────────────────
class _OutstandingCard extends StatelessWidget {
  const _OutstandingCard({required this.entry, required this.ref, required this.date});
  final OutstandingEntry entry;
  final WidgetRef ref;
  final String date;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: Colors.red.shade700.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade700.withValues(alpha: 0.25)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(entry.personName, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), overflow: TextOverflow.ellipsis),
                ),
                InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () async {
                    final confirmed = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Delete Outstanding'),
                        content: Text('Delete outstanding entry for ${entry.personName}?'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
                          FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Delete')),
                        ],
                      ),
                    );
                    if (confirmed == true) {
                      await ref.read(outstandingProvider(date).notifier).deleteEntry(entry.id);
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(Icons.delete_outline, size: 15, color: Theme.of(context).colorScheme.outline),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 2),
            Text(formatRupees(entry.pendingAmount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.red.shade700)),
            if (entry.isPartiallySettled)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text('Partial: ${formatRupees(entry.settledAmount)} paid', style: const TextStyle(fontSize: 10, color: Colors.orange)),
              ),
            if (entry.note.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Text(entry.note, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(DateFormat('dd MMM').format(entry.createdDate), style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () => showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  builder: (_) => SettleOutstandingSheet(entry: entry, date: date),
                ),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.green.shade700,
                  side: BorderSide(color: Colors.green.shade700),
                  minimumSize: const Size.fromHeight(32),
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  visualDensity: VisualDensity.compact,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: const Text('Settle ✓', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Reusable widgets ─────────────────────────────────────────────────────────
class _EntryCard extends StatelessWidget {
  const _EntryCard({
    required this.name,
    required this.amount,
    required this.note,
    required this.color,
    required this.canEdit,
    this.onEdit,
    this.onDelete,
  });
  final String name;
  final int amount;
  final String note;
  final Color color;
  final bool canEdit;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: canEdit && onEdit != null ? onEdit : null,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13), maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(formatRupees(amount), style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
                      if (note.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 1),
                          child: Text(note, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.outline), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                    ],
                  ),
                ),
                if (canEdit && onDelete != null)
                  InkWell(
                    borderRadius: BorderRadius.circular(20),
                    onTap: onDelete,
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: Icon(Icons.delete_outline, size: 15, color: Theme.of(context).colorScheme.outline),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
      child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color, letterSpacing: 0.8)),
    );
  }
}

class _ColHeader extends StatelessWidget {
  const _ColHeader({required this.label, required this.icon, required this.color});
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: color, size: 14),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 11, letterSpacing: 0.4)),
        ],
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.totalCredit, required this.totalDebit, required this.netBalance});
  final int totalCredit;
  final int totalDebit;
  final int netBalance;

  @override
  Widget build(BuildContext context) {
    final isPositive = netBalance >= 0;
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _SummaryItem(label: 'Credit', amount: totalCredit, color: Colors.green.shade700),
          Container(width: 1, height: 36, color: Theme.of(context).dividerColor),
          _SummaryItem(label: 'Debit', amount: totalDebit, color: Colors.red.shade700),
          Container(width: 1, height: 36, color: Theme.of(context).dividerColor),
          _SummaryItem(label: 'Net', amount: netBalance, color: isPositive ? Colors.green.shade700 : Colors.red.shade700, prefix: isPositive ? '+' : ''),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.amount, required this.color, this.prefix = ''});
  final String label;
  final int amount;
  final Color color;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text('$prefix${formatRupees(amount)}', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }
}

class _NetBalanceFooter extends StatelessWidget {
  const _NetBalanceFooter({required this.netBalance});
  final int netBalance;

  @override
  Widget build(BuildContext context) {
    final isPositive = netBalance >= 0;
    final color = isPositive ? Colors.green.shade700 : Colors.red.shade700;
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        border: Border(top: BorderSide(color: AppTheme.primary.withValues(alpha: 0.15), width: 1)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NET BALANCE', style: TextStyle(fontSize: 11, letterSpacing: 1.2, color: Theme.of(context).colorScheme.onSurfaceVariant)),
              Text('Credit − Debit', style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7))),
            ],
          ),
          Text('${isPositive ? '+' : ''}${formatRupees(netBalance)}', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }
}

Future<bool?> _confirmDialog(BuildContext context, String name) {
  return showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Remove Entry'),
      content: Text('Remove "$name" from today\'s silak?'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), style: FilledButton.styleFrom(backgroundColor: Colors.red), child: const Text('Remove')),
      ],
    ),
  );
}
