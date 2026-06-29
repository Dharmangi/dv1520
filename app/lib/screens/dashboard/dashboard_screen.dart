import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../models/person.dart';
import '../../providers/dashboard_provider.dart';
import '../../providers/people_provider.dart';
import '../people/add_person_sheet.dart';
import '../people/person_ledger_screen.dart';
import '../transactions/add_transaction_sheet.dart';
import 'my_balance_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(dashboardProvider);
    final peopleAsync = ref.watch(peopleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('DV1520')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'dashboard_fab',
        onPressed: () => showAddTransactionSheet(context),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(dashboardProvider);
          await ref.read(peopleProvider.notifier).refresh();
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            summaryAsync.when(
              data: (summary) => _SummaryCards(summary: summary),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 40),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text('Failed to load dashboard: $e'),
              ),
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Owners', style: Theme.of(context).textTheme.titleMedium),
                IconButton(
                  icon: const Icon(Icons.person_add_outlined),
                  onPressed: () => showAddPersonSheet(context),
                ),
              ],
            ),
            peopleAsync.when(
              data: (people) {
                if (people.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Center(child: Text('No people yet. Tap + to add one.')),
                  );
                }
                final owners = people.where((p) => p.isOwner).toList();
                final others = people.where((p) => !p.isOwner && p.ownerId == null).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (owners.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 16),
                        child: Text('No owners yet.'),
                      )
                    else
                      ...owners.map((p) => _PersonRow(
                            person: p,
                            onLongPress: () => _handlePersonLongPress(context, ref, p),
                          )),
                    const SizedBox(height: 24),
                    Text('Other Customers', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    if (others.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 8),
                        child: Text('No other customers.'),
                      )
                    else
                      ...others.map((p) => _PersonRow(
                            person: p,
                            onLongPress: () => _handlePersonLongPress(context, ref, p),
                          )),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Text('Failed to load customers: $e'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePersonLongPress(BuildContext context, WidgetRef ref, Person person) async {
    final choice = await showEditDeleteMenu(context);
    if (choice == 'edit') {
      if (context.mounted) showAddPersonSheet(context, existing: person);
    } else if (choice == 'delete') {
      if (!context.mounted) return;
      final confirmed = await confirmDelete(context, message: 'Delete ${person.name}? Their transaction history will remain but the customer will be removed.');
      if (confirmed) {
        await ref.read(peopleProvider.notifier).deletePerson(person.id);
      }
    }
  }
}

class _PersonRow extends StatelessWidget {
  const _PersonRow({required this.person, required this.onLongPress});

  final Person person;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        child: Icon(person.isOwner ? Icons.account_balance_outlined : Icons.person_outline),
      ),
      title: Text(person.name, style: person.isOwner ? const TextStyle(fontWeight: FontWeight.bold) : null),
      subtitle: Text(person.mobile ?? (person.isOwner ? 'Owner' : 'Customer')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => PersonLedgerScreen(person: person)),
      ),
      onLongPress: onLongPress,
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.summary});

  final dynamic summary;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Card(
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MyBalanceScreen()),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('My Balance', style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        Text(
                          formatRupees(summary.myBalance),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          color: Theme.of(context).colorScheme.primaryContainer,
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Current Balance', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text(
                  formatRupees(summary.currentBalance),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: "Today's Income", value: summary.todayIncome, color: Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: "Today's Expense", value: summary.todayExpense, color: Colors.red)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _StatCard(label: 'Monthly Income', value: summary.monthlyIncome, color: Colors.green)),
            const SizedBox(width: 12),
            Expanded(child: _StatCard(label: 'Monthly Expense', value: summary.monthlyExpense, color: Colors.red)),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Text(
              formatRupees(value),
              style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
