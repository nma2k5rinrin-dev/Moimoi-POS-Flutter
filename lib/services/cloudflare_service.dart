import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

/// Service để upload/delete ảnh trên Cloudflare R2 qua Worker proxy.
///
/// Cách dùng:
/// ```dart
/// final url = await CloudflareService.uploadBytes(
///   bytes: imageBytes,
///   folder: 'products',
///   extension: 'jpg',
/// );
/// // url = "https://moimoi-r2-worker.xxx.workers.dev/images/products/1234_abc.jpg"
/// ```
class CloudflareService {
  // ⚠️ CẬP NHẬT URL SAU KHI DEPLOY WORKER
  static const String _workerUrl = 'https://moimoi-r2-worker.nma-store-data.workers.dev';

  // ⚠️ CẬP NHẬT SECRET TRÙNG VỚI WRANGLER SECRET
  static const String _uploadSecret = 'Hihi123!';

  /// Upload raw bytes lên R2, trả về public URL.
  /// [folder]: thư mục phân loại (products, avatars, logos, qr)
  /// [extension]: đuôi file (jpg, png, webp)
  static Future<String> uploadBytes({
    required Uint8List bytes,
    required String folder,
    String extension = 'jpg',
  }) async {
    try {
      final uri = Uri.parse('$_workerUrl/upload');

      // Dùng multipart upload
      final request = http.MultipartRequest('POST', uri)
        ..headers['Authorization'] = 'Bearer $_uploadSecret'
        ..fields['folder'] = folder
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'image.$extension',
        ));

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.statusCode} ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['url'] as String;
    } catch (e) {
      debugPrint('[CloudflareService] Upload error: $e');
      rethrow;
    }
  }

  /// Upload base64 data URI lên R2, trả về public URL.
  /// Input: "data:image/webp;base64,..." hoặc raw base64 string 
  static Future<String> uploadBase64({
    required String base64Data,
    required String folder,
  }) async {
    try {
      final uri = Uri.parse('$_workerUrl/upload');

      final response = await http.post(
        uri,
        headers: {
          'Authorization': 'Bearer $_uploadSecret',
          'Content-Type': 'application/json',
        },
        body: json.encode({
          'data': base64Data,
          'folder': folder,
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.statusCode} ${response.body}');
      }

      final data = json.decode(response.body) as Map<String, dynamic>;
      return data['url'] as String;
    } catch (e) {
      debugPrint('[CloudflareService] Upload base64 error: $e');
      rethrow;
    }
  }

  /// Xóa ảnh trên R2 bằng URL.
  static Future<void> deleteByUrl(String imageUrl) async {
    try {
      // Extract path from full URL
      final uri = Uri.parse(imageUrl);
      final deletePath = uri.path; // e.g. /images/products/123_abc.jpg

      final response = await http.delete(
        Uri.parse('$_workerUrl$deletePath'),
        headers: {
          'Authorization': 'Bearer $_uploadSecret',
        },
      );

      if (response.statusCode != 200) {
        debugPrint('[CloudflareService] Delete failed: ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('[CloudflareService] Delete error: $e');
    }
  }

  /// Kiểm tra xem string là URL (Cloudflare) hay base64.
  static bool isUrl(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.startsWith('http://') || value.startsWith('https://');
  }

  /// Kiểm tra xem string là base64 data URI.
  static bool isBase64(String? value) {
    if (value == null || value.isEmpty) return false;
    return value.startsWith('data:');
  }
}
