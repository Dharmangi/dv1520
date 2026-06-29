import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../models/capital_entry.dart';
import '../../providers/capital_entries_provider.dart';

class MyBalanceScreen extends ConsumerWidget {
  const MyBalanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final entriesAsync = ref.watch(capitalEntriesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Balance')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'my_balance_fab',
        onPressed: () => _showAddEntrySheet(context),
        child: const Icon(Icons.add),
      ),
      body: entriesAsync.when(
        data: (entries) {
          if (entries.isEmpty) {
            return const Center(child: Text('No balance entries yet. Tap + to add one.'));
          }
          final total = entries.fold<int>(0, (sum, e) => sum + e.amount);
          return Column(
            children: [
              Card(
                margin: const EdgeInsets.all(16),
                color: Theme.of(context).colorScheme.primaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Total', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 8),
                      Text(
                        formatRupees(total),
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return ListTile(
                      leading: Icon(
                        entry.amount >= 0 ? Icons.add_circle_outline : Icons.remove_circle_outline,
                        color: entry.amount >= 0 ? Colors.green : Colors.red,
                      ),
                      title: Text(entry.note ?? 'Balance entry'),
                      subtitle: Text('${entry.date.day}/${entry.date.month}/${entry.date.year}'),
                      trailing: Text(
                        formatRupees(entry.amount),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: entry.amount >= 0 ? Colors.green : Colors.red,
                        ),
                      ),
                      onLongPress: () => _handleEntryLongPress(context, ref, entry),
                    );
                  },
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

  Future<void> _showAddEntrySheet(BuildContext context, {CapitalEntry? existing}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AddCapitalEntrySheet(existing: existing),
    );
  }

  Future<void> _handleEntryLongPress(BuildContext context, WidgetRef ref, CapitalEntry entry) async {
    final choice = await showEditDeleteMenu(context);
    if (choice == 'edit') {
      if (context.mounted) _showAddEntrySheet(context, existing: entry);
    } else if (choice == 'delete') {
      if (!context.mounted) return;
      final confirmed = await confirmDelete(context, message: 'Delete this balance entry?');
      if (confirmed) {
        await ref.read(capitalEntriesProvider.notifier).deleteEntry(entry.id);
      }
    }
  }
}

class _AddCapitalEntrySheet extends ConsumerStatefulWidget {
  const _AddCapitalEntrySheet({this.existing});

  final CapitalEntry? existing;

  @override
  ConsumerState<_AddCapitalEntrySheet> createState() => _AddCapitalEntrySheetState();
}

class _AddCapitalEntrySheetState extends ConsumerState<_AddCapitalEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;
  late String _sign;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _sign = (existing != null && existing.amount < 0) ? 'subtract' : 'add';
    _date = existing?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: existing != null ? (existing.amount.abs() / 100).toStringAsFixed(2) : '',
    );
    _noteController = TextEditingController(text: existing?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      var amount = rupeesToPaise(double.parse(_amountController.text));
      if (_sign == 'subtract') amount = -amount;
      final note = _noteController.text.trim().isEmpty ? null : _noteController.text.trim();
      if (widget.existing != null) {
        await ref.read(capitalEntriesProvider.notifier).updateEntry(
              widget.existing!.id,
              amount: amount,
              note: note,
              date: _date,
            );
      } else {
        await ref.read(capitalEntriesProvider.notifier).addEntry(amount: amount, note: note, date: _date);
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.existing != null ? 'Edit Balance Entry' : 'Add Balance Entry', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'add', label: Text('Add'), icon: Icon(Icons.add)),
                ButtonSegment(value: 'subtract', label: Text('Subtract'), icon: Icon(Icons.remove)),
              ],
              selected: {_sign},
              onSelectionChanged: (s) => setState(() => _sign = s.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter an amount';
                if (double.tryParse(v) == null || double.parse(v) <= 0) return 'Enter a valid amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 16),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text('Date: ${_date.day}/${_date.month}/${_date.year}'),
              trailing: const Icon(Icons.calendar_today),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _date = picked);
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
