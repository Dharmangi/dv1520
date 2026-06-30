import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../core/utils/currency.dart';
import '../../providers/daily_silak_provider.dart';
import 'daily_silak_detail_screen.dart';

class DailySilakListScreen extends ConsumerWidget {
  const DailySilakListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncList = ref.watch(dailySilakListProvider);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Silak'),
        actions: [
          IconButton(
            icon: const Icon(Icons.today),
            tooltip: 'Open Today',
            onPressed: () => _openDate(context, today),
          ),
        ],
      ),
      body: asyncList.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.book_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 12),
                  const Text('No daily silak records yet.', style: TextStyle(fontSize: 16)),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => _openDate(context, today),
                    icon: const Icon(Icons.add),
                    label: const Text("Open Today's Silak"),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => ref.read(dailySilakListProvider.notifier).refresh(),
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final item = list[i];
                final dateStr = DateFormat('yyyy-MM-dd').format(item.date);
                final displayDate = DateFormat('dd MMM yyyy, EEEE').format(item.date);
                final isToday = dateStr == today;

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: isToday
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.surfaceContainerHighest,
                      child: Text(
                        DateFormat('dd').format(item.date),
                        style: TextStyle(
                          color: isToday
                              ? Theme.of(context).colorScheme.onPrimary
                              : Theme.of(context).colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    title: Text(
                      isToday ? '$displayDate  •  Today' : displayDate,
                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text('${item.entryCount} entries'),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          formatRupees(item.netBalance),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                            color: item.netBalance >= 0 ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                        Text('net', style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.outline)),
                      ],
                    ),
                    onTap: () => _openDate(context, dateStr),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _pickAndOpenDate(context),
        icon: const Icon(Icons.calendar_month),
        label: const Text('Pick Date'),
      ),
    );
  }

  void _openDate(BuildContext context, String date) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => DailySilakDetailScreen(date: date)),
    );
  }

  Future<void> _pickAndOpenDate(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && context.mounted) {
      final dateStr = DateFormat('yyyy-MM-dd').format(picked);
      _openDate(context, dateStr);
    }
  }
}
