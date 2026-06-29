import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/network/api_client.dart';
import '../models/capital_entry.dart';
import 'dashboard_provider.dart';

const _uuid = Uuid();

final capitalEntriesProvider = AsyncNotifierProvider<CapitalEntriesNotifier, List<CapitalEntry>>(
  CapitalEntriesNotifier.new,
);

class CapitalEntriesNotifier extends AsyncNotifier<List<CapitalEntry>> {
  @override
  Future<List<CapitalEntry>> build() => _fetch();

  Future<List<CapitalEntry>> _fetch() async {
    final res = await ApiClient.instance.dio.get('/capital-entries');
    return (res.data as List).map((e) => CapitalEntry.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addEntry({required int amount, String? note, required DateTime date}) async {
    final entry = CapitalEntry(id: '', clientUuid: _uuid.v4(), amount: amount, note: note, date: date);
    await ApiClient.instance.dio.post('/capital-entries', data: entry.toJson());
    ref.invalidateSelf();
    ref.invalidate(dashboardProvider);
    await future;
  }

  Future<void> updateEntry(String id, {required int amount, String? note, required DateTime date}) async {
    final entry = CapitalEntry(id: id, clientUuid: '', amount: amount, note: note, date: date);
    await ApiClient.instance.dio.put('/capital-entries/$id', data: entry.toJson()..remove('clientUuid'));
    ref.invalidateSelf();
    ref.invalidate(dashboardProvider);
    await future;
  }

  Future<void> deleteEntry(String id) async {
    await ApiClient.instance.dio.delete('/capital-entries/$id');
    ref.invalidateSelf();
    ref.invalidate(dashboardProvider);
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
