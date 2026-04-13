import 'dart:convert';
import 'dart:typed_data';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'package:moimoi_pos/core/utils/constants.dart';

/// Backward-compatible image widget.
/// Hỗ trợ hiển thị ảnh từ:
/// - URL (Cloudflare R2 / bất kỳ HTTP URL)
/// - Base64 data URI (dữ liệu cũ)
/// - Placeholder khi không có ảnh
class SmartImage extends StatelessWidget {
  final String? imageData;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final BorderRadius? borderRadius;

  const SmartImage({
    super.key,
    this.imageData,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    final data = imageData;

    // No image data
    if (data == null || data.isEmpty) {
      return _buildPlaceholder();
    }

    Widget imageWidget;

    if (CloudflareService.isUrl(data)) {
      // Network image (Cloudflare R2 URL)
      imageWidget = CachedNetworkImage(
        imageUrl: data,
        width: width,
        height: height,
        fit: fit,
        memCacheWidth: width != null ? (width! * 2).toInt() : 256,
        placeholder: (_, _) => _buildPlaceholder(),
        errorWidget: (_, _, _) => _buildError(),
      );
    } else if (CloudflareService.isBase64(data)) {
      // Base64 data URI (backward compatible)
      try {
        final base64Part = data.split(',').last;
        final bytes = base64Decode(base64Part);
        imageWidget = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          cacheWidth: width != null ? (width! * 2).toInt() : 256,
          errorBuilder: (_, _, _) => _buildError(),
        );
      } catch (_) {
        imageWidget = _buildError();
      }
    } else {
      // Unknown format
      imageWidget = _buildError();
    }

    if (borderRadius != null) {
      return ClipRRect(borderRadius: borderRadius!, child: imageWidget);
    }

    return imageWidget;
  }

  Widget _buildPlaceholder() {
    return placeholder ??
        Container(
          width: width,
          height: height,
          color: AppColors.inputBg,
          child: Icon(Icons.image_outlined, color: AppColors.slate400),
        );
  }

  Widget _buildError() {
    return errorWidget ??
        Container(
          width: width,
          height: height,
          color: AppColors.red100,
          child: Icon(Icons.broken_image_outlined, color: Color(0xFFEF4444)),
        );
  }
}

/// Backward-compatible circular avatar widget.
/// Hỗ trợ URL + base64 + placeholder.
class SmartAvatar extends StatelessWidget {
  final String? imageData;
  final double radius;
  final IconData fallbackIcon;
  final Color fallbackColor;
  final Color fallbackBg;

  const SmartAvatar({
    super.key,
    this.imageData,
    this.radius = 40,
    this.fallbackIcon = Icons.storefront,
    this.fallbackColor = const Color(0xFF10B981),
    this.fallbackBg = const Color(0xFFECFDF5),
  });

  @override
  Widget build(BuildContext context) {
    final data = imageData;
    final size = radius * 2;

    if (data == null || data.isEmpty) {
      return _fallback();
    }

    if (CloudflareService.isUrl(data)) {
      return ClipOval(
        child: CachedNetworkImage(
          imageUrl: data,
          width: size,
          height: size,
          fit: BoxFit.cover,
          memCacheWidth: (size * 2).toInt(),
          placeholder: (_, _) => _fallback(),
          errorWidget: (_, _, _) => _fallback(),
        ),
      );
    }

    if (CloudflareService.isBase64(data)) {
      try {
        final base64Part = data.split(',').last;
        final bytes = base64Decode(base64Part);
        return ClipOval(
          child: Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            cacheWidth: (size * 2).toInt(),
            errorBuilder: (_, _, _) => _fallback(),
          ),
        );
      } catch (_) {
        return _fallback();
      }
    }

    return _fallback();
  }

  Widget _fallback() {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(color: fallbackBg, shape: BoxShape.circle),
      child: Icon(fallbackIcon, size: radius * 0.8, color: fallbackColor),
    );
  }
}

/// Decode ảnh từ base64 hoặc trả về null nếu là URL.
/// Dùng cho các logic cần raw bytes (vd: in bill).
Uint8List? decodeImageData(String? data) {
  if (data == null || data.isEmpty) return null;
  if (CloudflareService.isBase64(data)) {
    try {
      final base64Part = data.split(',').last;
      return base64Decode(base64Part);
    } catch (_) {
      return null;
    }
  }
  return null; // URL — cần fetch riêng nếu muốn bytes
}
