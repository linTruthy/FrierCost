import 'package:intl/intl.dart';
/// A utility class that provides global currency formatting functionality
/// with a focus on Ugandan Shillings (UGX).
class CurrencyFormatter {
  /// Singleton instance
  static final CurrencyFormatter _instance = CurrencyFormatter._internal();
  
  /// NumberFormat instance for Ugandan Shillings
  late final NumberFormat _ugxFormatter;
  
  /// NumberFormat instance for compact notation (K, M, B)
  late final NumberFormat _compactFormatter;
  
  /// Factory constructor to return the singleton instance
  factory CurrencyFormatter() {
    return _instance;
  }
  
  /// Private constructor for singleton pattern
  CurrencyFormatter._internal() {
    _ugxFormatter = NumberFormat.currency(
      locale: 'en_UG',
      symbol: 'USh',
      decimalDigits: 0, // Shillings typically don't use decimal places
    );
    
    _compactFormatter = NumberFormat.compactCurrency(
      locale: 'en_UG',
      symbol: 'USh',
      decimalDigits: 1,
    );
  }
  
  /// Formats a number as Ugandan Shillings with the USh symbol
  /// 
  /// Example: 15000 -> "USh 15,000"
  String format(num amount) {
    return _ugxFormatter.format(amount);
  }
  
  /// Formats a number as Ugandan Shillings without the currency symbol
  /// 
  /// Example: 15000 -> "15,000"
  String formatWithoutSymbol(num amount) {
    return NumberFormat('#,###', 'en_UG').format(amount);
  }
  
  /// Formats a number as Ugandan Shillings in compact notation
  /// 
  /// Example: 1500000 -> "USh 1.5M"
  String formatCompact(num amount) {
    return _compactFormatter.format(amount);
  }
  
  /// Formats a number as Ugandan Shillings with a specific precision
  /// 
  /// Example: formatWithPrecision(15000.75, 2) -> "USh 15,000.75"
  String formatWithPrecision(num amount, int decimalDigits) {
    return NumberFormat.currency(
      locale: 'en_UG',
      symbol: 'USh',
      decimalDigits: decimalDigits,
    ).format(amount);
  }
  
  /// Parses a formatted string back to a number
  /// 
  /// Example: "USh 15,000" -> 15000
  num parse(String formattedAmount) {
    // Remove the currency symbol and any whitespace
    String cleaned = formattedAmount.replaceAll('USh', '').trim();
    return NumberFormat('#,###', 'en_UG').parse(cleaned);
  }
  
  /// Formats a number as Ugandan Shillings and adds a plus sign if positive
  /// 
  /// Example: 15000 -> "+USh 15,000"
  String formatWithSign(num amount) {
    return (amount > 0 ? '+' : '') + _ugxFormatter.format(amount);
  }
  
  /// Returns just the currency symbol
  String get currencySymbol => 'USh';
}


/// Extension on num for easy formatting
extension CurrencyFormatterExtension on num {
  /// Format this number as Ugandan Shillings
  String toUgx() {
    return CurrencyFormatter().format(this);
  }
  
  /// Format this number as compact Ugandan Shillings
  String toUgxCompact() {
    return CurrencyFormatter().formatCompact(this);
  }
}
