import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../core/network/api_client.dart';
import '../models/transaction.dart';

const _uuid = Uuid();

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

  Future<void> addTransaction({
    required String personId,
    required String type,
    required int amount,
    required String paymentMode,
    String? description,
    required DateTime date,
    String? categoryId,
  }) async {
    final txn = Txn(
      id: '',
      clientUuid: _uuid.v4(),
      personId: personId,
      type: type,
      amount: amount,
      paymentMode: paymentMode,
      description: description,
      date: date,
      categoryId: categoryId,
    );
    await ApiClient.instance.dio.post('/transactions', data: txn.toJson());
    ref.invalidateSelf();
    ref.invalidate(personTransactionsProvider(personId));
    await future;
  }

  Future<void> updateTransaction(Txn txn) async {
    await ApiClient.instance.dio.put('/transactions/${txn.id}', data: txn.toJson());
    ref.invalidateSelf();
    ref.invalidate(personTransactionsProvider(txn.personId));
    await future;
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
