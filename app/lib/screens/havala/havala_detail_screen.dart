import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency.dart';
import '../../models/havala.dart';
import '../../models/transaction.dart';
import '../../providers/havala_provider.dart';
import '../../providers/transactions_provider.dart';

class HavalaDetailScreen extends ConsumerWidget {
  const HavalaDetailScreen({super.key, required this.havala});

  final Havala havala;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final havalasAsync = ref.watch(havalaListProvider);
    final current = havalasAsync.maybeWhen(
      data: (list) => list.firstWhere((h) => h.id == havala.id, orElse: () => havala),
      orElse: () => havala,
    );
    final ownerTxnsAsync = ref.watch(personTransactionsProvider(current.ownerId));

    return Scaffold(
      appBar: AppBar(title: Text(current.ownerName ?? 'Havala')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(child: _AmountLabel(label: 'Total', amount: current.totalAmount, color: Colors.black87)),
                  Expanded(child: _AmountLabel(label: 'Paid', amount: current.paidAmount, color: Colors.green)),
                  Expanded(
                    child: _AmountLabel(
                      label: 'Pending',
                      amount: current.pendingAmount,
                      color: current.pendingAmount > 0 ? Colors.orange.shade800 : Colors.grey,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Customer Splits', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ...current.splits.map((s) => Card(
                child: ListTile(
                  title: Text(s.personName ?? 'Unknown'),
                  subtitle: s.personPlace != null ? Text(s.personPlace!) : null,
                  trailing: Text(formatRupees(s.amount), style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )),
          const SizedBox(height: 24),
          Text('Owner Entries (Pending & Settlements)', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ownerTxnsAsync.when(
            data: (txns) {
              final related = txns.where((t) => current.ownerTransactionIds.contains(t.id) || t.id == current.pendingTransactionId).toList();
              if (related.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('No entries yet.'),
                );
              }
              return Column(children: related.map((t) => _EntryTile(txn: t)).toList());
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Failed to load entries: $e'),
          ),
        ],
      ),
    );
  }
}

class _AmountLabel extends StatelessWidget {
  const _AmountLabel({required this.label, required this.amount, required this.color});

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(formatRupees(amount), style: TextStyle(fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: txn.isPending ? Colors.orange.shade100 : Colors.green.shade100,
          child: Icon(
            txn.isPending ? Icons.hourglass_empty : Icons.check,
            color: txn.isPending ? Colors.orange.shade800 : Colors.green,
          ),
        ),
        title: Text(txn.description ?? (txn.isPending ? 'Pending' : 'Settlement')),
        subtitle: Text('${txn.date.day}/${txn.date.month}/${txn.date.year}'),
        trailing: Text(
          formatRupees(txn.amount),
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: txn.isPending ? Colors.orange.shade800 : Colors.green,
          ),
        ),
      ),
    );
  }
}
