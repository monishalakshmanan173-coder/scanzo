import 'package:intl/intl.dart';

class CurrencyFormatter {
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final NumberFormat _compactCurrencyFormat = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static String format(num amount) {
    return _currencyFormat.format(amount);
  }

  static String formatCompact(num amount) {
    return _compactCurrencyFormat.format(amount);
  }

  static String formatWithoutSymbol(num amount) {
    return NumberFormat('#,##,##0.00', 'en_IN').format(amount);
  }
}
