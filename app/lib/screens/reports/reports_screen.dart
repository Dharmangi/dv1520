import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/reports_provider.dart';
import 'tabs/category_report_tab.dart';
import 'tabs/chart_report_tab.dart';
import 'tabs/people_report_tab.dart';
import 'tabs/summary_report_tab.dart';

class ReportsScreen extends ConsumerWidget {
  const ReportsScreen({super.key});

  String _formatDate(DateTime d) => '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';

  Future<void> _pickRange(BuildContext context, WidgetRef ref) async {
    final current = ref.read(reportDateRangeProvider);
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      initialDateRange: current.from != null && current.to != null
          ? DateTimeRange(start: current.from!, end: current.to!)
          : null,
    );
    if (picked != null) {
      ref.read(reportDateRangeProvider.notifier).state = DateRange(from: picked.start, to: picked.end);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final range = ref.watch(reportDateRangeProvider);

    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Reports'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Summary'),
              Tab(text: 'People'),
              Tab(text: 'Categories'),
              Tab(text: 'Chart'),
            ],
          ),
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      range.from != null && range.to != null
                          ? '${_formatDate(range.from!)} - ${_formatDate(range.to!)}'
                          : 'All time',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _pickRange(context, ref),
                    icon: const Icon(Icons.date_range),
                    label: const Text('Filter'),
                  ),
                  if (range.from != null || range.to != null)
                    IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () => ref.read(reportDateRangeProvider.notifier).state = const DateRange(),
                    ),
                ],
              ),
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  SummaryReportTab(),
                  PeopleReportTab(),
                  CategoryReportTab(),
                  ChartReportTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
