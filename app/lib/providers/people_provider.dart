import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/network/api_client.dart';
import '../models/owner_ledger.dart';
import '../models/person.dart';

final peopleProvider = AsyncNotifierProvider<PeopleNotifier, List<Person>>(PeopleNotifier.new);

final ownerLedgerProvider = FutureProvider.family.autoDispose<OwnerLedger, String>((ref, ownerId) async {
  final res = await ApiClient.instance.dio.get('/people/$ownerId/ledger');
  return OwnerLedger.fromJson(res.data as Map<String, dynamic>);
});

class PeopleNotifier extends AsyncNotifier<List<Person>> {
  @override
  Future<List<Person>> build() => _fetch();

  Future<List<Person>> _fetch() async {
    final res = await ApiClient.instance.dio.get('/people');
    return (res.data as List).map((e) => Person.fromJson(e as Map<String, dynamic>)).toList();
  }

  Future<void> addPerson(Person person) async {
    await ApiClient.instance.dio.post('/people', data: person.toJson());
    ref.invalidateSelf();
    await future;
  }

  Future<void> updatePerson(String id, Person person) async {
    await ApiClient.instance.dio.put('/people/$id', data: person.toJson());
    ref.invalidateSelf();
    await future;
  }

  Future<void> deletePerson(String id) async {
    await ApiClient.instance.dio.delete('/people/$id');
    ref.invalidateSelf();
    await future;
  }

  Future<void> refresh() async {
    ref.invalidateSelf();
    await future;
  }
}
