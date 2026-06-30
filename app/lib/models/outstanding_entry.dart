class OutstandingSettlement {
  OutstandingSettlement({required this.amount, required this.date, this.note = ''});

  final int amount;
  final DateTime date;
  final String note;

  factory OutstandingSettlement.fromJson(Map<String, dynamic> json) {
    return OutstandingSettlement(
      amount: json['amount'] as int,
      date: DateTime.parse(json['date'] as String),
      note: json['note'] as String? ?? '',
    );
  }
}

class OutstandingEntry {
  OutstandingEntry({
    required this.id,
    this.personId,
    required this.personName,
    required this.totalAmount,
    required this.settledAmount,
    required this.status,
    required this.createdDate,
    this.note = '',
    this.settlements = const [],
  });

  final String id;
  final String? personId;
  final String personName;
  final int totalAmount;
  final int settledAmount;
  final String status; // 'pending' | 'settled'
  final DateTime createdDate;
  final String note;
  final List<OutstandingSettlement> settlements;

  int get pendingAmount => totalAmount - settledAmount;
  bool get isSettled => status == 'settled';
  bool get isPartiallySettled => settledAmount > 0 && !isSettled;

  factory OutstandingEntry.fromJson(Map<String, dynamic> json) {
    return OutstandingEntry(
      id: json['_id'] as String,
      personId: json['personId'] as String?,
      personName: json['personName'] as String,
      totalAmount: json['totalAmount'] as int,
      settledAmount: json['settledAmount'] as int? ?? 0,
      status: json['status'] as String? ?? 'pending',
      createdDate: DateTime.parse(json['createdDate'] as String),
      note: json['note'] as String? ?? '',
      settlements: (json['settlements'] as List? ?? [])
          .map((e) => OutstandingSettlement.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

class HavalaPendingSummary {
  HavalaPendingSummary({
    required this.personId,
    required this.personName,
    required this.totalPending,
    required this.havalaCount,
  });

  final String personId;
  final String personName;
  final int totalPending;
  final int havalaCount;

  factory HavalaPendingSummary.fromJson(Map<String, dynamic> json) {
    return HavalaPendingSummary(
      personId: json['personId'] as String,
      personName: json['personName'] as String,
      totalPending: json['totalPending'] as int,
      havalaCount: json['havalaCount'] as int,
    );
  }
}

class HavalaCreditSummary {
  HavalaCreditSummary({required this.personId, required this.personName, required this.totalAmount});

  final String personId;
  final String personName;
  final int totalAmount;

  factory HavalaCreditSummary.fromJson(Map<String, dynamic> json) {
    return HavalaCreditSummary(
      personId: json['personId'] as String,
      personName: json['personName'] as String,
      totalAmount: json['totalAmount'] as int,
    );
  }
}

class OutstandingListResult {
  OutstandingListResult({required this.outstandingEntries, required this.havalaPending, required this.havalaCredits});

  final List<OutstandingEntry> outstandingEntries;
  final List<HavalaPendingSummary> havalaPending;
  final List<HavalaCreditSummary> havalaCredits;

  factory OutstandingListResult.fromJson(Map<String, dynamic> json) {
    return OutstandingListResult(
      outstandingEntries: (json['outstandingEntries'] as List)
          .map((e) => OutstandingEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      havalaPending: (json['havalaPending'] as List)
          .map((e) => HavalaPendingSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      havalaCredits: (json['havalaCredits'] as List? ?? [])
          .map((e) => HavalaCreditSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}
