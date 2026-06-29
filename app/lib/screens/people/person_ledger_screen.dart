import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../models/person.dart';
import '../../models/transaction.dart';
import '../../providers/people_provider.dart';
import '../../providers/transactions_provider.dart';
import '../transactions/add_transaction_sheet.dart';

int _balanceOf(List<Txn> txns) => txns
    .where((t) => !t.isPending)
    .fold<int>(0, (sum, t) => sum + (t.type == 'received' ? t.amount : -t.amount));

class PersonLedgerScreen extends ConsumerWidget {
  const PersonLedgerScreen({super.key, required this.person});

  final Person person;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (person.isOwner) {
      return _OwnerLedgerView(owner: person);
    }

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
          final balance = _balanceOf(txns);

          return ListView(
            children: [
              _BalanceCard(label: 'Balance', amount: balance),
              if (txns.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No transactions with this person yet.')),
                )
              else
                ...txns.map((t) => _TransactionTile(
                      txn: t,
                      onLongPress: () => _handleTransactionLongPress(context, ref, person, t),
                    )),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load transactions: $e')),
      ),
    );
  }
}

Future<void> _handleTransactionLongPress(BuildContext context, WidgetRef ref, Person person, Txn txn) async {
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

class _OwnerLedgerView extends ConsumerWidget {
  const _OwnerLedgerView({required this.owner});

  final Person owner;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ledgerAsync = ref.watch(ownerLedgerProvider(owner.id));

    return Scaffold(
      appBar: AppBar(title: Text(owner.name)),
      floatingActionButton: FloatingActionButton(
        heroTag: 'ledger_fab',
        onPressed: () => showAddTransactionSheet(context, initialPerson: owner),
        child: const Icon(Icons.add),
      ),
      body: ledgerAsync.when(
        data: (ledger) {
          final ownTxns = ledger.transactions.where((t) => t.personId == owner.id).toList();
          final ownBalance = _balanceOf(ownTxns);
          final groupBalance = _balanceOf(ledger.transactions);

          return ListView(
            children: [
              _BalanceCard(label: "${owner.name}'s Balance", amount: ownBalance),
              _BalanceCard(label: 'Group Balance', amount: groupBalance, highlighted: true),
              const SizedBox(height: 8),
              if (ledger.transactions.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(child: Text('No transactions yet.')),
                )
              else
                ...ledger.transactions.map((t) => _TransactionTile(
                      txn: t,
                      showPersonName: true,
                      onLongPress: () => _handleTransactionLongPress(
                        context,
                        ref,
                        t.personId == owner.id ? owner : ledger.customers.firstWhere((c) => c.id == t.personId),
                        t,
                      ),
                    )),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Customers under ${owner.name}', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (ledger.customers.isEmpty)
                      const Text('No customers under this owner yet.')
                    else
                      ...ledger.customers.map((c) => ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: CircleAvatar(child: Text(c.name.isNotEmpty ? c.name[0].toUpperCase() : '?')),
                            title: Text(c.name),
                            subtitle: Text(c.mobile ?? 'Customer'),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => PersonLedgerScreen(person: c)),
                            ),
                          )),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load: $e')),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.label, required this.amount, this.highlighted = false});

  final String label;
  final int amount;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      color: highlighted ? Theme.of(context).colorScheme.primaryContainer : null,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(
              formatRupees(amount),
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn, this.showPersonName = false, this.onLongPress});

  final Txn txn;
  final bool showPersonName;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final subtitleParts = [
      if (showPersonName) txn.personName ?? 'Unknown',
      txn.description ?? txn.paymentMode,
      '${txn.date.day}/${txn.date.month}/${txn.date.year}',
    ];

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: txn.isPending
            ? Colors.orange.shade100
            : (txn.type == 'received' ? Colors.green.shade100 : Colors.red.shade100),
        child: Icon(
          txn.isPending
              ? Icons.hourglass_empty
              : (txn.type == 'received' ? Icons.arrow_downward : Icons.arrow_upward),
          color: txn.isPending ? Colors.orange.shade800 : (txn.type == 'received' ? Colors.green : Colors.red),
        ),
      ),
      title: Text(showPersonName ? (txn.personName ?? 'Unknown') : (txn.description ?? txn.paymentMode)),
      subtitle: Text(
        (txn.isPending ? 'Pending · ' : '') + subtitleParts.skip(showPersonName ? 1 : 0).join(' · '),
      ),
      trailing: Text(
        formatRupees(txn.amount),
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: txn.isPending ? Colors.orange.shade800 : (txn.type == 'received' ? Colors.green : Colors.red),
        ),
      ),
      onLongPress: txn.isPending ? null : onLongPress,
    );
  }
}
