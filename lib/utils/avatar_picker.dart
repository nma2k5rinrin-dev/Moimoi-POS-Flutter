import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../services/cloudflare_service.dart';
import '../widgets/circle_crop_dialog.dart';

/// Max file size: 100KB (optimized for base64 DB storage)
const int maxImageFileBytes = 100 * 1024;

/// Max dimension: 200×200 (images display at ≤200px in UI)
const int maxImageDimension = 200;

/// Validates image file size and dimensions.
/// Returns error message or null if valid.
/// Rules: max 100KB, max 200×200, no minimum size requirement.
Future<String?> validateImage(Uint8List bytes, {bool isGif = false}) async {
  // Check file size: max 100KB
  if (bytes.length > maxImageFileBytes) {
    final sizeKB = (bytes.length / 1024).round();
    return 'Ảnh quá nặng (${sizeKB}KB). Tối đa 100KB.';
  }
  // Skip dimension check for GIFs (legacy, GIF upload now blocked)
  if (isGif) return null;
  // Check dimensions: max 200×200
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final w = frame.image.width;
  final h = frame.image.height;
  frame.image.dispose();
  if (w > maxImageDimension || h > maxImageDimension) {
    return 'Ảnh quá lớn (${w}×${h}). Tối đa ${maxImageDimension}×${maxImageDimension} pixel.';
  }
  return null;
}

/// Alias for backward compatibility
Future<String?> validateProductImage(Uint8List bytes) async {
  return validateImage(bytes);
}

/// Auto-resize and compress image bytes to fit within system limits.
/// Returns processed bytes ready for crop dialog. Does NOT reject — always returns usable bytes.
/// - Resizes to max 200×200 if larger
/// - Compresses as JPEG to stay under 100KB
/// Now runs in a background isolate to avoid UI freeze.
Future<Uint8List> prepareImageBytes(Uint8List rawBytes) async {
  return compute(_prepareImageBytesIsolate, rawBytes);
}

/// Top-level function for compute() isolate
Uint8List _prepareImageBytesIsolate(Uint8List rawBytes) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) return rawBytes;

  img.Image processed = decoded;

  // Resize if any dimension exceeds max
  if (decoded.width > maxImageDimension || decoded.height > maxImageDimension) {
    if (decoded.width >= decoded.height) {
      processed = img.copyResize(decoded, width: maxImageDimension, interpolation: img.Interpolation.linear);
    } else {
      processed = img.copyResize(decoded, height: maxImageDimension, interpolation: img.Interpolation.linear);
    }
  }

  // Encode as JPEG, try quality 70 first
  var compressed = Uint8List.fromList(img.encodeJpg(processed, quality: 70));

  // If still over 100KB, reduce quality progressively
  if (compressed.length > maxImageFileBytes) {
    for (int q = 60; q >= 20; q -= 10) {
      compressed = Uint8List.fromList(img.encodeJpg(processed, quality: q));
      if (compressed.length <= maxImageFileBytes) break;
    }
  }

  return compressed;
}

/// Converts PNG bytes (from crop dialogs) to compressed WebP-like base64 data URI.
/// Uses JPEG encoding since Dart image package doesn't support WebP encoding.
/// GIF bytes are returned as-is.
/// Now runs in a background isolate to avoid UI freeze.
Future<String> convertToWebpBase64(Uint8List pngBytes) async {
  return compute(_convertToWebpBase64Isolate, pngBytes);
}

/// Top-level function for compute() isolate
String _convertToWebpBase64Isolate(Uint8List pngBytes) {
  final decoded = img.decodePng(pngBytes);
  if (decoded == null) {
    return 'data:image/png;base64,${base64Encode(pngBytes)}';
  }
  // Resize if larger than max dimension
  img.Image processed = decoded;
  if (decoded.width > maxImageDimension || decoded.height > maxImageDimension) {
    if (decoded.width >= decoded.height) {
      processed = img.copyResize(decoded, width: maxImageDimension, interpolation: img.Interpolation.linear);
    } else {
      processed = img.copyResize(decoded, height: maxImageDimension, interpolation: img.Interpolation.linear);
    }
  }
  // Encode as JPEG (much lighter than PNG, typically 3-5x smaller)
  final compressed = Uint8List.fromList(img.encodeJpg(processed, quality: 70));
  return 'data:image/webp;base64,${base64Encode(compressed)}';
}

/// Converts raw image bytes (any format) to compressed base64 data URI.
/// Resizes if needed. For QR, logos, etc. that don't go through crop dialog.
/// Now runs in a background isolate to avoid UI freeze.
Future<String> convertRawToWebpBase64(Uint8List rawBytes) async {
  return compute(_convertRawToWebpBase64Isolate, rawBytes);
}

