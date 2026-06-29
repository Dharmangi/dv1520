import 'package:intl/intl.dart';

final _rupeeFormat = NumberFormat.currency(locale: 'en_IN', symbol: '₹', decimalDigits: 0);

String formatRupees(int paise) => _rupeeFormat.format(paise / 100);

int rupeesToPaise(double rupees) => (rupees * 100).round();
