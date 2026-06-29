import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../models/person.dart';
import '../../models/transaction.dart';
import '../../providers/people_provider.dart';
import '../../providers/transactions_provider.dart';
import '../transactions/add_transaction_sheet.dart';

class PersonLedgerScreen extends ConsumerWidget {
  const PersonLedgerScreen({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final txnsAsync = ref.watch(personTransactionsProvider(person.id));

    return Scaffold(
      appBar: AppBar(title: Text(person.name)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'ledger_fab',
        onPressed: () => showAddTransactionSheet(context, initialPerson: person),
        child: const Icon(Icons.add),
      ),
      body: txnsAsync.when(
        data: (txns) {
          final balance = txns.fold<int>(
            0,
            (sum, t) => sum + (t.type == 'received' ? t.amount : -t.amount),
          );

          return ListView(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Balance', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        formatRupees(balance),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              if (txns.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No transactions with this person yet.')),
                )
              else
                ...txns.map((t) => ListTile(
                      leading: CircleAvatar(
                        backgroundColor: t.type == 'received' ? Colors.green.shade100 : Colors.red.shade100,
                        child: Icon(
                          t.type == 'received' ? Icons.arrow_downward : Icons.arrow_upward,
                          color: t.type == 'received' ? Colors.green : Colors.red,
                        ),
                      ),
                      title: Text(t.description ?? t.paymentMode),
                      subtitle: Text('${t.date.day}/${t.date.month}/${t.date.year}'),
                      trailing: Text(
                        formatRupees(t.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: t.type == 'received' ? Colors.green : Colors.red,
                        ),
                      ),
                      onLongPress: () => _handleTransactionLongPress(context, ref, t),
                    )),
              if (person.isOwner) _OwnerCustomersSection(owner: person),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load transactions: $e')),
      ),
    );
  }

  Future<void> _handleTransactionLongPress(BuildContext context, WidgetRef ref, Txn txn) async {
    final choice = await showEditDeleteMenu(context);
    if (choice == 'edit') {
      if (context.mounted) showAddTransactionSheet(context, initialPerson: person, existing: txn);
    } else if (choice == 'delete') {
      if (!context.mounted) return;
      final confirmed = await confirmDelete(context, message: 'Delete this transaction?');
      if (confirmed) {
        await ref.read(transactionsProvider.notifier).deleteTransaction(txn);
      }
    }
  }
}

class _OwnerCustomersSection extends ConsumerWidget {
  const _OwnerCustomersSection({required this.owner});

  final Person owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(ownerLedgerProvider(owner.id));

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Customers under ${owner.name}', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          ledgerAsync.when(
            data: (ledger) {
              if (ledger.customers.isEmpty) {
                return const Text('No customers under this owner yet.');
              }
              return Column(
                children: ledger.customers
                    .map((c) => ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?')),
                          title: Text(c.name),
                          subtitle: Text(c.mobile ?? 'Customer'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => PersonLedgerScreen(person: c)),
                          ),
                        ))
                    .toList(),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Text('Failed to load: $e'),
          ),
        ],
      ),
    );
  }
}
