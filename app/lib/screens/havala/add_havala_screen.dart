import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/amount_input_formatter.dart';
import '../../core/utils/currency.dart';
import '../../models/havala.dart';
import '../../models/person.dart';
import '../../providers/havala_provider.dart';
import '../../providers/people_provider.dart';

class AddHavalaScreen extends ConsumerStatefulWidget {
  const AddHavalaScreen({super.key, this.editingHavala});

  final Havala? editingHavala;

  @override
  ConsumerState<AddHavalaScreen> createState() => _AddHavalaScreenState();
}

class _CustomerSplit {
  Person? customer;
  DateTime date = DateTime.now();
  final TextEditingController amountController = TextEditingController();

  void dispose() => amountController.dispose();
}

class _AddHavalaScreenState extends ConsumerState<AddHavalaScreen> {
  final _formKey = GlobalKey<FormState>();
  final _totalAmountController = TextEditingController();
  final _mobileController = TextEditingController();
  final _paidNowController = TextEditingController();
  Person? _selectedOwner;
  DateTime _date = DateTime.now();
  List<_CustomerSplit> _splits = [_CustomerSplit()];
  bool _saving = false;
  bool _initialized = false;

  bool get _isEditing => widget.editingHavala != null;

  void _prefillFromHavala(List<Person> people) {
    if (_initialized) return;
    final h = widget.editingHavala;
    if (h == null) return;
    _initialized = true;
    _selectedOwner = people.where((p) => p.id == h.ownerId).firstOrNull;
    _mobileController.text = _selectedOwner?.mobile ?? '';
    _totalAmountController.text = NumberFormat.decimalPattern('en_IN').format(h.totalAmount / 100);
    _paidNowController.text = NumberFormat.decimalPattern('en_IN').format(h.paidAmount / 100);
    _date = h.date;
    _splits = h.splits.map((s) {
      final split = _CustomerSplit();
      split.customer = people.where((p) => p.id == s.personId).firstOrNull;
      split.amountController.text = NumberFormat.decimalPattern('en_IN').format(s.amount / 100);
      split.date = s.date;
      return split;
    }).toList();
  }

  @override
  void dispose() {
    _totalAmountController.dispose();
    _mobileController.dispose();
    _paidNowController.dispose();
    for (final s in _splits) {
      s.dispose();
    }
    super.dispose();
  }

  void _addSplitRow() => setState(() => _splits.add(_CustomerSplit()..date = _date));

  void _removeSplitRow(int index) {
    setState(() {
      _splits[index].dispose();
      _splits.removeAt(index);
    });
  }

  int _splitsTotal() {
    var total = 0;
    for (final s in _splits) {
      final v = double.tryParse(s.amountController.text.replaceAll(',', ''));
      if (v != null) total += rupeesToPaise(v);
    }
    return total;
  }

  int _pendingAmountPreview() {
    final total = double.tryParse(_totalAmountController.text.replaceAll(',', ''));
    if (total == null) return 0;
    final paidNowText = _paidNowController.text.trim().replaceAll(',', '');
    final paidNow = paidNowText.isEmpty ? total : (double.tryParse(paidNowText) ?? total);
    final pending = rupeesToPaise(total) - rupeesToPaise(paidNow);
    return pending > 0 ? pending : 0;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedOwner == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select an owner')));
      return;
    }
    for (final s in _splits) {
      if (s.customer == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Select a customer for each row')));
        return;
      }
    }

