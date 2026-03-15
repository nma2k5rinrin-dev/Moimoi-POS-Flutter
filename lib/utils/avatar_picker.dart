import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../widgets/circle_crop_dialog.dart';

/// Picks an image from gallery, crops it to a circle, and returns a base64 string.
/// Supports static images (jpg, png, webp) and animated gifs.
/// Returns null if the user cancels.
Future<String?> pickAndCropAvatar(BuildContext context) async {
  final picker = ImagePicker();

  final XFile? pickedFile = await picker.pickImage(
    source: ImageSource.gallery,
    maxWidth: 512,
    maxHeight: 512,
    imageQuality: 85,
  );

  if (pickedFile == null) return null;

  // Check if it's a GIF (animated) — skip cropping for GIFs
  final ext = pickedFile.path.toLowerCase();
  if (ext.endsWith('.gif')) {
    final bytes = await pickedFile.readAsBytes();
    return 'data:image/gif;base64,${base64Encode(bytes)}';
  }

  // Read bytes and show custom crop dialog
  final bytes = await pickedFile.readAsBytes();
  if (!context.mounted) return null;

  final result = await showCircleCropDialog(context, imageBytes: bytes);
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
    // Extract base64 part
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
