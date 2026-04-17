void main() {
  final now = DateTime.now();
  final dFrom = DateTime(now.year, now.month, 1);
  final fromStr = dFrom.toIso8601String();
  final timeInDbUTC = now.toUtc().toIso8601String();
  
  print('fromStr: $fromStr');
  print('timeInDbUTC: $timeInDbUTC');
  print('Compare: ${timeInDbUTC.compareTo(fromStr)}');
}
