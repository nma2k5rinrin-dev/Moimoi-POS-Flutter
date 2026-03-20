import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../store/app_store.dart';
import '../utils/constants.dart';
import '../utils/format.dart';

/// Hiển thị dialog xác nhận thanh toán (QR + nút thanh toán).
///
/// [amount]   – số tiền cần thanh toán.
/// [onPaid]   – callback khi bấm "Đã nhận Tiền mặt / CK", truyền 'cash' hoặc 'transfer'.
/// [onUnpaid] – callback khi bấm "Thanh toán sau".
void showPaymentConfirmation(
  BuildContext context, {
  required double amount,
  required ValueChanged<String> onPaid,
  required VoidCallback onUnpaid,
}) {
  final store = context.read<AppStore>();
  final storeInfo = store.currentStoreInfo;

  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Dismiss',
    barrierColor: Colors.transparent,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (ctx, anim1, anim2) {
      return Stack(
        children: [
          // Blurred dim overlay
          Positioned.fill(
            child: GestureDetector(
              onTap: () => Navigator.pop(ctx),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
                child: Container(
                  color: const Color(0x66000000),
                ),
              ),
            ),
          ),
          // Centered payment panel
          Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 12),
              constraints: const BoxConstraints(maxWidth: 480),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x33000000),
                    blurRadius: 32,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(20),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Header
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Xác nhận thanh toán',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 18,
                              color: AppColors.slate800,
                            ),
                          ),
                          InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: AppColors.slate100,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: const Icon(Icons.close,
                                  size: 18, color: AppColors.slate500),
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(height: 1, color: AppColors.slate100),

                    // Body – QR or Bank info + amount
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                      child: Column(
                        children: [
                          // Show QR image, bank info, or prompt
                          _buildPaymentInfo(storeInfo),
                          const SizedBox(height: 8),
                          const Text(
                            'Cần thanh toán',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: AppColors.slate500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formatCurrency(amount),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF0F766E),
                            ),
                          ),
                        ],
                      ),
                    ),

                      // Buttons
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                      child: Column(
                        children: [
                          // Two paid buttons side by side
                          Row(
                            children: [
                              // Cash button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    onPaid('cash');
                                  },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF10B981),
                                          Color(0xFF059669),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x4010B981),
                                          blurRadius: 12,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.payments_rounded,
                                            size: 20, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(
                                          'Tiền mặt',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              // Transfer button
                              Expanded(
                                child: GestureDetector(
                                  onTap: () {
                                    Navigator.pop(ctx);
                                    onPaid('transfer');
                                  },
                                  child: Container(
                                    height: 52,
                                    decoration: BoxDecoration(
                                      gradient: const LinearGradient(
                                        begin: Alignment.topCenter,
                                        end: Alignment.bottomCenter,
                                        colors: [
                                          Color(0xFF3B82F6),
                                          Color(0xFF2563EB),
                                        ],
                                      ),
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Color(0x403B82F6),
                                          blurRadius: 12,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.account_balance_rounded,
                                            size: 20, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text(
                                          'Chuyển khoản',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w700,
                                            fontSize: 14,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          // Deferred payment
                          GestureDetector(
                            onTap: () {
                              Navigator.pop(ctx);
                              onUnpaid();
                            },
                            child: Container(
                              width: double.infinity,
                              height: 48,
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFFBEB),
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                    color: const Color(0xFFF59E0B),
                                    width: 1.5),
                              ),
                              child: const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.schedule_rounded,
                                      size: 18, color: Color(0xFFF59E0B)),
                                  SizedBox(width: 8),
                                  Text(
                                    'Thanh toán sau',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: Color(0xFFF59E0B),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      );
    },
  );
}

/// Builds the QR / bank info / prompt section for the payment dialog.
Widget _buildPaymentInfo(storeInfo) {
  final hasQr = storeInfo.qrImageUrl.isNotEmpty;
  final hasBank = storeInfo.bankId.isNotEmpty &&
      storeInfo.bankAccount.isNotEmpty &&
      storeInfo.bankOwner.isNotEmpty;

  if (hasQr) {
    // Show QR image
    Uint8List? qrBytes;
    try {
      final base64Part = storeInfo.qrImageUrl.split(',').last;
      qrBytes = base64Decode(base64Part);
    } catch (_) {}

    return Container(
      width: 280,
      height: 280,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: qrBytes != null
          ? ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.memory(
                qrBytes,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Icon(Icons.broken_image, size: 40, color: AppColors.slate300),
                ),
              ),
            )
          : const Center(
              child: Icon(Icons.qr_code_rounded, size: 80, color: AppColors.slate300),
            ),
    );
  }

  if (hasBank) {
    // Show bank text info
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.slate50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.slate200),
      ),
      child: Column(
        children: [
          const Icon(Icons.account_balance_rounded, size: 28, color: AppColors.emerald500),
          const SizedBox(height: 8),
          Text(
            storeInfo.bankId,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.slate700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            storeInfo.bankAccount,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.slate800,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            storeInfo.bankOwner,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.slate500,
            ),
          ),
        ],
      ),
    );
  }

  // No QR and no bank info — show prompt
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF7ED),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
    ),
    child: const Column(
      children: [
        Icon(Icons.info_outline_rounded, size: 28, color: Color(0xFFF59E0B)),
        SizedBox(height: 8),
        Text(
          'Chưa có thông tin thanh toán',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Color(0xFFB45309),
          ),
        ),
        SizedBox(height: 4),
        Text(
          'Vào Cài đặt → Thông tin cửa hàng để chọn ảnh QR hoặc nhập STK ngân hàng',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            color: Color(0xFFD97706),
          ),
        ),
      ],
    ),
  );
}
