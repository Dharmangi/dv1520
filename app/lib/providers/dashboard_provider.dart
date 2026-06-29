import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/dashboard_summary.dart';

final dashboardProvider = FutureProvider.autoDispose<DashboardSummary>((ref) async {
  final res = await ApiClient.instance.dio.get('/dashboard/summary');
  return DashboardSummary.fromJson(res.data as Map<String, dynamic>);
});
