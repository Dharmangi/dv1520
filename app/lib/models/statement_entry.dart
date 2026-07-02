class Statement {
  Statement({required this.entries, required this.pendingAmount});

  final List<StatementEntry> entries;
  final int pendingAmount; // paise

  factory Statement.fromJson(Map<String, dynamic> json) => Statement(
        entries: (json['entries'] as List)
            .map((e) => StatementEntry.fromJson(e as Map<String, dynamic>))
            .toList(),
        pendingAmount: json['pendingAmount'] as int,
      );
}

class StatementEntry {
  StatementEntry({
    required this.date,
    required this.type,
    required this.amount,
    required this.paymentMode,
    required this.description,
  });

  final DateTime date;
  final String type; // 'received' | 'paid'
  final int amount; // paise
  final String paymentMode;
  final String description;

  factory StatementEntry.fromJson(Map<String, dynamic> json) => StatementEntry(
        date: DateTime.parse(json['date'] as String),
        type: json['type'] as String,
        amount: json['amount'] as int,
        paymentMode: json['paymentMode'] as String? ?? 'cash',
        description: json['description'] as String? ?? '',
      );
}
