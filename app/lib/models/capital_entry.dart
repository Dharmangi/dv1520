class CapitalEntry {
  CapitalEntry({
    required this.id,
    required this.clientUuid,
    required this.amount,
    this.note,
    required this.date,
  });

  final String id;
  final String clientUuid;
  final int amount; // paise, can be negative
  final String? note;
  final DateTime date;

  factory CapitalEntry.fromJson(Map<String, dynamic> json) => CapitalEntry(
        id: json['_id'] as String,
        clientUuid: json['clientUuid'] as String,
        amount: json['amount'] as int,
        note: json['note'] as String?,
        date: DateTime.parse(json['date'] as String),
      );

  Map<String, dynamic> toJson() => {
        'clientUuid': clientUuid,
        'amount': amount,
        if (note != null) 'note': note,
        'date': date.toIso8601String(),
      };
}
