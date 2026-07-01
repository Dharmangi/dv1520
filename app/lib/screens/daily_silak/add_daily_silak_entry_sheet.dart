import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/amount_input_formatter.dart';
import '../../models/daily_silak.dart';
import '../../providers/daily_silak_provider.dart';

class AddDailySilakEntrySheet extends ConsumerStatefulWidget {
  const AddDailySilakEntrySheet({
    super.key,
    required this.date,
    required this.initialType,
    this.editEntry,
    this.silakId,
    this.allowDateChange = false,
  });

  final String date;
  final String initialType;
  final DailySilakEntry? editEntry;
  final String? silakId;
  final bool allowDateChange;

  @override
  ConsumerState<AddDailySilakEntrySheet> createState() => _State();
}

class _State extends ConsumerState<AddDailySilakEntrySheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();

  late String _type;
  late DateTime _selectedDate;
  SilakPerson? _selectedPerson;  // existing person from DB
  String? _customName;           // manually typed new name
  bool _saving = false;
  String _searchQuery = '';

  bool get isEdit => widget.editEntry != null;
  bool get hasPersonSelected => _selectedPerson != null || (_customName != null && _customName!.isNotEmpty);
  String get selectedDisplayName => _selectedPerson?.displayName ?? _customName ?? '';

  @override
  void initState() {
    super.initState();
    _type = widget.initialType;
    _selectedDate = DateTime.parse(widget.date);
    if (isEdit) {
      final e = widget.editEntry!;
      _amountCtrl.text = NumberFormat.decimalPattern('en_IN').format(e.amount / 100);
      _noteCtrl.text = e.note;
      // Pre-fill name for edit
      _customName = e.personName;
    }
    _searchCtrl.addListener(() => setState(() => _searchQuery = _searchCtrl.text));
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _selectPerson(SilakPerson p) {
    setState(() {
      _selectedPerson = p;
      _customName = null;
      _searchCtrl.clear();
      _searchQuery = '';
    });
  }

  void _useCustomName(String name) {
    setState(() {
      _selectedPerson = null;
      _customName = name.trim();
      _searchCtrl.clear();
      _searchQuery = '';
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedPerson = null;
      _customName = null;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!hasPersonSelected && !isEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select or type a person name')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final amount = (parseAmountInput(_amountCtrl.text) * 100).round();
      final targetDate = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final personName = _selectedPerson?.name ?? _customName ?? widget.editEntry!.personName;
      final personId = _selectedPerson?.id;

      if (isEdit) {
        final dateChanged = targetDate != widget.date;
        if (dateChanged) {
          // Entry lives inside its day's document — moving days means
          // removing it from the old day and re-adding it under the new one.
          await ref.read(dailySilakByDateProvider(widget.date).notifier).removeEntry(widget.silakId!, widget.editEntry!.id);
          await ref.read(dailySilakByDateProvider(targetDate).notifier).addEntry(
                personId: personId,
                personName: personName,
                amount: amount,
                type: _type,
                note: _noteCtrl.text.trim(),
              );
        } else {
          await ref.read(dailySilakByDateProvider(targetDate).notifier).editEntry(
                silakId: widget.silakId!,
                entryId: widget.editEntry!.id,
                personId: personId,
                personName: personName,
                amount: amount,
                type: _type,
                note: _noteCtrl.text.trim(),
              );
        }
      } else {
        await ref.read(dailySilakByDateProvider(targetDate).notifier).addEntry(
              personId: personId,
              personName: personName,
              amount: amount,
              type: _type,
              note: _noteCtrl.text.trim(),
            );
      }
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
    final isReceived = _type == 'received';
    final typeColor = isReceived ? Colors.green.shade700 : Colors.red.shade700;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.88),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Row(
              children: [
                Expanded(
                  child: Text(
                    isEdit ? 'Edit Entry' : 'Add Entry',
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 8),

            // Date picker (shown when the caller allows changing the date)
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

            // Received / Paid toggle
            Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = 'received'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _type == 'received' ? Colors.green.shade700 : Colors.transparent,
                        border: Border.all(color: Colors.green.shade700),
                        borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_downward, size: 16, color: _type == 'received' ? Colors.white : Colors.green.shade700),
                          const SizedBox(width: 4),
                          Text('Received', style: TextStyle(color: _type == 'received' ? Colors.white : Colors.green.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    onTap: () => setState(() => _type = 'paid'),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      decoration: BoxDecoration(
                        color: _type == 'paid' ? Colors.red.shade700 : Colors.transparent,
                        border: Border.all(color: Colors.red.shade700),
                        borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_upward, size: 16, color: _type == 'paid' ? Colors.white : Colors.red.shade700),
                          const SizedBox(width: 4),
                          Text('Paid', style: TextStyle(color: _type == 'paid' ? Colors.white : Colors.red.shade700, fontWeight: FontWeight.bold)),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Person section
            if (!isEdit) ...[
              // Show selected person chip OR search box
              if (hasPersonSelected)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: typeColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: typeColor),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        _selectedPerson != null ? Icons.person : Icons.person_add,
                        color: typeColor,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedDisplayName,
                              style: TextStyle(fontWeight: FontWeight.bold, color: typeColor),
                            ),
                            if (_selectedPerson == null)
                              Text(
                                'New person (will be added as manual entry)',
                                style: TextStyle(fontSize: 11, color: typeColor.withValues(alpha: 0.7)),
                              ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, size: 18),
                        onPressed: _clearSelection,
                      ),
                    ],
                  ),
                )
              else ...[
                // Search field
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    labelText: 'Search or type new name',
                    hintText: 'e.g. Ramesh, Kano...',
                    border: const OutlineInputBorder(),
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                  ),
                  textCapitalization: TextCapitalization.words,
                ),
                const SizedBox(height: 6),
                // People list
                peopleAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (e, _) => Text('Error: $e'),
                  data: (people) {
                    final filtered = _searchQuery.isEmpty
                        ? people
                        : people
                            .where((p) => p.displayName.toLowerCase().contains(_searchQuery.toLowerCase()))
                            .toList();

                    // Check if search query exactly matches an existing person
                    final exactMatch = _searchQuery.isNotEmpty &&
                        people.any((p) => p.name.toLowerCase() == _searchQuery.toLowerCase());

                    return SizedBox(
                      height: 160,
                      child: ListView(
                        children: [
                          // "Create new" option — shown when typing and no exact match
                          if (_searchQuery.trim().isNotEmpty && !exactMatch)
                            ListTile(
                              dense: true,
                              tileColor: typeColor.withValues(alpha: 0.08),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: typeColor,
                                child: const Icon(Icons.add, size: 16, color: Colors.white),
                              ),
                              title: Text(
                                'Use "${_searchQuery.trim()}"',
                                style: TextStyle(fontWeight: FontWeight.bold, color: typeColor, fontSize: 13),
                              ),
                              subtitle: const Text('Add as new name (not saved to people list)', style: TextStyle(fontSize: 11)),
                              onTap: () => _useCustomName(_searchQuery.trim()),
                            ),
                          if (_searchQuery.trim().isNotEmpty && !exactMatch)
                            const Divider(height: 8),
                          // Existing people
                          ...filtered.map((p) {
                            return ListTile(
                              dense: true,
                              leading: CircleAvatar(
                                radius: 14,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                                child: Text(p.name[0].toUpperCase(), style: const TextStyle(fontSize: 12)),
                              ),
                              title: Text(p.name, style: const TextStyle(fontSize: 13)),
                              subtitle: p.place != null ? Text(p.place!, style: const TextStyle(fontSize: 11)) : null,
                              trailing: p.isOwner
                                  ? Chip(
                                      label: const Text('Owner', style: TextStyle(fontSize: 10)),
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                    )
                                  : null,
                              onTap: () => _selectPerson(p),
                            );
                          }),
                          if (filtered.isEmpty && _searchQuery.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No people found. Type a name above to add manually.', textAlign: TextAlign.center),
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 10),
            ],

            // Amount
            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(
                labelText: 'Amount (₹)',
                border: OutlineInputBorder(),
                prefixText: '₹ ',
              ),
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

            // Note
            TextFormField(
              controller: _noteCtrl,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                border: OutlineInputBorder(),
              ),
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 16),

            // Submit
            FilledButton(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: typeColor),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      isEdit ? 'Update Entry' : 'Add ${_type == 'received' ? 'Received' : 'Paid'} Entry',
                      style: const TextStyle(color: Colors.white),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