    final totalAmount = rupeesToPaise(parseAmountInput(_totalAmountController.text));
    final splitsTotal = _splitsTotal();
    if (splitsTotal != totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Customer amounts (${formatRupees(splitsTotal)}) must add up to the total (${formatRupees(totalAmount)})')),
      );
      return;
    }

    final paidNowText = _paidNowController.text.trim();
    final paidNow = paidNowText.isEmpty ? totalAmount : rupeesToPaise(parseAmountInput(paidNowText));
    if (paidNow > totalAmount) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Amount paid now cannot exceed the total havala amount')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final splitsData = _splits
          .map((s) => {
                'personId': s.customer!.id,
                'amount': rupeesToPaise(parseAmountInput(s.amountController.text)),
                'date': '${s.date.year}-${s.date.month.toString().padLeft(2, '0')}-${s.date.day.toString().padLeft(2, '0')}',
              })
          .toList();

      if (_isEditing) {
        await ref.read(havalaListProvider.notifier).updateHavala(
              id: widget.editingHavala!.id,
              ownerId: _selectedOwner!.id,
              totalAmount: totalAmount,
              paidAmount: paidNow,
              date: _date,
              splits: splitsData,
            );
      } else {
        await ref.read(havalaListProvider.notifier).createHavala(
              ownerId: _selectedOwner!.id,
              totalAmount: totalAmount,
              paidAmount: paidNow,
              date: _date,
              splits: splitsData,
            );
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
    final peopleAsync = ref.watch(peopleProvider);

    return Scaffold(
      appBar: AppBar(title: Text(_isEditing ? 'Edit Havala' : 'New Havala')),
      body: peopleAsync.when(
        data: (people) {
          _prefillFromHavala(people);
          final owners = people.where((p) => p.isOwner).toList();
          final customers = people;

          return Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                DropdownButtonFormField<Person>(
                  initialValue: _selectedOwner,
                  decoration: const InputDecoration(labelText: 'Owner', border: OutlineInputBorder()),
                  items: owners.map((o) => DropdownMenuItem(value: o, child: Text(o.name))).toList(),
                  onChanged: (o) => setState(() {
                    _selectedOwner = o;
                    _mobileController.text = o?.mobile ?? '';
                  }),
                  validator: (v) => v == null ? 'Select an owner' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _mobileController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(labelText: 'Mobile Number', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _totalAmountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [AmountInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Total Havala Amount (₹)', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter the total amount';
                    final n = double.tryParse(v.replaceAll(',', ''));
                    if (n == null || n <= 0) return 'Enter a valid amount';
                    return null;
                  },
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
                TextFormField(
                  controller: _paidNowController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [AmountInputFormatter()],
                  decoration: const InputDecoration(
                    labelText: 'Amount Paid by Owner Now (₹)',
                    helperText: 'Leave blank if the owner is paying the full amount now. Enter less than the total if some is still pending.',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setState(() {}),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    final n = double.tryParse(v.replaceAll(',', ''));
                    if (n == null || n < 0) return 'Enter a valid amount';
                    return null;
                  },
                ),
                if (_pendingAmountPreview() > 0)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Pending from owner: ${formatRupees(_pendingAmountPreview())}',
                      style: TextStyle(color: Colors.orange.shade800, fontWeight: FontWeight.bold),
                    ),
                  ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Customers', style: Theme.of(context).textTheme.titleMedium),
                    IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: _addSplitRow),
                  ],
                ),
                for (var i = 0; i < _splits.length; i++) _buildSplitRow(context, customers, i),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _submit,
                  child: _saving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(_isEditing
                          ? 'Update Havala'
                          : (_pendingAmountPreview() > 0 ? 'Save Havala (Partial)' : 'Save Havala')),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load people: $e')),
      ),
    );
  }

  Widget _buildSplitRow(BuildContext context, List<Person> customers, int index) {
    final split = _splits[index];
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: DropdownButtonFormField<Person>(
                  initialValue: split.customer,
                  decoration: const InputDecoration(labelText: 'Customer', border: OutlineInputBorder()),
                  items: customers
                      .map((c) => DropdownMenuItem(
                            value: c,
                            child: Text(c.place != null ? '${c.name} (${c.place})' : c.name),
                          ))
                      .toList(),
                  onChanged: (c) => setState(() => split.customer = c),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: split.amountController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [AmountInputFormatter()],
                  decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder()),
                  onChanged: (_) => setState(() {}),
                ),
              ),
              if (_splits.length > 1)
                IconButton(
                  icon: const Icon(Icons.remove_circle_outline),
                  onPressed: () => _removeSplitRow(index),
                ),
            ],
          ),
          const SizedBox(height: 6),
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: split.date,
                firstDate: DateTime(2020),
                lastDate: DateTime(2100),
              );
              if (picked != null) setState(() => split.date = picked);
            },
            child: Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Theme.of(context).colorScheme.outline),
                const SizedBox(width: 6),
                Text(
                  'Payout date: ${split.date.day}/${split.date.month}/${split.date.year}',
                  style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.outline),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
