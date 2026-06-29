import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/havala.dart';
import 'dashboard_provider.dart';
import 'people_provider.dart';
import 'transactions_provider.dart';

final havalaListProvider = AsyncNotifierProvider<HavalaListNotifier, List<Havala>>(HavalaListNotifier.new);

class HavalaListNotifier extends AsyncNotifier<List<Havala>> {
  @override
  Future<List<Havala>> build() => _fetch();

  Future<List<Havala>> _fetch() async {
    final res = await ApiClient.instance.dio.get('/havala');
    return (res.data as List).map((e) => Havala.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> createHavala({
    required String ownerId,
    required int totalAmount,
    required int paidAmount,
    required DateTime date,
    required List<Map<String, dynamic>> splits,
  }) async {
    await ApiClient.instance.dio.post('/havala', data: {
      'ownerId': ownerId,
      'totalAmount': totalAmount,
      'paidAmount': paidAmount,
      'date': date.toIso8601String(),
      'splits': splits,
    });
    ref.invalidateSelf();
    ref.invalidate(dashboardProvider);
    ref.invalidate(transactionsProvider);
    ref.invalidate(peopleProvider);
    await future;
  }

  Future<void> settleHavala(String id, {required int amount, required DateTime date}) async {
    await ApiClient.instance.dio.patch('/havala/$id/settle', data: {
      'amount': amount,
      'date': date.toIso8601String(),
    });
    ref.invalidateSelf();
    ref.invalidate(dashboardProvider);
    ref.invalidate(transactionsProvider);
    await future;
  }

  Future<void> deleteHavala(String id) async {
    await ApiClient.instance.dio.delete('/havala/$id');
    ref.invalidateSelf();
    ref.invalidate(dashboardProvider);
    ref.invalidate(transactionsProvider);
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
