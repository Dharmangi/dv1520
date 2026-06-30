import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/daily_silak.dart';

// All people for quick selection in entry sheet
final silakPeopleProvider = FutureProvider<List<SilakPerson>>((ref) async {
  final res = await ApiClient.instance.dio.get('/daily-silak/people');
  return (res.data as List).map((e) => SilakPerson.fromJson(e as Map<String, dynamic>)).toList();
});

// List of all silak date summaries
final dailySilakListProvider =
    AsyncNotifierProvider<DailySilakListNotifier, List<DailySilakSummary>>(DailySilakListNotifier.new);

class DailySilakListNotifier extends AsyncNotifier<List<DailySilakSummary>> {
  @override
  Future<List<DailySilakSummary>> build() => _fetch();

  Future<List<DailySilakSummary>> _fetch() async {
    final res = await ApiClient.instance.dio.get('/daily-silak');
    return (res.data as List)
        .map((e) => DailySilakSummary.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}

// Provider for a specific date's silak detail
final dailySilakByDateProvider =
    AsyncNotifierProviderFamily<DailySilakByDateNotifier, DailySilak, String>(
        DailySilakByDateNotifier.new);

class DailySilakByDateNotifier extends FamilyAsyncNotifier<DailySilak, String> {
  @override
  Future<DailySilak> build(String date) => _fetch(date);

  Future<DailySilak> _fetch(String date) async {
    final res = await ApiClient.instance.dio
        .get('/daily-silak/by-date', queryParameters: {'date': date});
    return DailySilak.fromJson(res.data as Map<String, dynamic>);
  }

  Future<void> addEntry({
    String? personId,
    required String personName,
    required int amount,
    required String type,
    String note = '',
  }) async {
    await ApiClient.instance.dio.post('/daily-silak/entry', data: {
      'date': arg,
      'personId': personId,
      'personName': personName,
      'amount': amount,
      'type': type,
      'note': note,
    });
    ref.invalidateSelf();
    ref.invalidate(dailySilakListProvider);
    await future;
  }

  Future<void> editEntry({
    required String silakId,
    required String entryId,
    String? personId,
    String? personName,
    int? amount,
    String? type,
    String? note,
  }) async {
    await ApiClient.instance.dio.put('/daily-silak/$silakId/entry/$entryId', data: {
      'personId': personId,
      'personName': personName,
      'amount': amount,
      'type': type,
      'note': note,
    });
    ref.invalidateSelf();
    ref.invalidate(dailySilakListProvider);
    await future;
  }

  Future<void> removeEntry(String silakId, String entryId) async {
    await ApiClient.instance.dio.delete('/daily-silak/$silakId/entry/$entryId');
    ref.invalidateSelf();
    ref.invalidate(dailySilakListProvider);
    await future;
  }

  Future<void> sync() async {
    await ApiClient.instance.dio.post('/daily-silak/$arg/sync');
    ref.invalidateSelf();
    ref.invalidate(dailySilakListProvider);
    await future;
  }
}
