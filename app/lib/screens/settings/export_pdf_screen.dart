import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:intl/intl.dart';
import '../../models/person.dart';
import '../../models/statement_entry.dart';
import '../../providers/people_provider.dart';
import '../../providers/transactions_provider.dart';

final _pdfAmountFormat = NumberFormat.currency(locale: 'en_IN', symbol: 'Rs. ', decimalDigits: 0);
String _formatRupeesForPdf(int paise) => _pdfAmountFormat.format(paise / 100);

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
      final statement = await ref.read(personStatementProvider(_selectedPerson!.id).future);
      final txns = statement.entries.where((t) {
        if (_from != null && t.date.isBefore(_from!)) return false;
        if (_to != null && t.date.isAfter(_to!.add(const Duration(days: 1)))) return false;
        return true;
      }).toList()
        ..sort((a, b) => a.date.compareTo(b.date));

      final doc = _buildDocument(_selectedPerson!, txns, statement.pendingAmount);
      final bytes = await doc.save();
      if (mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => _PdfPreviewScreen(
              bytes: bytes,
              filename: '${_selectedPerson!.name.replaceAll(' ', '_')}_statement.pdf',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate PDF: $e')));
      }
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  pw.Document _buildDocument(Person person, List<StatementEntry> txns, int pendingAmount) {
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
                      _formatRupeesForPdf(t.amount),
                      t.paymentMode,
                      t.description,
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
              'Balance: ${_formatRupeesForPdf(balance)}',
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
          ),
          if (pendingAmount != 0)
            pw.Align(
              alignment: pw.Alignment.centerRight,
              child: pw.Text(
                'Pending: ${_formatRupeesForPdf(pendingAmount)}',
                style: pw.TextStyle(fontSize: 13, color: PdfColors.orange800, fontWeight: pw.FontWeight.bold),
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
              label: const Text('Generate PDF'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdfPreviewScreen extends StatefulWidget {
  const _PdfPreviewScreen({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;

  @override
  State<_PdfPreviewScreen> createState() => _PdfPreviewScreenState();
}

class _PdfPreviewScreenState extends State<_PdfPreviewScreen> {
  bool _downloading = false;

  Future<void> _download() async {
    setState(() => _downloading = true);
    try {
      final dir = await getExternalStorageDirectory();
      final path = '${dir!.path}/${widget.filename}';
      final file = File(path);
      await file.writeAsBytes(widget.bytes);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Saved to ${file.path}'),
            action: SnackBarAction(label: 'Open', onPressed: () => OpenFilex.open(path)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to save: $e')));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.filename),
        actions: [
          IconButton(
            icon: _downloading
                ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.download),
            tooltip: 'Download',
            onPressed: _downloading ? null : _download,
          ),
        ],
      ),
      body: PdfPreview(
        build: (format) => widget.bytes,
        initialPageFormat: PdfPageFormat.a4,
        canChangeOrientation: false,
        canChangePageFormat: false,
        pdfFileName: widget.filename,
      ),
    );
  }
}