/// Top-level function for compute() isolate
String _convertRawToWebpBase64Isolate(Uint8List rawBytes) {
  final decoded = img.decodeImage(rawBytes);
  if (decoded == null) {
    return 'data:image/jpeg;base64,${base64Encode(rawBytes)}';
  }
  // Resize if larger than max dimension
  img.Image processed = decoded;
  if (decoded.width > maxImageDimension || decoded.height > maxImageDimension) {
    if (decoded.width >= decoded.height) {
      processed = img.copyResize(decoded, width: maxImageDimension, interpolation: img.Interpolation.linear);
    } else {
      processed = img.copyResize(decoded, height: maxImageDimension, interpolation: img.Interpolation.linear);
    }
  }
  final compressed = Uint8List.fromList(img.encodeJpg(processed, quality: 70));
  return 'data:image/webp;base64,${base64Encode(compressed)}';
}

/// Picks an image from gallery, crops it to a circle, and returns a base64 string.
/// Supports static images (jpg, png, webp) and animated gifs.
/// Returns null if the user cancels.
Future<String?> pickAndCropAvatar(BuildContext context) async {
  final picker = ImagePicker();

  final XFile? pickedFile = await picker.pickImage(
    source: ImageSource.gallery,
  );

  if (pickedFile == null) return null;

  final bytes = await pickedFile.readAsBytes();

  // Reject GIF format
  final ext = pickedFile.path.toLowerCase();
  if (ext.endsWith('.gif')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Không hỗ trợ định dạng GIF. Vui lòng chọn ảnh JPG hoặc PNG.'), backgroundColor: Color(0xFFEF4444)),
      );
    }
    return null;
  }

  // Auto-resize & compress if needed (max 1024px, under 1MB)
  final prepared = await prepareImageBytes(bytes);

  if (!context.mounted) return null;

  final result = await showCircleCropDialog(context, imageBytes: prepared);
  return result;
}

// ═══════════════════════════════════════════════════════════
// CLOUDFLARE R2 UPLOAD FUNCTIONS (new)
// ═══════════════════════════════════════════════════════════

/// Upload raw bytes lên Cloudflare R2, trả về public URL.
/// Tự resize + compress trước khi upload.
Future<String> uploadToR2({
  required Uint8List bytes,
  required String folder,
}) async {
  // Compress bytes before upload
  final compressed = await prepareImageBytes(bytes);
  
  return CloudflareService.uploadBytes(
    bytes: compressed,
    folder: folder,
    extension: 'jpg',
  );
}

/// Picks, crops (circle), compresses, and uploads to R2. Returns URL or null.
Future<String?> pickCropAndUploadAvatar(BuildContext context) async {
  final picker = ImagePicker();
  final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);

  if (pickedFile == null) return null;

  final bytes = await pickedFile.readAsBytes();

  // Reject GIF
  if (pickedFile.path.toLowerCase().endsWith('.gif')) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Không hỗ trợ định dạng GIF. Vui lòng chọn ảnh JPG hoặc PNG.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
    return null;
  }

  final prepared = await prepareImageBytes(bytes);
  if (!context.mounted) return null;

  final base64Result = await showCircleCropDialog(context, imageBytes: prepared);
  if (base64Result == null) return null;

  // Upload base64 result to R2
  try {
    return await CloudflareService.uploadBase64(
      base64Data: base64Result,
      folder: 'avatars',
    );
  } catch (e) {
    debugPrint('[pickCropAndUploadAvatar] Upload failed, falling back to base64: $e');
    return base64Result; // Fallback: return base64 nếu upload thất bại
  }
}

/// Builds an avatar widget from a base64 data URI or placeholder.
Widget buildAvatar({
  String? imageData,
  double radius = 40,
  IconData fallbackIcon = Icons.storefront,
  Color fallbackColor = const Color(0xFF10B981),
  Color fallbackBg = const Color(0xFFECFDF5),
}) {
  if (imageData == null || imageData.isEmpty) {
    return _fallbackAvatar(radius, fallbackIcon, fallbackColor, fallbackBg);
  }

  // URL (Cloudflare R2 or any HTTP URL)
  if (CloudflareService.isUrl(imageData)) {
    return ClipOval(
      child: CachedNetworkImage(
        imageUrl: imageData,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        placeholder: (_, __) => _fallbackAvatar(
          radius, fallbackIcon, fallbackColor, fallbackBg,
        ),
        errorWidget: (_, __, ___) => _fallbackAvatar(
          radius, fallbackIcon, fallbackColor, fallbackBg,
        ),
      ),
    );
  }

  // Base64 data URI (backward compatible)
  if (imageData.startsWith('data:')) {
    final base64Part = imageData.split(',').last;
    final bytes = base64Decode(base64Part);
    return ClipOval(
      child: Image.memory(
        bytes,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _fallbackAvatar(
          radius, fallbackIcon, fallbackColor, fallbackBg,
        ),
      ),
    );
  }

  return _fallbackAvatar(radius, fallbackIcon, fallbackColor, fallbackBg);
}

Widget _fallbackAvatar(
  double radius,
  IconData icon,
  Color iconColor,
  Color bg,
) {
  return Container(
    width: radius * 2,
    height: radius * 2,
    decoration: BoxDecoration(
      color: bg,
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: radius * 0.8, color: iconColor),
  );
}
