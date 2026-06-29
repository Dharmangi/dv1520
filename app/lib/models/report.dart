class RangeSummary {
  RangeSummary({required this.received, required this.paid, required this.net});

  final int received;
  final int paid;
  final int net;

  factory RangeSummary.fromJson(Map<String, dynamic> json) => RangeSummary(
        received: json['received'] as int,
        paid: json['paid'] as int,
        net: json['net'] as int,
      );
}

class PersonReport {
  PersonReport({
    required this.personId,
    required this.personName,
    required this.received,
    required this.paid,
    required this.net,
  });

  final String personId;
  final String personName;
  final int received;
  final int paid;
  final int net;

  factory PersonReport.fromJson(Map<String, dynamic> json) => PersonReport(
        personId: json['personId'] as String,
        personName: json['personName'] as String,
        received: json['received'] as int,
        paid: json['paid'] as int,
        net: json['net'] as int,
      );
}

class CategoryReport {
  CategoryReport({
    required this.categoryId,
    required this.categoryName,
    required this.categoryType,
    required this.total,
  });

  final String categoryId;
  final String categoryName;
  final String categoryType;
  final int total;

  factory CategoryReport.fromJson(Map<String, dynamic> json) => CategoryReport(
        categoryId: json['categoryId'] as String,
        categoryName: json['categoryName'] as String,
        categoryType: json['categoryType'] as String,
        total: json['total'] as int,
      );
}

class TimeSeriesPoint {
  TimeSeriesPoint({required this.date, required this.received, required this.paid});

  final DateTime date;
  final int received;
  final int paid;

  factory TimeSeriesPoint.fromJson(Map<String, dynamic> json) => TimeSeriesPoint(
        date: DateTime.parse(json['date'] as String),
        received: json['received'] as int? ?? 0,
        paid: json['paid'] as int? ?? 0,
      );
}
