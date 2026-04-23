import 'dart:io';

void main() {
  final dir = Directory('lib');
  int filesModified = 0;
  for (var entity in dir.listSync(recursive: true)) {
    if (entity is File && entity.path.endsWith('.dart')) {
      var content = entity.readAsStringSync();
      
      bool modified = false;
      var newLines = <String>[];
      var lines = content.split('\n');
      for (int i = 0; i < lines.length; i++) {
        newLines.add(lines[i]);
        if (lines[i].contains("barrierDismissible: true,")) {
          if (i + 1 < lines.length && !lines[i + 1].contains("barrierLabel:")) {
             newLines.add("      barrierLabel: 'Dialog',");
             modified = true;
          }
        }
      }
      
      if (modified) {
        entity.writeAsStringSync(newLines.join('\n'));
        print('Fixed \${entity.path}');
        filesModified++;
      }
    }
  }
  print('Total files modified: $filesModified');
}
