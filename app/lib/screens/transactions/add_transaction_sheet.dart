import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/utils/currency.dart';
import '../../models/category.dart';
import '../../models/person.dart';
import '../../models/transaction.dart';
import '../../providers/categories_provider.dart';
import '../../providers/people_provider.dart';
import '../../providers/transactions_provider.dart';

Future<void> showAddTransactionSheet(BuildContext context, {Person? initialPerson, Txn? existing}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => AddTransactionSheet(initialPerson: initialPerson, existing: existing),
  );
}

class AddTransactionSheet extends ConsumerStatefulWidget {
  const AddTransactionSheet({super.key, this.initialPerson, this.existing});

  final Person? initialPerson;
  final Txn? existing;

  @override
  ConsumerState<AddTransactionSheet> createState() => _AddTransactionSheetState();
}

class _AddTransactionSheetState extends ConsumerState<AddTransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _descriptionController;

  late String _type;
  late String _paymentMode;
  Person? _selectedPerson;
  Category? _selectedCategory;
  late DateTime _date;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _selectedPerson = widget.initialPerson;
    _type = existing?.type ?? 'received';
    _paymentMode = existing?.paymentMode ?? 'cash';
    _date = existing?.date ?? DateTime.now();
    _amountController = TextEditingController(
      text: existing != null ? (existing.amount / 100).toStringAsFixed(2) : '',
    );
    _descriptionController = TextEditingController(text: existing?.description ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate() || _selectedPerson == null) {
      if (_selectedPerson == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a person')),
        );
      }
      return;
    }

    setState(() => _saving = true);
    try {
      final amount = rupeesToPaise(double.parse(_amountController.text));
      final description = _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim();
      if (widget.existing != null) {
        final updated = Txn(
          id: widget.existing!.id,
          clientUuid: widget.existing!.clientUuid,
          personId: _selectedPerson!.id,
          type: _type,
          amount: amount,
          paymentMode: _paymentMode,
          description: description,
          date: _date,
          categoryId: _selectedCategory?.id,
        );
        await ref.read(transactionsProvider.notifier).updateTransaction(updated);
      } else {
        await ref.read(transactionsProvider.notifier).addTransaction(
              personId: _selectedPerson!.id,
              type: _type,
              amount: amount,
              paymentMode: _paymentMode,
              description: description,
              date: _date,
              categoryId: _selectedCategory?.id,
            );
      }
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleProvider);
    final categoriesAsync = ref.watch(categoriesProvider);
    final categoryType = _type == 'received' ? 'income' : 'expense';

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: 20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(widget.existing != null ? 'Edit Transaction' : 'Add Transaction', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 16),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'received', label: Text('Received'), icon: Icon(Icons.arrow_downward)),
                  ButtonSegment(value: 'paid', label: Text('Paid'), icon: Icon(Icons.arrow_upward)),
                ],
                selected: {_type},
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  _selectedCategory = null;
                }),
              ),
              const SizedBox(height: 16),
              peopleAsync.when(
                data: (people) => DropdownButtonFormField<Person>(
                  initialValue: _selectedPerson,
                  decoration: const InputDecoration(labelText: 'Person', border: OutlineInputBorder()),
                  items: people
                      .map((p) => DropdownMenuItem(value: p, child: Text(p.name)))
                      .toList(),
                  onChanged: (p) => setState(() => _selectedPerson = p),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Failed to load people: $e'),
              ),
              const SizedBox(height: 16),
              categoriesAsync.when(
                data: (categories) {
                  final filtered = categories.where((c) => c.type == categoryType).toList();
                  if (_selectedCategory == null && widget.existing?.categoryId != null) {
                    final matches = filtered.where((c) => c.id == widget.existing!.categoryId);
                    _selectedCategory = matches.isEmpty ? null : matches.first;
                  } else if (filtered.isNotEmpty && filtered.contains(_selectedCategory) == false) {
                    _selectedCategory = null;
                  }
                  return DropdownButtonFormField<Category>(
                    initialValue: _selectedCategory,
                    decoration: const InputDecoration(labelText: 'Category (optional)', border: OutlineInputBorder()),
                    items: filtered
                        .map((c) => DropdownMenuItem(value: c, child: Text(c.name)))
                        .toList(),
                    onChanged: (c) => setState(() => _selectedCategory = c),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const SizedBox.shrink(),
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
              DropdownButtonFormField<String>(
                initialValue: _paymentMode,
                decoration: const InputDecoration(labelText: 'Payment Mode', border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'bank', child: Text('Bank')),
                  DropdownMenuItem(value: 'upi', child: Text('UPI')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setState(() => _paymentMode = v!),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder()),
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
      ),
    );
  }
}
