import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../providers/reports_provider.dart';

class ChartReportTab extends ConsumerWidget {
  const ChartReportTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final seriesAsync = ref.watch(timeSeriesReportProvider);

    return seriesAsync.when(
      data: (points) {
        if (points.isEmpty) {
          return const Center(child: Text('No transactions in this period'));
        }

        final maxY = points
            .map((p) => p.received > p.paid ? p.received : p.paid)
            .reduce((a, b) => a > b ? a : b)
            .toDouble();

        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: const [
                  _LegendDot(color: Colors.green, label: 'Received'),
                  SizedBox(width: 16),
                  _LegendDot(color: Colors.red, label: 'Paid'),
                ],
              ),
              const SizedBox(height: 16),
              Expanded(
                child: BarChart(
                  BarChartData(
                    maxY: maxY == 0 ? 1 : maxY * 1.1,
                    barGroups: [
                      for (var i = 0; i < points.length; i++)
                        BarChartGroupData(
                          x: i,
                          barRods: [
                            BarChartRodData(toY: points[i].received.toDouble(), color: Colors.green, width: 6),
                            BarChartRodData(toY: points[i].paid.toDouble(), color: Colors.red, width: 6),
                          ],
                        ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, meta) {
                            final i = value.toInt();
                            if (i < 0 || i >= points.length) return const SizedBox.shrink();
                            final d = points[i].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text('${d.day}/${d.month}', style: const TextStyle(fontSize: 9)),
                            );
                          },
                        ),
                      ),
                      leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 40)),
                      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: false),
                    gridData: const FlGridData(show: true),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('Failed to load chart: $e')),
    );
  }
}

class _LegendDot extends StatelessWidget {
  const _LegendDot({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label),
      ],
    );
  }
}
