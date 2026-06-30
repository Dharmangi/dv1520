class HavalaSplit {
  HavalaSplit({required this.personId, this.personName, this.personPlace, required this.amount, required this.date});

  final String personId;
  final String? personName;
  final String? personPlace;
  final int amount;
  final DateTime date;

  factory HavalaSplit.fromJson(Map<String, dynamic> json, {DateTime? fallbackDate}) {
    final person = json['personId'];
    return HavalaSplit(
      personId: person is Map ? person['_id'] as String : person as String,
      personName: person is Map ? person['name'] as String? : null,
      personPlace: person is Map ? person['place'] as String? : null,
      amount: json['amount'] as int,
      date: json['date'] != null ? DateTime.parse(json['date'] as String) : (fallbackDate ?? DateTime.now()),
    );
  }

  Map<String, dynamic> toJson() => {
        'personId': personId,
        'amount': amount,
        'date': '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      };
}

class Havala {
  Havala({
    required this.id,
    required this.ownerId,
    this.ownerName,
    this.ownerMobile,
    required this.totalAmount,
    required this.paidAmount,
    required this.date,
    required this.splits,
    this.ownerTransactionIds = const [],
    this.pendingTransactionId,
  });

  final String id;
  final String ownerId;
  final String? ownerName;
  final String? ownerMobile;
  final int totalAmount;
  final int paidAmount;
  final DateTime date;
  final List<HavalaSplit> splits;
  final List<String> ownerTransactionIds;
  final String? pendingTransactionId;

  int get pendingAmount => totalAmount - paidAmount;

  factory Havala.fromJson(Map<String, dynamic> json) {
    final owner = json['ownerId'];
    final havalaDate = DateTime.parse(json['date'] as String);
    return Havala(
      id: json['_id'] as String,
      ownerId: owner is Map ? owner['_id'] as String : owner as String,
      ownerName: owner is Map ? owner['name'] as String? : null,
      ownerMobile: owner is Map ? owner['mobile'] as String? : null,
      totalAmount: json['totalAmount'] as int,
      paidAmount: json['paidAmount'] as int,
      date: havalaDate,
      splits: (json['splits'] as List)
          .map((e) => HavalaSplit.fromJson(e as Map<String, dynamic>, fallbackDate: havalaDate))
          .toList(),
      ownerTransactionIds: (json['ownerTransactionIds'] as List? ?? [])
          .map((e) => e is Map ? e['_id'] as String : e as String)
          .toList(),
      pendingTransactionId: json['pendingTransactionId'] == null
          ? null
          : (json['pendingTransactionId'] is Map
              ? json['pendingTransactionId']['_id'] as String
              : json['pendingTransactionId'] as String),
    );
  }
}
