import 'dart:io';

void main() {
  final file = File('lib/features/dashboard/presentation/admin/admin_dashboard_page.dart');
  final lines = file.readAsLinesSync();
  final corruptedLine = lines[400]; // Line 401 is index 400
  print(corruptedLine);
  print(corruptedLine.codeUnits);
}
