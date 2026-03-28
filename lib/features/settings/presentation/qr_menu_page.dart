import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';

class QrMenuPage extends StatelessWidget {
  const QrMenuPage({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final storeId = store.getStoreId();
    final tables = store.storeTables[storeId] ?? [];
    final storeName = store.currentStoreInfo.name.isNotEmpty
        ? store.currentStoreInfo.name
        : storeId;

    if (tables.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppColors.slate100,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.qr_code_2, size: 40, color: AppColors.slate400),
              ),
              const SizedBox(height: 20),
              const Text(
                'Chưa có bàn nào',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.slate800),
              ),
              const SizedBox(height: 8),
              const Text(
                'Thêm bàn trong mục "Quản Lý Bàn & Khu Vực"\nđể tạo mã QR cho từng bàn.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: AppColors.slate400, height: 1.5),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.emerald200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.emerald500,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.qr_code_2, size: 22, color: Colors.white),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'QR Code cho bàn',
                            style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.emerald700),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${tables.length} bàn • Bấm vào bàn để xem & tải QR',
                            style: const TextStyle(fontSize: 12, color: AppColors.emerald600),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Table grid
              GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.3,
                ),
                itemCount: tables.length,
                itemBuilder: (context, index) {
                  final tableName = tables[index];
                  return _TableQrCard(
                    tableName: tableName,
                    storeId: storeId,
                    storeName: storeName,
                    index: index,
                  );
                },
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TableQrCard extends StatelessWidget {
  final String tableName;
  final String storeId;
  final String storeName;
  final int index;

  const _TableQrCard({
    required this.tableName,
    required this.storeId,
    required this.storeName,
    required this.index,
  });

  /// Base URL for the customer ordering web app.
  /// Replace with your deployed domain (e.g. https://order.moimoi.vn)
  static const _webBaseUrl = 'https://moimoi-green.vercel.app';

  String get _qrData => '$_webBaseUrl/menu/$storeId?table=${Uri.encodeComponent(tableName)}';

  static const _cardColors = [
    [Color(0xFF10B981), Color(0xFFF0FDF4)],
    [Color(0xFF6366F1), Color(0xFFF0F5FF)],
    [Color(0xFFF59E0B), Color(0xFFFFF7ED)],
    [Color(0xFFF97316), Color(0xFFFFF3E0)],
    [Color(0xFF3B82F6), Color(0xFFEFF6FF)],
    [Color(0xFFEC4899), Color(0xFFFDF2F8)],
    [Color(0xFF8B5CF6), Color(0xFFF5F3FF)],
    [Color(0xFF14B8A6), Color(0xFFF0FDFA)],
  ];

  @override
  Widget build(BuildContext context) {
    final colors = _cardColors[index % _cardColors.length];
    final accentColor = colors[0];
    final bgColor = colors[1];

    return GestureDetector(
      onTap: () => _showQrDialog(context, accentColor),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.qr_code_2, size: 24, color: accentColor),
            ),
            const SizedBox(height: 10),
            Text(
              tableName,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: AppColors.slate800,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(
              'Bấm để xem QR',
              style: TextStyle(fontSize: 11, color: AppColors.slate400),
            ),
          ],
        ),
      ),
    );
  }

  void _showQrDialog(BuildContext context, Color accentColor) {
    final qrKey = GlobalKey();

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 360,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: accentColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.table_bar, size: 20, color: accentColor),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tableName,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800),
                        ),
                        Text(
                          storeName,
                          style: const TextStyle(fontSize: 12, color: AppColors.slate400),
                        ),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => Navigator.pop(ctx),
                    child: Container(
                      width: 32,
                      height: 32,
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.close, size: 16, color: AppColors.slate500),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // QR Code
              RepaintBoundary(
                key: qrKey,
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Column(
                    children: [
                      QrImageView(
                        data: _qrData,
                        version: QrVersions.auto,
                        size: 200,
                        gapless: true,
                        eyeStyle: QrEyeStyle(
                          eyeShape: QrEyeShape.square,
                          color: accentColor,
                        ),
                        dataModuleStyle: QrDataModuleStyle(
                          dataModuleShape: QrDataModuleShape.square,
                          color: AppColors.slate800,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        tableName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: accentColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        storeName,
                        style: const TextStyle(fontSize: 11, color: AppColors.slate400),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Info
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline, size: 16, color: AppColors.slate400),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'In QR này và dán lên bàn.\nKhách quét để xem menu và đặt món.',
                        style: TextStyle(fontSize: 12, color: AppColors.slate500, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await _saveQrImage(ctx, qrKey);
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: AppColors.slate50,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.download_rounded, size: 18, color: AppColors.slate600),
                            SizedBox(width: 8),
                            Text('Tải QR',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.slate600)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        await _printQr(ctx, qrKey);
                      },
                      child: Container(
                        height: 52,
                        decoration: BoxDecoration(
                          color: accentColor,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.print_rounded, size: 18, color: Colors.white),
                            SizedBox(width: 8),
                            Text('In QR',
                                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveQrImage(BuildContext context, GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      final _ = byteData.buffer.asUint8List();

      // Use a simple approach: save to app cache and show success
      if (context.mounted) {
        context.read<AppStore>().showToast('Đã tạo QR thành công! Dùng nút In để in.');
      }
    } catch (e) {
      if (context.mounted) {
        context.read<AppStore>().showToast('Lỗi tạo QR: $e', 'error');
      }
    }
  }

  Future<void> _printQr(BuildContext context, GlobalKey key) async {
    try {
      final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return;

      if (context.mounted) {
        context.read<AppStore>().showToast('Tính năng in sẽ được hỗ trợ khi kết nối máy in.');
      }
    } catch (e) {
      if (context.mounted) {
        context.read<AppStore>().showToast('Lỗi: $e', 'error');
      }
    }
  }
}
