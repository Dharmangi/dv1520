import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/report.dart';

class DateRange {
  const DateRange({this.from, this.to});

  final DateTime? from;
  final DateTime? to;

  Map<String, dynamic> toQuery() => {
        if (from != null) 'from': from!.toIso8601String(),
        if (to != null) 'to': to!.toIso8601String(),
      };
}

final reportDateRangeProvider = StateProvider<DateRange>((ref) => const DateRange());

final rangeSummaryProvider = FutureProvider.autoDispose<RangeSummary>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final res = await ApiClient.instance.dio.get('/dashboard/range-summary', queryParameters: range.toQuery());
  return RangeSummary.fromJson(res.data as Map<String, dynamic>);
});

final byPersonReportProvider = FutureProvider.autoDispose<List<PersonReport>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final res = await ApiClient.instance.dio.get('/dashboard/by-person', queryParameters: range.toQuery());
  return (res.data as List).map((e) => PersonReport.fromJson(e as Map<String, dynamic>)).toList();
});

final byCategoryReportProvider = FutureProvider.autoDispose<List<CategoryReport>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final res = await ApiClient.instance.dio.get('/dashboard/by-category', queryParameters: range.toQuery());
  return (res.data as List).map((e) => CategoryReport.fromJson(e as Map<String, dynamic>)).toList();
});

final timeSeriesReportProvider = FutureProvider.autoDispose<List<TimeSeriesPoint>>((ref) async {
  final range = ref.watch(reportDateRangeProvider);
  final res = await ApiClient.instance.dio.get('/dashboard/time-series', queryParameters: range.toQuery());
  return (res.data as List).map((e) => TimeSeriesPoint.fromJson(e as Map<String, dynamic>)).toList();
});
