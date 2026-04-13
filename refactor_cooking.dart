import 'dart:io';

void main() {
  final dir = Directory('lib');
  final files = dir.listSync(recursive: true).whereType<File>().where((f) => f.path.endsWith('.dart'));

  for (final file in files) {
    String content = file.readAsStringSync();
    bool changed = false;

    if (content.contains('cooking')) {
      content = content.replaceAll('cookingOrders', 'processingOrders');
      content = content.replaceAll('cookingCount', 'processingCount');
      content = content.replaceAll("'cooking'", "'processing'");
      content = content.replaceAll('cooking', 'processing');
      changed = true;
    }
    
    if (content.contains('Cooking')) {
      content = content.replaceAll('Cooking', 'Processing');
      changed = true;
    }

    if (content.contains('chế biến')) {
      content = content.replaceAll('chế biến', 'xử lý');
      changed = true;
    }
    
    if (content.contains('nấu')) {
      // Be careful with 'nấu', only replace isolated 'đang nấu' or similar unless we ensure it's safe.
      // But we checked, 'Đang nấu' wasn't there. 
      // It's just a general safety check. 
    }

    if (changed) {
      file.writeAsStringSync(content);
      print('Updated ${file.path}');
    }
  }
}
