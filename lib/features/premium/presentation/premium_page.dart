import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';

class PremiumPage extends StatefulWidget {
  const PremiumPage({super.key});

  @override
  State<PremiumPage> createState() => _PremiumPageState();
}

class _PremiumPageState extends State<PremiumPage>
    with SingleTickerProviderStateMixin {
  int _selectedPlan = 1; // Default to 3-month (popular)
  late AnimationController _shimmerCtrl;
  String? _paymentView; // null = plan selection, 'payment' = QR payment screen
  String _transferContent = '';
  int _paymentAmount = 0;
  Timer? _pollTimer;
  bool _justApproved = false;

  static const List<_PlanInfo> _plans = [
    _PlanInfo(
      name: '1 Tháng',
      totalPrice: 250000,
      pricePerMonth: 250000,
      discount: 0,
      badge: '',
      badgeColor: Colors.transparent,
      icon: Icons.calendar_today,
    ),
    _PlanInfo(
      name: '3 Tháng',
      totalPrice: 600000,
      pricePerMonth: 200000,
      discount: 20,
      badge: 'Phổ biến',
      badgeColor: Color(0xFF10B981),
      icon: Icons.event_available,
    ),
    _PlanInfo(
      name: '6 Tháng',
      totalPrice: 900000,
      pricePerMonth: 150000,
      discount: 40,
      badge: 'Tốt nhất',
      badgeColor: Color(0xFFD97706),
      icon: Icons.star,
    ),
    _PlanInfo(
      name: '1 Năm',
      totalPrice: 1500000,
      pricePerMonth: 125000,
      discount: 50,
      badge: 'Siêu tiết kiệm',
      badgeColor: Color(0xFF7C3AED),
      icon: Icons.diamond,
    ),
  ];

  static const List<_FeatureItem> _features = [
    _FeatureItem(Icons.people, 'Nhân viên không giới hạn'),
    _FeatureItem(Icons.table_bar, 'Bàn & khu vực không giới hạn'),
    _FeatureItem(Icons.restaurant_menu, 'Sản phẩm không giới hạn'),
    _FeatureItem(Icons.receipt_long, 'Đơn hàng không giới hạn'),
    _FeatureItem(Icons.qr_code, 'Thanh toán QR ngân hàng'),
    _FeatureItem(Icons.support_agent, 'Hỗ trợ ưu tiên 24/7'),
    _FeatureItem(Icons.analytics, 'Báo cáo nâng cao'),
    _FeatureItem(Icons.cloud_sync, 'Đồng bộ đa thiết bị'),
  ];

  @override
  void initState() {
    super.initState();
    _shimmerCtrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    // Auto-detect existing pending request and restore payment view
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkExistingRequest();
    });
  }

  void _checkExistingRequest() {
    final store = context.read<AppStore>();
    final username = store.currentUser?.username ?? '';
    final myReq = store.upgradeRequests
        .where((r) => r.username == username && r.status == 'pending')
        .toList();
    if (myReq.isNotEmpty) {
      final req = myReq.first;
      setState(() {
        _paymentView = 'payment';
        _transferContent = req.transferContent;
        _paymentAmount = req.amount;
        _selectedPlan = req.planIndex;
      });
      _startPolling();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      _pollPaymentStatus();
    });
  }

  void _stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> _pollPaymentStatus() async {
    try {
      final store = context.read<AppStore>();
      final username = store.currentUser?.username ?? '';
      final data = await Supabase.instance.client
          .from('upgrade_requests')
          .select()
          .eq('username', username)
          .eq('status', 'approved')
          .limit(1);
      if ((data as List).isNotEmpty && mounted) {
        _stopPolling();
        // Trigger realtime-like update in store
        final approved = data.first;
        store.upgradeRequests = store.upgradeRequests
            .map((r) => r.id == approved['id'] ? r.copyWith(status: 'approved') : r)
            .toList();
        store.notifyListeners();
        setState(() => _justApproved = true);
      }
    } catch (e) {
      debugPrint('[PollPayment] Error: $e');
    }
  }

  @override
  void dispose() {
    _stopPolling();
    _shimmerCtrl.dispose();
    super.dispose();
  }

  String _formatCurrency(int amount) {
    final str = amount.toString();
    final buffer = StringBuffer();
    int count = 0;
    for (int i = str.length - 1; i >= 0; i--) {
      buffer.write(str[i]);
      count++;
      if (count % 3 == 0 && i != 0) buffer.write('.');
    }
    return '${buffer.toString().split('').reversed.join('')}đ';
  }

  void _handleRegister() {
    final store = context.read<AppStore>();
    final user = store.currentUser;
    if (user == null) return;

    final plan = _plans[_selectedPlan];
    const planMonths = [1, 3, 6, 12];
    final storeName = store.currentStoreInfo.name.isNotEmpty
        ? store.currentStoreInfo.name
        : user.username;
    final cleanStoreName = storeName.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    final cleanPlanName = plan.name.toUpperCase().replaceAll(' ', '');
    final transferContent = '$cleanStoreName $cleanPlanName';

    store.requestUpgrade(
      user.username,
      _selectedPlan,
      plan.name,
      planMonths[_selectedPlan],
    );

    setState(() {
      _paymentView = 'payment';
      _transferContent = transferContent;
      _paymentAmount = plan.totalPrice;
    });
    _startPolling();
  }

  @override
  Widget build(BuildContext context) {
    if (_paymentView == 'payment') {
      return _buildPaymentScreen();
    }

    final plan = _plans[_selectedPlan];

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Column(
            children: [
              _buildFeatureCard(),
              const SizedBox(height: 20),
              _buildPlansSection(plan),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  // ── Payment Screen ──
  Widget _buildPaymentScreen() {
    final store = context.watch<AppStore>();
    // Check if the request has been approved via realtime
    final myReq = store.upgradeRequests
        .where((r) => r.username == store.currentUser?.username)
        .toList();
    final isPaid = myReq.isNotEmpty && myReq.first.status == 'approved';

    // Get sadmin bank config
    final sadminInfo = store.storeInfos['sadmin'] ?? const StoreInfoModel();
    final bankName = sadminInfo.bankId.isNotEmpty ? sadminInfo.bankId : 'Chưa cấu hình';
    final bankAccount = sadminInfo.bankAccount.isNotEmpty ? sadminInfo.bankAccount : 'Chưa cấu hình';
    final bankOwner = sadminInfo.bankOwner.isNotEmpty ? sadminInfo.bankOwner : 'Chưa cấu hình';
    final hasBankConfig = sadminInfo.bankId.isNotEmpty && sadminInfo.bankAccount.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  children: [
                    // Status header
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: isPaid ? const Color(0xFFF0FDF4) : const Color(0xFFFFFBEB),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isPaid ? AppColors.emerald200 : const Color(0xFFFDE68A),
                        ),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            isPaid ? Icons.check_circle : Icons.hourglass_top_rounded,
                            size: 48,
                            color: isPaid ? AppColors.emerald500 : const Color(0xFFD97706),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            isPaid ? 'Thanh toán thành công!' : 'Chờ thanh toán',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: isPaid ? AppColors.emerald700 : const Color(0xFF92400E),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            isPaid
                                ? 'Premium đã được kích hoạt!'
                                : 'Chuyển khoản theo thông tin bên dưới',
                            style: TextStyle(
                              fontSize: 13,
                              color: isPaid ? AppColors.emerald600 : const Color(0xFFB45309),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    if (!isPaid) ...[
                      // Bank info card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.04),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.account_balance, size: 20, color: AppColors.emerald600),
                                SizedBox(width: 8),
                                Text('Thông tin chuyển khoản',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                              ],
                            ),
                            const SizedBox(height: 16),

                            if (!hasBankConfig)
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFFEF2F2),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: AppColors.red200),
                                ),
                                child: const Text(
                                  'Chưa cấu hình thông tin ngân hàng. Vui lòng liên hệ quản trị viên.',
                                  style: TextStyle(fontSize: 13, color: AppColors.red600),
                                ),
                              )
                            else ...[
                              _bankInfoRow('Ngân hàng', bankName),
                              _bankInfoRow('Số tài khoản', bankAccount, copyable: true),
                              _bankInfoRow('Chủ tài khoản', bankOwner),
                            ],
                            _bankInfoRow('Số tiền', _formatCurrency(_paymentAmount)),
                            _bankInfoRow('Nội dung CK', _transferContent, copyable: true, highlight: true),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Warning
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF2F2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.red200),
                        ),
                        child: const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 20, color: AppColors.red500),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Vui lòng nhập đúng nội dung chuyển khoản để hệ thống tự động xác nhận. '
                                'Thời gian xử lý: 1-5 phút sau khi thanh toán.',
                                style: TextStyle(fontSize: 13, color: AppColors.red600, height: 1.4),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // QR Code
                      if (hasBankConfig)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              const Text('Quét mã QR để chuyển khoản',
                                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate700)),
                              const SizedBox(height: 16),
                              // VietQR image
                              Container(
                                width: 220,
                                height: 220,
                                decoration: BoxDecoration(
                                  color: AppColors.slate50,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: AppColors.slate200),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(16),
                                  child: Image.network(
                                    'https://img.vietqr.io/image/${Uri.encodeComponent(bankName)}-${bankAccount.replaceAll(' ', '')}-compact2.jpg'
                                    '?amount=$_paymentAmount'
                                    '&addInfo=${Uri.encodeComponent(_transferContent)}'
                                    '&accountName=${Uri.encodeComponent(bankOwner)}',
                                    fit: BoxFit.contain,
                                    loadingBuilder: (ctx, child, progress) {
                                      if (progress == null) return child;
                                      return const Center(
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: AppColors.emerald500,
                                        ),
                                      );
                                    },
                                    errorBuilder: (ctx, error, stack) => const Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      children: [
                                        Icon(Icons.qr_code_2, size: 60, color: AppColors.slate300),
                                        SizedBox(height: 8),
                                        Text('Không tải được QR',
                                            style: TextStyle(fontSize: 12, color: AppColors.slate400)),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                'VietQR • $bankName',
                                style: TextStyle(fontSize: 12, color: AppColors.slate400),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),

        // Bottom button
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: GestureDetector(
              onTap: () {
                if (isPaid) {
                  // Go back to plan selection
                  setState(() => _paymentView = null);
                } else {
                  // Go back to plan selection and cancel the pending request
                  setState(() => _paymentView = null);
                }
              },
              child: Container(
                height: 52,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      isPaid ? Icons.check_rounded : Icons.arrow_back_rounded,
                      size: 18,
                      color: isPaid ? AppColors.emerald600 : AppColors.slate500,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      isPaid ? 'Hoàn tất' : 'Quay lại chọn gói',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: isPaid ? AppColors.emerald600 : AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _bankInfoRow(String label, String value, {bool copyable = false, bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label,
                style: const TextStyle(fontSize: 13, color: AppColors.slate500, fontWeight: FontWeight.w500)),
          ),
          Expanded(
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: highlight
                        ? const EdgeInsets.symmetric(horizontal: 8, vertical: 4)
                        : EdgeInsets.zero,
                    decoration: highlight
                        ? BoxDecoration(
                            color: const Color(0xFFF0FDF4),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: AppColors.emerald200),
                          )
                        : null,
                    child: Text(
                      value,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: highlight ? AppColors.emerald700 : AppColors.slate800,
                      ),
                    ),
                  ),
                ),
                if (copyable) ...[
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: value.replaceAll(' ', '')));
                      context.read<AppStore>().showToast('Đã sao chép!');
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(Icons.copy_rounded, size: 14, color: AppColors.slate500),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


  // ── Feature Card ──
  Widget _buildFeatureCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.verified,
                    color: AppColors.emerald500, size: 20),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tính năng Premium',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: AppColors.slate800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(_features.length, (i) {
            final f = _features[i];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: const Color(0xFFECFDF5),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child:
                        Icon(f.icon, size: 16, color: AppColors.emerald500),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      f.label,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: AppColors.slate700,
                        height: 1.3,
                      ),
                    ),
                  ),
                  const Icon(Icons.check_circle,
                      size: 18, color: AppColors.emerald500),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Plans Section ──
  Widget _buildPlansSection(_PlanInfo plan) {
    return Column(
      children: [
        // Plan Cards
        ...List.generate(_plans.length, (i) => _buildPlanCard(i)),

        const SizedBox(height: 20),

        // CTA Button
        GestureDetector(
          onTap: _handleRegister,
          child: Container(
            width: double.infinity,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: AppColors.emerald500,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.payment_rounded, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Đăng ký ngay — ${_formatCurrency(plan.totalPrice)}',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 14),

        // Disclaimer
        Text(
          'Hủy bất kỳ lúc nào. Không tự động gia hạn.',
          style: TextStyle(
            fontSize: 12,
            color: AppColors.slate400,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  // ── Plan Card ──
  Widget _buildPlanCard(int index) {
    final plan = _plans[index];
    final isSelected = _selectedPlan == index;
    final hasDiscount = plan.discount > 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: GestureDetector(
        onTap: () => setState(() => _selectedPlan = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: isSelected ? const Color(0xFFF0FDF4) : Colors.white,
            border: Border.all(
              color: isSelected ? AppColors.emerald500 : AppColors.slate200,
              width: isSelected ? 2 : 1,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.emerald500.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.03),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Row(
            children: [
              // Radio
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? AppColors.emerald500
                        : AppColors.slate300,
                    width: isSelected ? 7 : 2,
                  ),
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 14),

              // Plan info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(plan.icon,
                            size: 18,
                            color: isSelected
                                ? AppColors.emerald600
                                : AppColors.slate500),
                        const SizedBox(width: 8),
                        Text(
                          plan.name,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? AppColors.emerald700
                                : AppColors.slate800,
                          ),
                        ),
                        if (plan.badge.isNotEmpty) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: plan.badgeColor,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              plan.badge,
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (hasDiscount) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: AppColors.red50,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              '-${plan.discount}%',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: AppColors.red500,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Tiết kiệm ${_formatCurrency((250000 * _getMonths(index)) - plan.totalPrice)}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              // Price
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    _formatCurrency(plan.totalPrice),
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: isSelected
                          ? AppColors.emerald600
                          : AppColors.slate800,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${_formatCurrency(plan.pricePerMonth)}/th',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.slate400,
                      fontWeight: FontWeight.w500,
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

  int _getMonths(int planIndex) {
    switch (planIndex) {
      case 0:
        return 1;
      case 1:
        return 3;
      case 2:
        return 6;
      case 3:
        return 12;
      default:
        return 1;
    }
  }
}

// ── Data Models ──
class _PlanInfo {
  final String name;
  final int totalPrice;
  final int pricePerMonth;
  final int discount;
  final String badge;
  final Color badgeColor;
  final IconData icon;

  const _PlanInfo({
    required this.name,
    required this.totalPrice,
    required this.pricePerMonth,
    required this.discount,
    required this.badge,
    required this.badgeColor,
    required this.icon,
  });
}

class _FeatureItem {
  final IconData icon;
  final String label;
  const _FeatureItem(this.icon, this.label);
}
