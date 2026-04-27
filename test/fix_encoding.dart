import 'dart:io';

void main() {
  final file = File(r'd:\Moimoi-POS-Flutter\lib\features\dashboard\presentation\admin\admin_dashboard_page.dart');
  final lines = file.readAsLinesSync();
  
  int fixCount = 0;
  
  void fixLine(int lineNum, String newContent) {
    final idx = lineNum - 1;
    if (idx >= 0 && idx < lines.length) {
      final oldLine = lines[idx];
      final indent = oldLine.substring(0, oldLine.length - oldLine.trimLeft().length);
      lines[idx] = indent + newContent;
      fixCount++;
      print('Fixed line $lineNum');
    }
  }
  
  fixLine(464, "'Qu\u1ea3n l\u00fd t\u00e0i kho\u1ea3n h\u1ec7 th\u1ed1ng',");
  fixLine(551, "'C\u1ea3nh b\u00e1o: \$expiringCount c\u1eeda h\u00e0ng s\u1eafp h\u1ebft h\u1ea1n trong 7 ng\u00e0y',");
  fixLine(664, "'G\u00f3i N\u0103m (\$yearlyCount):',");
  fixLine(697, "'G\u00f3i Th\u00e1ng (\$monthlyCount):',");
  fixLine(731, "// C\u1eeda h\u00e0ng (Width ~50%)");
  fixLine(802, "// Nh\u00e2n vi\u00ean (Width ~25%)");
  fixLine(834, "'Nh\u00e2n vi\u00ean',");
  fixLine(903, "'Danh s\u00e1ch c\u1eeda h\u00e0ng',");
  fixLine(923, "hintText: 'T\u00ecm t\u00ean, S\u0110T ch\u1ee7 shop...',");
  fixLine(954, "label: 'C\u1ea7n ch\u00fa \u00fd',");
  
  file.writeAsStringSync(lines.join('\n'));
  print('\nDone! Fixed $fixCount lines');
}
