import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

/// Live-formats a plain numeric amount field with Indian comma grouping
/// (e.g. 1234567 -> 12,34,567) as the user types. The underlying value
/// stays parseable with [double.parse] after stripping commas.
class AmountInputFormatter extends TextInputFormatter {
  static final _grouping = NumberFormat.decimalPattern('en_IN');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digitsOnly = newValue.text.replaceAll(',', '');
    if (digitsOnly.isEmpty) return newValue.copyWith(text: '');

    // Allow a single trailing decimal point / partial decimal while typing.
    final parts = digitsOnly.split('.');
    final wholePart = parts[0].replaceAll(RegExp(r'[^0-9]'), '');
    if (wholePart.isEmpty && parts.length == 1) return newValue.copyWith(text: '');

    final wholeNum = int.tryParse(wholePart.isEmpty ? '0' : wholePart) ?? 0;
    final formattedWhole = _grouping.format(wholeNum);

    String formatted = formattedWhole;
    if (parts.length > 1) {
      final decimalPart = parts[1].replaceAll(RegExp(r'[^0-9]'), '');
      formatted = '$formattedWhole.$decimalPart';
    }

    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

/// Strips comma grouping so the text can be parsed with [double.parse].
double parseAmountInput(String text) => double.parse(text.replaceAll(',', ''));
