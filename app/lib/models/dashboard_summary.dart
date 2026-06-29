class DashboardSummary {
  DashboardSummary({
    required this.currentBalance,
    required this.myBalance,
    required this.todayIncome,
    required this.todayExpense,
    required this.monthlyIncome,
    required this.monthlyExpense,
    required this.netBalance,
  });

  final int currentBalance;
  final int myBalance;
  final int todayIncome;
  final int todayExpense;
  final int monthlyIncome;
  final int monthlyExpense;
  final int netBalance;

  factory DashboardSummary.fromJson(Map<String, dynamic> json) => DashboardSummary(
        currentBalance: json['currentBalance'] as int,
        myBalance: json['myBalance'] as int? ?? 0,
        todayIncome: json['todayIncome'] as int,
        todayExpense: json['todayExpense'] as int,
        monthlyIncome: json['monthlyIncome'] as int,
        monthlyExpense: json['monthlyExpense'] as int,
        netBalance: json['netBalance'] as int,
      );
}
