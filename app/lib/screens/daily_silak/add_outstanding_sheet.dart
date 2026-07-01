import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/amount_input_formatter.dart';
import '../../models/daily_silak.dart';
import '../../providers/daily_silak_provider.dart';
import '../../providers/outstanding_provider.dart';

class AddOutstandingSheet extends ConsumerStatefulWidget {
  const AddOutstandingSheet({super.key, required this.date, this.allowDateChange = false});
  final String date;
  final bool allowDateChange;

  @override
  ConsumerState<AddOutstandingSheet> createState() => _State();
}

class _State extends ConsumerState<AddOutstandingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  SilakPerson? _selectedPerson;
  String? _customName;
  String _searchQuery = '';
  bool _saving = false;
  late DateTime _selectedDate;

  bool get hasPersonSelected => _selectedPerson != null || (_customName != null && _customName!.isNotEmpty);

  @override
  void initState() {
    super.initState();
    _selectedDate = DateTime.parse(widget.date);
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!hasPersonSelected) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select or type a person name')));
      return;
    }
    setState(() => _saving = true);
    try {
      final amount = (parseAmountInput(_amountCtrl.text) * 100).round();
      final targetDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      await ref.read(outstandingProvider(targetDate).notifier).createEntry(
            personId: _selectedPerson?.id,
            personName: _selectedPerson?.name ?? _customName!,
            totalAmount: amount,
            note: _noteCtrl.text.trim(),
            createdDate: _selectedDate,
          );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final peopleAsync = ref.watch(silakPeopleProvider);

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Add Debit / Outstanding', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text('Carries forward daily until settled', style: TextStyle(fontSize: 12, color: Colors.red.shade700)),
                  ],
                )),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 8),

            if (widget.allowDateChange) ...[
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selectedDate,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                  );
                  if (picked != null) setState(() => _selectedDate = picked);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEFF6F9),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_month, size: 18, color: Color(0xFF5C7480)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          DateFormat('dd MMM yyyy, EEEE').format(_selectedDate),
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                      ),
                      const Icon(Icons.keyboard_arrow_down, size: 18, color: Color(0xFF5C7480)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Person selection
            if (hasPersonSelected)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.red.shade700)),
                child: Row(
                  children: [
                    Icon(Icons.person, color: Colors.red.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(_selectedPerson?.name ?? _customName ?? '', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700))),
                    IconButton(icon: const Icon(Icons.close, size: 18), onPressed: () => setState(() { _selectedPerson = null; _customName = null; })),
                  ],
                ),
              )
            else ...[
              TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  labelText: 'Search or type person name',
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: const Icon(Icons.clear), onPressed: () { _searchCtrl.clear(); setState(() => _searchQuery = ''); }) : null,
                ),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: 6),
              peopleAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
                data: (people) {
                  final filtered = _searchQuery.isEmpty ? people : people.where((p) => p.displayName.toLowerCase().contains(_searchQuery.toLowerCase())).toList();
                  final exactMatch = _searchQuery.isNotEmpty && people.any((p) => p.name.toLowerCase() == _searchQuery.toLowerCase());
                  return SizedBox(
                    height: 150,
                    child: ListView(
                      children: [
                        if (_searchQuery.trim().isNotEmpty && !exactMatch)
                          ListTile(
                            dense: true,
                            tileColor: Colors.red.shade50,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                            leading: CircleAvatar(radius: 14, backgroundColor: Colors.red.shade700, child: const Icon(Icons.add, size: 16, color: Colors.white)),
                            title: Text('Use "${_searchQuery.trim()}"', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700, fontSize: 13)),
                            onTap: () => setState(() { _customName = _searchQuery.trim(); _searchCtrl.clear(); _searchQuery = ''; }),
                          ),
                        ...filtered.map((p) => ListTile(
                          dense: true,
                          leading: CircleAvatar(radius: 14, child: Text(p.name[0].toUpperCase(), style: const TextStyle(fontSize: 12))),
                          title: Text(p.name, style: const TextStyle(fontSize: 13)),
                          subtitle: p.place != null ? Text(p.place!, style: const TextStyle(fontSize: 11)) : null,
                          onTap: () => setState(() { _selectedPerson = p; _customName = null; _searchCtrl.clear(); _searchQuery = ''; }),
                        )),
                      ],
                    ),
                  );
                },
              ),
            ],
            const SizedBox(height: 10),

            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: 'Amount (₹)', border: OutlineInputBorder(), prefixText: '₹ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [AmountInputFormatter()],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v.replaceAll(',', ''));
                if (n == null || n <= 0) return 'Enter valid amount';
                return null;
              },
            ),
            const SizedBox(height: 10),
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(labelText: 'Note (optional)', border: OutlineInputBorder()),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Add to Debit / Outstanding', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
