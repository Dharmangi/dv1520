import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/transaction.dart';

final transactionsProvider =
    AsyncNotifierProvider<TransactionsNotifier, List<Txn>>(TransactionsNotifier.new);

final personTransactionsProvider =
    FutureProvider.family<List<Txn>, String>((ref, personId) async {
  final res = await ApiClient.instance.dio.get('/transactions', queryParameters: {
    'personId': personId,
    'limit': 200,
  });
  return (res.data as List).map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList();
});

class TransactionsNotifier extends AsyncNotifier<List<Txn>> {
  @override
  Future<List<Txn>> build() => _fetch();

  Future<List<Txn>> _fetch() async {
    final res = await ApiClient.instance.dio.get('/transactions', queryParameters: {'limit': 20});
    return (res.data as List).map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> deleteTransaction(Txn txn) async {
    await ApiClient.instance.dio.delete('/transactions/${txn.id}');
    ref.invalidateSelf();
    ref.invalidate(personTransactionsProvider(txn.personId));
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
