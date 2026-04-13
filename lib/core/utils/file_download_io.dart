import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

Future<void> downloadFile(String fileName, Uint8List bytes) async {
  try {
    Directory? dir;
    if (Platform.isAndroid) {
      dir = Directory('/storage/emulated/0/Download');
      if (!await dir.exists()) {
        dir = await getExternalStorageDirectory();
      }
    } else if (Platform.isIOS) {
      dir = await getApplicationDocumentsDirectory();
    } else {
      dir = await getDownloadsDirectory();
    }

    if (dir != null) {
      final file = File('${dir.path}/$fileName');
      await file.writeAsBytes(bytes);
    }
  } catch (e) {
    debugPrint('Error saving file: $e');
    rethrow;
  }
}
