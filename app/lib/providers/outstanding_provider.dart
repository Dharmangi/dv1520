import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/outstanding_entry.dart';

// Family provider — takes date string so havala credits are for that specific date
final outstandingProvider =
    AsyncNotifierProviderFamily<OutstandingNotifier, OutstandingListResult, String>(OutstandingNotifier.new);

class OutstandingNotifier extends FamilyAsyncNotifier<OutstandingListResult, String> {
  @override
  Future<OutstandingListResult> build(String date) => _fetch(date);

  Future<OutstandingListResult> _fetch(String date) async {
    final res = await ApiClient.instance.dio.get('/outstanding', queryParameters: {'date': date});
    return OutstandingListResult.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> createEntry({
    String? personId,
    required String personName,
    required int totalAmount,
    String note = '',
    required DateTime createdDate,
  }) async {
    await ApiClient.instance.dio.post('/outstanding', data: {
      'personId': personId,
      'personName': personName,
      'totalAmount': totalAmount,
      'note': note,
      'createdDate': '${createdDate.year}-${createdDate.month.toString().padLeft(2, '0')}-${createdDate.day.toString().padLeft(2, '0')}',
    });
    ref.invalidateSelf();
    await future;
  }

  Future<OutstandingEntry> settleEntry({
    required String id,
    required int amount,
    required DateTime date,
    String note = '',
  }) async {
    final res = await ApiClient.instance.dio.post('/outstanding/$id/settle', data: {
      'amount': amount,
      'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'note': note,
    });
    ref.invalidateSelf();
    await future;
    return OutstandingEntry.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> deleteEntry(String id) async {
    await ApiClient.instance.dio.delete('/outstanding/$id');
    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

final outstandingHistoryProvider = FutureProvider<List<OutstandingEntry>>((ref) async {
  final res = await ApiClient.instance.dio.get('/outstanding/history');
  return (res.data as List).map((e) => OutstandingEntry.fromJson(e as Map<String, dynamic>)).toList();
});
