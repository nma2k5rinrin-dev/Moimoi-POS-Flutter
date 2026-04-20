import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/features/premium/logic/premium_store_standalone.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';

void showPaymentHistoryDialog(BuildContext context) {
  showAnimatedDialog(
    context: context,
    builder: (ctx) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(24),
      child: _PaymentHistoryDialogContent(),
    ),
  );
}

class _PaymentHistoryDialogContent extends StatelessWidget {
  const _PaymentHistoryDialogContent();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<PremiumStore>();
    final payments = store.premiumPayments;

    return Container(
      width: double.infinity,
      constraints: BoxConstraints(
        maxWidth: 480,
        maxHeight: MediaQuery.of(context).size.height * 0.7,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 12, 16),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: AppColors.primary50,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.history_rounded,
                    color: AppColors.primary500,
                    size: 20,
                  ),
                ),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Lịch sử thanh toán',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.slate800,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close_rounded,
                    color: AppColors.slate400,
                    size: 22,
                  ),
                  splashRadius: 20,
                ),
              ],
            ),
          ),
          Container(height: 1, color: AppColors.slate200),
          // Content
          Flexible(
            child: payments.isEmpty
                ? Padding(
                    padding: EdgeInsets.all(40),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.receipt_long_outlined,
                          size: 48,
                          color: AppColors.slate300,
                        ),
                        SizedBox(height: 12),
                        Text(
                          'Chưa có giao dịch nào',
                          style: TextStyle(
                            color: AppColors.slate400,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    shrinkWrap: true,
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    itemCount: payments.length,
                    itemBuilder: (ctx, i) {
                      final p = payments[i];
                      return Container(
                        margin: EdgeInsets.only(bottom: 10),
                        padding: EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Color(0xFFF8FAFC), // slate-50
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.slate200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: AppColors.primary100,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                Icons.workspace_premium_rounded,
                                color: AppColors.primary600,
                                size: 18,
                              ),
                            ),
                            SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    p.planName,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.slate800,
                                      fontSize: 14,
                                    ),
                                  ),
                                  SizedBox(height: 2),
                                  Text(
                                    'Giá: ${_formatCurrency(p.amount)} (${p.months} tháng)',
                                    style: TextStyle(
                                      color: AppColors.slate500,
                                      fontSize: 12,
                                    ),
                                  ),
                                  SizedBox(height: 4),
                                  Text(
                                    'Vào lúc: ${_formatTime(p.paidAt)}', // need helper format
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.slate400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Success Status badge
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.primary50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                'Thành công',
                                style: TextStyle(
                                  color: AppColors.primary600,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }

  String _formatCurrency(int amount) {
    if (amount >= 1000) {
      final s = amount.toString();
      final buffer = StringBuffer();
      int count = 0;
      for (int i = s.length - 1; i >= 0; i--) {
        if (count != 0 && count % 3 == 0) {
          buffer.write('.');
        }
        buffer.write(s[i]);
        count++;
      }
      return '${buffer.toString().split('').reversed.join()} ₫';
    }
    return '$amount ₫';
  }
}
