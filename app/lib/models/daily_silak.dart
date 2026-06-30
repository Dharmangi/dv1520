class DailySilakEntry {
  DailySilakEntry({
    required this.id,
    this.personId,
    required this.personName,
    required this.amount,
    required this.type,
    this.note = '',
    this.havalaId,
  });

  final String id;
  final String? personId;
  final String personName;
  final int amount;
  final String type; // 'received' | 'paid'
  final String note;
  final String? havalaId;

  bool get isReceived => type == 'received';
  bool get isPaid => type == 'paid';
  bool get isFromHavala => havalaId != null;

  factory DailySilakEntry.fromJson(Map<String, dynamic> json) {
    return DailySilakEntry(
      id: json['_id'] as String,
      personId: json['personId'] as String?,
      personName: json['personName'] as String,
      amount: json['amount'] as int,
      type: json['type'] as String? ?? 'received',
      note: json['note'] as String? ?? '',
      havalaId: json['havalaId'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'personName': personName,
        'amount': amount,
        'type': type,
        'note': note,
        if (personId != null) 'personId': personId,
      };
}

class DailySilak {
  DailySilak({
    required this.id,
    required this.date,
    required this.entries,
    required this.totalReceived,
    required this.totalPaid,
    required this.netBalance,
  });

  final String id;
  final DateTime date;
  final List<DailySilakEntry> entries;
  final int totalReceived;
  final int totalPaid;
  final int netBalance;

  List<DailySilakEntry> get receivedEntries => entries.where((e) => e.isReceived).toList();
  List<DailySilakEntry> get paidEntries => entries.where((e) => e.isPaid).toList();

  factory DailySilak.fromJson(Map<String, dynamic> json) {
    return DailySilak(
      id: json['_id'] as String,
      date: DateTime.parse(json['date'] as String),
      entries: (json['entries'] as List)
          .map((e) => DailySilakEntry.fromJson(e as Map<String, dynamic>))
          .toList(),
      totalReceived: json['totalReceived'] as int? ?? 0,
      totalPaid: json['totalPaid'] as int? ?? 0,
      netBalance: json['netBalance'] as int? ?? 0,
    );
  }
}

class DailySilakSummary {
  DailySilakSummary({
    required this.id,
    required this.date,
    required this.totalReceived,
    required this.totalPaid,
    required this.netBalance,
    required this.entryCount,
  });

  final String id;
  final DateTime date;
  final int totalReceived;
  final int totalPaid;
  final int netBalance;
  final int entryCount;

  factory DailySilakSummary.fromJson(Map<String, dynamic> json) {
    return DailySilakSummary(
      id: json['_id'] as String,
      date: DateTime.parse(json['date'] as String),
      totalReceived: json['totalReceived'] as int? ?? 0,
      totalPaid: json['totalPaid'] as int? ?? 0,
      netBalance: json['netBalance'] as int? ?? 0,
      entryCount: (json['entries'] as List?)?.length ?? 0,
    );
  }
}

class SilakPerson {
  SilakPerson({required this.id, required this.name, this.place, this.isOwner = false});

  final String id;
  final String name;
  final String? place;
  final bool isOwner;

  factory SilakPerson.fromJson(Map<String, dynamic> json) {
    return SilakPerson(
      id: json['_id'] as String,
      name: json['name'] as String,
      place: json['place'] as String?,
      isOwner: json['isOwner'] as bool? ?? false,
    );
  }

  String get displayName => place != null && place!.isNotEmpty ? '$name ($place)' : name;
}
