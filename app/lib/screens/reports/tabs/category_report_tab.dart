import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/currency.dart';
import '../../../providers/reports_provider.dart';

class CategoryReportTab extends ConsumerWidget {
  const CategoryReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reportAsync = ref.watch(byCategoryReportProvider);

    return reportAsync.when(
      data: (rows) {
        if (rows.isEmpty) {
          return const Center(child: Text('No categorized transactions in this period'));
        }
        return ListView.builder(
          itemCount: rows.length,
          itemBuilder: (context, index) {
            final row = rows[index];
            return ListTile(
              leading: Icon(
                row.categoryType == 'income' ? Icons.arrow_downward : Icons.arrow_upward,
                color: row.categoryType == 'income' ? Colors.green : Colors.red,
              ),
              title: Text(row.categoryName),
              trailing: Text(
                formatRupees(row.total),
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: row.categoryType == 'income' ? Colors.green : Colors.red,
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
