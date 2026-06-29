import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../../core/utils/currency.dart';
import '../../models/person.dart';
import '../../models/transaction.dart';
import '../../providers/people_provider.dart';
import '../../providers/transactions_provider.dart';

class ExportPdfScreen extends ConsumerStatefulWidget {
  const ExportPdfScreen({super.key});

  @override
  ConsumerState<ExportPdfScreen> createState() => _ExportPdfScreenState();
}

class _ExportPdfScreenState extends ConsumerState<ExportPdfScreen> {
  Person? _selectedPerson;
  DateTime? _from;
  DateTime? _to;
  bool _generating = false;

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _from : _to) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _from = picked;
        } else {
          _to = picked;
        }
      });
    }
  }

  Future<void> _generate() async {
    if (_selectedPerson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Select a customer first')),
      );
      return;
    }

    setState(() => _generating = true);
    try {
      final allTxns = await ref.read(personTransactionsProvider(_selectedPerson!.id).future);
      final txns = allTxns.where((t) {
        if (_from != null && t.date.isBefore(_from!)) return false;
        if (_to != null && t.date.isAfter(_to!.add(const Duration(days: 1)))) return false;
        return true;
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final doc = _buildDocument(_selectedPerson!, txns);
      await Printing.sharePdf(
        bytes: await doc.save(),
        filename: '${_selectedPerson!.name.replaceAll(' ', '_')}_statement.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  pw.Document _buildDocument(Person person, List<Txn> txns) {
    final doc = pw.Document();
    final balance = txns.fold<int>(0, (sum, t) => sum + (t.type == 'received' ? t.amount : -t.amount));

    doc.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Text(person.name, style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold)),
          if (person.mobile != null) pw.Text(person.mobile!),
          pw.SizedBox(height: 4),
          pw.Text(
            'Statement period: ${_from != null ? _formatDate(_from!) : 'All time'} - ${_to != null ? _formatDate(_to!) : 'Now'}',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 16),
          pw.Table.fromTextArray(
            headers: ['Date', 'Type', 'Amount', 'Mode', 'Description'],
            data: txns
                .map((t) => [
                      _formatDate(t.date),
                      t.type == 'received' ? 'Received' : 'Paid',
                      formatRupees(t.amount),
                      t.paymentMode,
                      t.description ?? '',
                    ])
                .toList(),
            headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            cellAlignment: pw.Alignment.centerLeft,
          ),
          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text(
              'Balance: ${formatRupees(balance)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return doc;
  }

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  @override
  Widget build(BuildContext context) {
    final peopleAsync = ref.watch(peopleProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Export Customer Statement')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            peopleAsync.when(
              data: (people) => DropdownButtonFormField<Person>(
                initialValue: _selectedPerson,
                decoration: const InputDecoration(labelText: 'Customer', border: OutlineInputBorder()),
                items: people.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                onChanged: (p) => setState(() => _selectedPerson = p),
              ),
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Failed to load customers: $e'),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('From'),
                    subtitle: Text(_from != null ? _formatDate(_from!) : 'All time'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _pickDate(isFrom: true),
                  ),
                ),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('To'),
                    subtitle: Text(_to != null ? _formatDate(_to!) : 'Now'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () => _pickDate(isFrom: false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _generating ? null : _generate,
              icon: _generating
                  ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.picture_as_pdf),
              label: const Text('Generate & Share PDF'),
            ),
          ],
        ),
      ),
    );
  }
}
