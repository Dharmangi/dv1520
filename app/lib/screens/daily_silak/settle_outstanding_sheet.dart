import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/amount_input_formatter.dart';
import '../../core/utils/currency.dart';
import '../../models/outstanding_entry.dart';
import '../../providers/outstanding_provider.dart';
import '../../providers/daily_silak_provider.dart';

class SettleOutstandingSheet extends ConsumerStatefulWidget {
  const SettleOutstandingSheet({super.key, required this.entry, required this.date});
  final OutstandingEntry entry;
  final String date;

  @override
  ConsumerState<SettleOutstandingSheet> createState() => _State();
}

class _State extends ConsumerState<SettleOutstandingSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    // Default to full pending amount
    _amountCtrl.text = NumberFormat.decimalPattern('en_IN').format(widget.entry.pendingAmount / 100);
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final amount = (parseAmountInput(_amountCtrl.text) * 100).round();

      // 1. Settle the outstanding entry
      await ref.read(outstandingProvider(widget.date).notifier).settleEntry(
            id: widget.entry.id,
            amount: amount,
            date: DateTime.parse(widget.date),
            note: _noteCtrl.text.trim(),
          );

      // 2. Also add a credit entry to today's silak
      await ref.read(dailySilakByDateProvider(widget.date).notifier).addEntry(
            personName: widget.entry.personName,
            personId: widget.entry.personId,
            amount: amount,
            type: 'received',
            note: _noteCtrl.text.trim().isNotEmpty ? _noteCtrl.text.trim() : 'Settlement received',
          );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.entry.personName} — ${formatRupees(amount)} settled ✓'),
            backgroundColor: Colors.green.shade700,
          ),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final entry = widget.entry;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text('Settle: ${entry.personName}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold))),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const SizedBox(height: 4),

            // Summary
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.red.shade50, borderRadius: BorderRadius.circular(8)),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(children: [
                    const Text('Total', style: TextStyle(fontSize: 11)),
                    Text(formatRupees(entry.totalAmount), style: const TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  Column(children: [
                    const Text('Settled', style: TextStyle(fontSize: 11)),
                    Text(formatRupees(entry.settledAmount), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green.shade700)),
                  ]),
                  Column(children: [
                    const Text('Remaining', style: TextStyle(fontSize: 11)),
                    Text(formatRupees(entry.pendingAmount), style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red.shade700)),
                  ]),
                ],
              ),
            ),
            const SizedBox(height: 14),

            TextFormField(
              controller: _amountCtrl,
              decoration: const InputDecoration(labelText: 'Settlement Amount (₹)', border: OutlineInputBorder(), prefixText: '₹ '),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [AmountInputFormatter()],
              validator: (v) {
                if (v == null || v.trim().isEmpty) return 'Required';
                final n = double.tryParse(v.replaceAll(',', ''));
                if (n == null || n <= 0) return 'Enter valid amount';
                final paise = (n * 100).round();
                if (paise > entry.pendingAmount) return 'Cannot exceed pending ${formatRupees(entry.pendingAmount)}';
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
            FilledButton.icon(
              onPressed: _saving ? null : _submit,
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
              icon: const Icon(Icons.check_circle_outline, color: Colors.white),
              label: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Mark as Settled → Move to Credit', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
