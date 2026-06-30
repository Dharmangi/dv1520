import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency.dart';
import '../../core/widgets/confirm_delete_dialog.dart';
import '../../models/havala.dart';
import '../../providers/havala_provider.dart';
import 'add_havala_screen.dart';
import 'havala_detail_screen.dart';

class HavalaListScreen extends ConsumerWidget {
  const HavalaListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final havalasAsync = ref.watch(havalaListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Havala')),
      floatingActionButton: FloatingActionButton(
        heroTag: 'havala_fab',
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const AddHavalaScreen()),
        ),
        child: const Icon(Icons.add),
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.read(havalaListProvider.notifier).refresh(),
        child: havalasAsync.when(
          data: (havalas) {
            if (havalas.isEmpty) {
              return const Center(child: Text('No havalas yet. Tap + to add one.'));
            }
            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: havalas.length,
              itemBuilder: (context, index) => _HavalaCard(
                havala: havalas[index],
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => HavalaDetailScreen(havala: havalas[index])),
                ),
                onLongPress: () => _handleLongPress(context, ref, havalas[index]),
                onSettle: () => _showSettleSheet(context, ref, havalas[index]),
                onEdit: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => AddHavalaScreen(editingHavala: havalas[index])),
                ),
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Failed to load havalas: $e')),
        ),
      ),
    );
  }

  Future<void> _handleLongPress(BuildContext context, WidgetRef ref, Havala havala) async {
    final confirmed = await confirmDelete(
      context,
      message: 'Delete this havala? All related transactions will be removed.',
    );
    if (confirmed) {
      await ref.read(havalaListProvider.notifier).deleteHavala(havala.id);
    }
  }

  Future<void> _showSettleSheet(BuildContext context, WidgetRef ref, Havala havala) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _SettleHavalaSheet(havala: havala),
    );
  }
}

class _SettleHavalaSheet extends ConsumerStatefulWidget {
  const _SettleHavalaSheet({required this.havala});

  final Havala havala;

  @override
  ConsumerState<_SettleHavalaSheet> createState() => _SettleHavalaSheetState();
}

class _SettleHavalaSheetState extends ConsumerState<_SettleHavalaSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _receivedViaController = TextEditingController();
  DateTime _date = DateTime.now();
  bool _saving = false;

  @override
  void dispose() {
    _amountController.dispose();
    _receivedViaController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = rupeesToPaise(double.parse(_amountController.text));
      await ref.read(havalaListProvider.notifier).settleHavala(
            widget.havala.id,
            amount: amount,
            date: _date,
            receivedVia: _receivedViaController.text.trim().isEmpty ? null : _receivedViaController.text.trim(),
          );
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to settle: $e')));
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
            Text('Settle Havala', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            Text('Pending from ${widget.havala.ownerName ?? "owner"}: ${formatRupees(widget.havala.pendingAmount)}'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _amountController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount Paid Now (₹)', border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.isEmpty) return 'Enter an amount';
                final value = double.tryParse(v);
                if (value == null || value <= 0) return 'Enter a valid amount';
                if (rupeesToPaise(value) > widget.havala.pendingAmount) return 'Cannot exceed pending amount';
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _receivedViaController,
              decoration: const InputDecoration(
                labelText: 'Received Via (e.g. branch/location name)',
                border: OutlineInputBorder(),
              ),
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
                  : const Text('Settle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _HavalaCard extends StatelessWidget {
  const _HavalaCard({
    required this.havala,
    required this.onTap,
    required this.onLongPress,
    required this.onSettle,
    required this.onEdit,
  });

  final Havala havala;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onSettle;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      havala.ownerName ?? 'Unknown Owner',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text('${havala.date.day}/${havala.date.month}/${havala.date.year}'),
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    visualDensity: VisualDensity.compact,
                    onPressed: onEdit,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _AmountLabel(label: 'Total', amount: havala.totalAmount, color: Colors.black87),
                  ),
                  Expanded(
                    child: _AmountLabel(label: 'Paid', amount: havala.paidAmount, color: Colors.green),
                  ),
                  Expanded(
                    child: _AmountLabel(
                      label: 'Pending',
                      amount: havala.pendingAmount,
                      color: havala.pendingAmount > 0 ? Colors.orange.shade800 : Colors.grey,
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text('Customers', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              ...havala.splits.map((s) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(s.personPlace != null ? '${s.personName} (${s.personPlace})' : s.personName ?? 'Unknown'),
                        Text(formatRupees(s.amount), style: const TextStyle(fontWeight: FontWeight.w600)),
                      ],
                    ),
                  )),
              if (havala.pendingAmount > 0) ...[
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    onPressed: onSettle,
                    icon: const Icon(Icons.payments_outlined),
                    label: const Text('Settle'),
                  ),
                ),
              ],
            ],
          ),
        ),
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
