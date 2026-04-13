import 'package:intl/intl.dart';

String formatCurrency(double amount) {
  final formatter = NumberFormat.currency(
    locale: 'vi_VN',
    symbol: '₫',
    decimalDigits: 0,
  );
  return formatter.format(amount);
}

/// Strip ★ prefix from default table names for display
String displayTableName(String raw) {
  if (raw.isEmpty) return 'Mang về';
  final clean = raw.startsWith('★') ? raw.substring(1) : raw;
  if (clean.contains(' · ')) {
    final parts = clean.split(' · ');
    return '${parts.sublist(1).join(' · ')} · ${parts[0]}';
  }
  return clean;
}

/// Check if a table is a default (★ prefix) table
bool isDefaultTable(String raw) => raw.startsWith('★');
