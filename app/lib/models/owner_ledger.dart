import 'person.dart';
import 'transaction.dart';

class OwnerLedger {
  OwnerLedger({required this.owner, required this.customers, required this.transactions});

  final Person owner;
  final List<Person> customers;
  final List<Txn> transactions;

  factory OwnerLedger.fromJson(Map<String, dynamic> json) => OwnerLedger(
        owner: Person.fromJson(json['owner'] as Map<String, dynamic>),
        customers: (json['customers'] as List).map((e) => Person.fromJson(e as Map<String, dynamic>)).toList(),
        transactions: (json['transactions'] as List).map((e) => Txn.fromJson(e as Map<String, dynamic>)).toList(),
      );
}
