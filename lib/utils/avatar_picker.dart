import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import '../widgets/circle_crop_dialog.dart';

/// Max file size: 1MB
const int maxImageFileBytes = 1024 * 1024;

/// Max dimension: 1024×1024
const int maxImageDimension = 1024;

/// Validates image file size and dimensions.
/// Returns error message or null if valid.
/// Rules: max 1MB, max 1024×1024, no minimum size requirement.
Future<String?> validateImage(Uint8List bytes, {bool isGif = false}) async {
  // Check file size: max 1MB
  if (bytes.length > maxImageFileBytes) {
    final sizeMB = (bytes.length / 1024 / 1024 * 100).round() / 100;
    return 'Ảnh quá nặng (${sizeMB}MB). Tối đa 1MB.';
  }
  // Skip dimension check for GIFs
  if (isGif) return null;
  // Check dimensions: max 1024×1024
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
/// - Resizes to max 1024×1024 if larger
/// - Compresses as JPEG to stay under 1MB
Uint8List prepareImageBytes(Uint8List rawBytes) {
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

  // Encode as JPEG, try quality 85 first
  var compressed = Uint8List.fromList(img.encodeJpg(processed, quality: 85));

  // If still over 1MB, reduce quality progressively
  if (compressed.length > maxImageFileBytes) {
    for (int q = 70; q >= 30; q -= 10) {
      compressed = Uint8List.fromList(img.encodeJpg(processed, quality: q));
      if (compressed.length <= maxImageFileBytes) break;
    }
  }

  return compressed;
}

/// Converts PNG bytes (from crop dialogs) to compressed WebP-like base64 data URI.
/// Uses JPEG encoding since Dart image package doesn't support WebP encoding.
/// GIF bytes are returned as-is.
String convertToWebpBase64(Uint8List pngBytes) {
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
  final compressed = Uint8List.fromList(img.encodeJpg(processed, quality: 85));
  return 'data:image/webp;base64,${base64Encode(compressed)}';
}

/// Converts raw image bytes (any format) to compressed base64 data URI.
/// Resizes if needed. For QR, logos, etc. that don't go through crop dialog.
String convertRawToWebpBase64(Uint8List rawBytes) {
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
  final compressed = Uint8List.fromList(img.encodeJpg(processed, quality: 85));
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

  // Check if it's a GIF (animated) — skip cropping and conversion for GIFs
  final ext = pickedFile.path.toLowerCase();
  if (ext.endsWith('.gif')) {
    // GIFs: only check file size (can't easily resize)
    if (bytes.length > maxImageFileBytes) {
      final sizeMB = (bytes.length / 1024 / 1024 * 100).round() / 100;
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('GIF quá nặng (${sizeMB}MB). Tối đa 1MB.'), backgroundColor: const Color(0xFFEF4444)),
        );
      }
      return null;
    }
    return 'data:image/gif;base64,${base64Encode(bytes)}';
  }

  // Auto-resize & compress if needed (max 1024px, under 1MB)
  final prepared = prepareImageBytes(bytes);

  if (!context.mounted) return null;

  final result = await showCircleCropDialog(context, imageBytes: prepared);
  return result;
}

/// Builds an avatar widget from a base64 data URI or placeholder.
Widget buildAvatar({
  String? imageData,
  double radius = 40,
  IconData fallbackIcon = Icons.storefront,
  Color fallbackColor = const Color(0xFF10B981),
  Color fallbackBg = const Color(0xFFECFDF5),
}) {
  if (imageData != null && imageData.startsWith('data:')) {
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
