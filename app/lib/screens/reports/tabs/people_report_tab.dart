import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency.dart';
import '../../../providers/reports_provider.dart';

class PeopleReportTab extends ConsumerWidget {
  const PeopleReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(byPersonReportProvider);

    return reportAsync.when(
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No transactions in this period'));
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return ListTile(
              title: Text(row.personName),
              subtitle: Text('Received ${formatRupees(row.received)} · Paid ${formatRupees(row.paid)}'),
              trailing: Text(
                formatRupees(row.net),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: row.net >= 0 ? Colors.green : Colors.red,
                ),
              ),
            );
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load report: $e')),
    );
  }
}
