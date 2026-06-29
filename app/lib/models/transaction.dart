class Txn {
  Txn({
    required this.id,
    required this.clientUuid,
    required this.personId,
    this.personName,
    required this.type,
    required this.amount,
    this.paymentMode = 'cash',
    this.description,
    required this.date,
    this.categoryId,
    this.categoryName,
    this.status = 'confirmed',
  });

  final String id;
  final String clientUuid;
  final String personId;
  final String? personName;
  final String type; // 'received' | 'paid'
  final int amount; // paise
  final String paymentMode;
  final String? description;
  final DateTime date;
  final String? categoryId;
  final String? categoryName;
  final String status; // 'pending' | 'confirmed'

  bool get isPending => status == 'pending';

  factory Txn.fromJson(Map<String, dynamic> json) {
    final person = json['personId'];
    final category = json['categoryId'];
    return Txn(
      id: json['_id'] as String,
      clientUuid: json['clientUuid'] as String,
      personId: person is Map ? person['_id'] as String : person as String,
      personName: person is Map ? person['name'] as String? : null,
      type: json['type'] as String,
      amount: json['amount'] as int,
      paymentMode: json['paymentMode'] as String? ?? 'cash',
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String),
      categoryId: category is Map ? category['_id'] as String? : category as String?,
      categoryName: category is Map ? category['name'] as String? : null,
      status: json['status'] as String? ?? 'confirmed',
    );
  }

  Map<String, dynamic> toJson() => {
        'clientUuid': clientUuid,
        'personId': personId,
        'type': type,
        'amount': amount,
        'paymentMode': paymentMode,
        if (description != null) 'description': description,
        'date': date.toIso8601String(),
        if (categoryId != null) 'categoryId': categoryId,
      };
}
