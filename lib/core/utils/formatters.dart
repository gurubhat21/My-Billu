import 'package:intl/intl.dart';

class AppFormatters {
  static final _currencyFormat = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 2,
  );

  static final _compactCurrency = NumberFormat.compactCurrency(
    locale: 'en_IN',
    symbol: '₹',
    decimalDigits: 1,
  );

  static final _dateFormat = DateFormat('dd MMM yyyy');
  static final _timeFormat = DateFormat('hh:mm a');
  static final _dateTimeFormat = DateFormat('dd MMM yyyy, hh:mm a');
  static final _shortDate = DateFormat('dd/MM/yy');

  static String currency(double amount) => _currencyFormat.format(amount);
  static String compactCurrency(double amount) =>
      _compactCurrency.format(amount);
  static String date(DateTime dt) => _dateFormat.format(dt);
  static String time(DateTime dt) => _timeFormat.format(dt);
  static String dateTime(DateTime dt) => _dateTimeFormat.format(dt);
  static String shortDate(DateTime dt) => _shortDate.format(dt);

  static String percentage(double value) => '${value.toStringAsFixed(1)}%';

  static String paymentMethod(String method) {
    switch (method) {
      case 'cash':
        return 'Cash';
      case 'upi':
        return 'UPI';
      case 'card':
        return 'Card';
      case 'bank':
        return 'Bank Transfer';
      case 'credit':
        return 'Credit';
      default:
        return method;
    }
  }
}
