import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'package:moimoi_pos/features/notifications/presentation/notification_bell.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:convert';
import 'dart:math';

// Color palette (mirrors admin_dashboard_page.dart for consistent coloring)
const _storeColors = [
  [Color(0xFF10B981), Color(0xFF059669)],
  [Color(0xFF6366F1), Color(0xFF4F46E5)],
  [Color(0xFFF59E0B), Color(0xFFD97706)],
  [Color(0xFFF97316), Color(0xFFEA580C)],
  [Color(0xFF3B82F6), Color(0xFF2563EB)],
  [Color(0xFFEC4899), Color(0xFFDB2777)],
  [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
  [Color(0xFF14B8A6), Color(0xFF0D9488)],
];

// ═══════════════════════════════════════════════════════════
// STORE DETAIL PAGE (Sadmin → Tap on store card)
// ═══════════════════════════════════════════════════════════
class StoreDetailPage extends StatefulWidget {
  final String storeId;
  final StoreInfoModel info;
  final ManagementStore store;
  final int colorIndex;

  const StoreDetailPage({
    super.key,
    required this.storeId,
    required this.info,
    required this.store,
    required this.colorIndex,
  });

  @override
  State<StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<StoreDetailPage> {
  bool _isLoadingStats = true;
  int _staffCount = 0;
  final int _productCount = 0;
  final int _orderCount = 0;
  final double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    await Future.delayed(Duration(milliseconds: 600));
    if (!mounted) return;
    setState(() {
      _staffCount = widget.store.users
          .where((u) => u.createdBy == widget.storeId && u.role != 'admin')
          .length;
      _isLoadingStats = false;
    });
  }

  String _fmtCurrency(double amount) {
    if (amount == 0) return '0đ';
    final formatted = amount
        .toStringAsFixed(0)
        .replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]},',
        );
    return '${formatted}đ';
  }

  String _formatDateString(DateTime? dt) {
    if (dt == null) return 'N/A';
    try {
      final localDt = dt.toLocal();
      return '${localDt.day.toString().padLeft(2, '0')}/${localDt.month.toString().padLeft(2, '0')}/${localDt.year}';
    } catch (_) { return dt.toString(); }
  }

  String _formatCurrency(int amount) {
    if (amount == 0) return '0đ';
    final formatted = amount.toString().replaceAllMapped(
      RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return '${formatted}đ';
  }

  @override
  Widget build(BuildContext context) {
    final colors = _storeColors[widget.colorIndex % _storeColors.length];
    final storeName = widget.info.name.isNotEmpty
        ? widget.info.name
        : widget.storeId;
    final isPremium = widget.info.isPremium;
    final isActive = context
        .watch<ManagementStore>()
        .users
        .any((u) => u.username == widget.storeId && u.isOnline);

    return Scaffold(
      backgroundColor: Color(0xFFF4F7FA),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        title: Text(
          'Hồ sơ doanh nghiệp',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.slate800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildSleekHero(context, storeName, isActive, isPremium, colors),
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _buildDenseMetrics(),
            ),
            SizedBox(height: 24),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: _buildBusinessInfoCard(),
            ),
            SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildSleekHero(
    BuildContext context,
    String storeName,
    bool isActive,
    bool isPremium,
    List<Color> colors,
  ) {
    final pendingRequest = context.watch<ManagementStore>().upgradeRequests.where((r) => r.storeId == widget.storeId && r.status == 'pending').firstOrNull;

    return Container(
      color: Colors.transparent,
      padding: EdgeInsets.fromLTRB(20, 24, 20, 24),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Builder(
                builder: (context) {
                  final avatarWidget = Builder(
                    builder: (_) {
                      if (widget.info.logoUrl.isNotEmpty) {
                        if (CloudflareService.isUrl(widget.info.logoUrl))
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: CachedNetworkImage(
                              imageUrl: widget.info.logoUrl,
                              fit: BoxFit.cover,
                            ),
                          );
                        try {
                          return ClipRRect(
                            borderRadius: BorderRadius.circular(24),
                            child: Image.memory(
                              base64Decode(widget.info.logoUrl.split(',').last),
                              fit: BoxFit.cover,
                            ),
                          );
                        } catch (_) {}
                      }
                      return Icon(Icons.storefront, color: Colors.white, size: 36);
                    },
                  );

                  if (isPremium) {
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Color(0xFFFFDF00), Color(0xFFD4AF37), Color(0xFFB8860B)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: avatarWidget,
                    );
                  } else {
                    return Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: colors,
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: avatarWidget,
                    );
                  }
                },
              ),
              if (isPremium)
                Positioned(
                  bottom: -8,
                  right: -8,
                  child: Container(
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2))],
                    ),
                    child: Icon(Icons.workspace_premium_rounded, color: Color(0xFFD97706), size: 24),
                  ),
                ),
            ],
          ),
          SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                storeName,
                style: TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: isPremium ? Color(0xFFB45309) : AppColors.slate900,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
          SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? AppColors.primary50 : AppColors.slate100,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: isActive ? AppColors.primary200 : AppColors.slate200),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 6, height: 6,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: isActive ? AppColors.primary500 : AppColors.slate400,
                      ),
                    ),
                    SizedBox(width: 6),
                    Text(
                      isActive ? 'Đang hoạt động' : 'Ngoại tuyến',
                      style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w700,
                        color: isActive ? AppColors.primary700 : AppColors.slate600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.slate50,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppColors.slate200),
                ),
                child: Text(
                  widget.storeId,
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500),
                ),
              ),
              if (widget.info.createdAt != null) ...[
                SizedBox(width: 8),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.calendar_today_outlined, size: 11, color: AppColors.slate400),
                      SizedBox(width: 4),
                      Text(
                        _formatDateString(widget.info.createdAt),
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          _buildHeroPlanStatus(context, isPremium, pendingRequest),
          SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _heroActionBtn(Icons.edit_outlined, 'Chỉnh sửa', Colors.blue, _showEditStoreDialog),
              SizedBox(width: 16),
              _heroActionBtn(
                Icons.notifications_outlined, 'Thông báo', Colors.purple,
                () => showBroadcastDialog(context, context.read<UIStore>(), specificStoreId: widget.storeId, specificStoreName: storeName),
              ),
              SizedBox(width: 16),
              _heroActionBtn(Icons.lock_outline, 'Đóng băng', Colors.red, _showDeleteConfirm),
            ],
          ),
        ],
      ),
    );
  }

  void _showApproveDialog(BuildContext context, dynamic req) {
    int expectedMonths = 1;
    final pn = req.planName.toLowerCase();
    if (pn.contains('3 tháng')) expectedMonths = 3;
    else if (pn.contains('6 tháng')) expectedMonths = 6;
    else if (pn.contains('1 năm') || pn.contains('12 tháng')) expectedMonths = 12;

    final requestDate = DateTime.tryParse(req.createdAt) ?? DateTime.now();
    DateTime baseDate = DateTime.now();
    final targetUser = context.read<ManagementStore>().users.where((u) => u.username == req.storeId || u.createdBy == req.storeId).firstOrNull;
    if (targetUser?.expiresAt != null) {
      final currentExpiry = DateTime.tryParse(targetUser!.expiresAt!) ?? DateTime.now();
      if (currentExpiry.isAfter(DateTime.now())) baseDate = currentExpiry;
    }

    final expectedExpiryDate = baseDate.add(Duration(days: expectedMonths * 30));
    final String formattedRequestDate = '${requestDate.day.toString().padLeft(2,'0')}/${requestDate.month.toString().padLeft(2,'0')}/${requestDate.year}';
    final String formattedExpiryDate = '${expectedExpiryDate.day.toString().padLeft(2,'0')}/${expectedExpiryDate.month.toString().padLeft(2,'0')}/${expectedExpiryDate.year}';

    showDialog(
      context: context,
      builder: (dialogCtx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.all(20),
        child: Container(
          width: double.infinity,
          constraints: BoxConstraints(maxWidth: 400),
          decoration: BoxDecoration(color: AppColors.cardBg, borderRadius: BorderRadius.circular(24)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Row(
                  children: [
                    Icon(Icons.workspace_premium_rounded, color: Color(0xFFF59E0B), size: 28),
                    SizedBox(width: 12),
                    Expanded(child: Text('Xác nhận phê duyệt', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800))),
                  ],
                ),
              ),
              Divider(height: 1, color: AppColors.slate200),
              Padding(
                padding: EdgeInsets.all(24),
                child: Container(
                  padding: EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: AppColors.orange50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Color(0xFFF59E0B).withValues(alpha: 0.5)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _approveRow(Icons.storefront_rounded, 'Mã cửa hàng:', req.storeId),
                      Divider(color: Color(0xFFF59E0B).withValues(alpha: 0.2), height: 24),
                      _approveRow(Icons.calendar_month_rounded, 'Gói yêu cầu:', req.planName),
                      Divider(color: Color(0xFFF59E0B).withValues(alpha: 0.2), height: 24),
                      _approveRow(Icons.add_task_rounded, 'Ngày đăng ký:', formattedRequestDate),
                      SizedBox(height: 12),
                      _approveRow(Icons.event_busy_rounded, 'Dự kiến hết hạn:', formattedExpiryDate),
                      Divider(color: Color(0xFFF59E0B).withValues(alpha: 0.2), height: 24),
                      Row(
                        children: [
                          Icon(Icons.payments_rounded, color: Color(0xFFF59E0B), size: 20),
                          SizedBox(width: 8),
                          Text('Thanh toán:', style: TextStyle(color: AppColors.slate600, fontSize: 13, fontWeight: FontWeight.w600)),
                          Spacer(),
                          Text(_formatCurrency(req.amount), style: TextStyle(color: AppColors.primary600, fontSize: 16, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(24, 0, 24, 24),
                child: Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () => Navigator.pop(dialogCtx),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.slate100, foregroundColor: AppColors.slate700,
                            elevation: 0, padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Hủy bỏ', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: SizedBox(
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(dialogCtx);
                            context.read<ManagementStore>().showToast('Đang phê duyệt...', 'info');
                            await context.read<ManagementStore>().approveVIPRequest(req.id);
                            if (context.mounted) {
                              context.read<ManagementStore>().showToast('Đã phê duyệt gói Premium thành công!', 'success');
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.blue500, foregroundColor: Colors.white,
                            elevation: 0, padding: EdgeInsets.zero,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          ),
                          child: Text('Phê duyệt', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
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
    );
  }

  Widget _approveRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: Color(0xFFF59E0B), size: 20),
        SizedBox(width: 8),
        Text(label, style: TextStyle(color: AppColors.slate600, fontSize: 13, fontWeight: FontWeight.w600)),
        Spacer(),
        Text(value, style: TextStyle(color: AppColors.slate900, fontSize: 14, fontWeight: FontWeight.w700)),
      ],
    );
  }

  Widget _heroActionBtn(IconData icon, String label, MaterialColor color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.shade50, shape: BoxShape.circle),
            child: Icon(icon, color: color.shade600, size: 22),
          ),
          SizedBox(height: 6),
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate600)),
        ],
      ),
    );
  }

  Widget _buildDenseMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text('TỔNG QUAN HỆ THỐNG',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slate400, letterSpacing: 1.2)),
        ),
        _isLoadingStats
            ? Center(child: Padding(padding: EdgeInsets.all(40), child: CircularProgressIndicator()))
            : Row(
                children: [
                  _denseMetric(Icons.shopping_bag_outlined, 'Sản phẩm', '$_productCount', Colors.purple),
                  SizedBox(width: 12),
                  _denseMetric(Icons.people_outline, 'Nhân sự', '$_staffCount', Colors.blue),
                ],
              ),
        if (!_isLoadingStats) ...[
          SizedBox(height: 12),
          Row(
            children: [
              _denseMetric(Icons.receipt_long_outlined, 'Đơn hàng', '$_orderCount', Colors.orange),
              SizedBox(width: 12),
              _denseMetric(Icons.account_balance_wallet_outlined, 'Doanh thu', _fmtCurrency(_totalRevenue), Colors.teal),
            ],
          ),
        ],
      ],
    );
  }

  Widget _denseMetric(IconData icon, String label, String val, MaterialColor mColor) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.slate100),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: Offset(0, 4))],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 20, color: mColor.shade500),
            SizedBox(height: 12),
            Text(val, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate900), maxLines: 1, overflow: TextOverflow.ellipsis),
            SizedBox(height: 2),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate500)),
          ],
        ),
      ),
    );
  }

  Widget _buildBusinessInfoCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: 4, bottom: 12),
          child: Text('THÔNG TIN LIÊN HỆ',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.slate400, letterSpacing: 1.2)),
        ),
        Container(
          padding: EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.slate100),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: Offset(0, 4))],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _infoItem(Icons.tag, 'Mã số thuế', widget.info.taxId.isNotEmpty ? widget.info.taxId : 'Chưa cập nhật')),
                  Expanded(child: _infoItem(Icons.access_time, 'Giờ mở cửa', widget.info.openHours.isNotEmpty ? widget.info.openHours : 'Chưa cập nhật')),
                ],
              ),
              SizedBox(height: 20),
              _infoItem(Icons.location_on_outlined, 'Địa chỉ đăng ký', widget.info.address.isNotEmpty ? widget.info.address : 'Chưa cập nhật'),
              SizedBox(height: 20),
              _infoItem(Icons.event_outlined, 'Ngày gia nhập', widget.info.createdAt != null ? _formatDateString(widget.info.createdAt) : 'Không xác định'),
              Divider(height: 32, color: AppColors.slate100),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.all(10),
                    decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.account_balance_outlined, size: 20, color: AppColors.slate600),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Tài khoản ngân hàng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate500)),
                        SizedBox(height: 4),
                        Text(
                          widget.info.bankAccount.isEmpty ? 'Chưa cấu hình' : '${widget.info.bankId} • ${widget.info.bankAccount}',
                          style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800),
                        ),
                        if (widget.info.bankOwner.isNotEmpty)
                          Text(widget.info.bankOwner, style: TextStyle(fontSize: 12, color: AppColors.slate500)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _infoItem(IconData icon, String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 14, color: AppColors.slate400),
            SizedBox(width: 6),
            Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.slate500)),
          ],
        ),
        SizedBox(height: 6),
        Text(value, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate800)),
      ],
    );
  }

  Widget _buildHeroPlanStatus(BuildContext context, bool isPremium, dynamic pendingRequest) {
    return Container(
      margin: EdgeInsets.only(top: 20),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isPremium || pendingRequest != null ? Color(0xFFFDE68A) : AppColors.slate200),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 8, offset: Offset(0, 2))],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: isPremium || pendingRequest != null ? Color(0xFFFEF3C7) : AppColors.slate50,
              shape: BoxShape.circle,
            ),
            child: Icon(
              pendingRequest != null ? Icons.hourglass_top_rounded : (isPremium ? Icons.workspace_premium_rounded : Icons.local_activity_rounded),
              color: isPremium || pendingRequest != null ? Color(0xFFD97706) : AppColors.slate500,
              size: 22,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pendingRequest != null ? 'Yêu cầu: ${pendingRequest.planName}' : (isPremium ? 'MoiMoi Premium' : 'Gói Cơ Bản'),
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: pendingRequest != null ? Color(0xFFB45309) : AppColors.slate800),
                ),
                SizedBox(height: 4),
                if (pendingRequest != null) ...[
                  Text('Đăng ký: ${_formatDateString(DateTime.tryParse(pendingRequest.createdAt.toString()))}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate600)),
                  Text('Thanh toán: ${_fmtCurrency(pendingRequest.amount)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primary600)),
                  SizedBox(height: 2),
                  Text(
                    isPremium ? 'Gói đang dùng: Hết hạn ${_formatDateString(widget.info.premiumExpiresAt)}' : 'Gói đang dùng: Cơ Bản',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: AppColors.slate400)),
                ] else if (isPremium) ...[
                  Text('Kích hoạt: ${_formatDateString(widget.info.createdAt)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate500)),
                  Text('Hết hạn: ${_formatDateString(widget.info.premiumExpiresAt)}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Color(0xFFD97706))),
                ] else ...[
                  Text('Giới hạn tính năng', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.slate500)),
                ]
              ],
            ),
          ),
          SizedBox(width: 8),
          if (pendingRequest != null)
            ElevatedButton(
              onPressed: () => _showApproveDialog(context, pendingRequest),
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFF59E0B), foregroundColor: Colors.white,
                elevation: 0, padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Duyệt', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            )
          else
            TextButton(
              onPressed: () => context.read<UIStore>().showToast('Tính năng nâng cấp đang phát triển', 'info'),
              style: TextButton.styleFrom(
                foregroundColor: isPremium ? Color(0xFFD97706) : Colors.blue,
                backgroundColor: isPremium ? Color(0xFFFEF3C7) : AppColors.slate50,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text(isPremium ? 'Gia hạn' : 'Nâng cấp', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
            ),
        ],
      ),
    );
  }

  void _showEditStoreDialog() {
    final nameCtrl = TextEditingController(text: widget.info.name);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Sửa cửa hàng', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
        content: TextField(
          controller: nameCtrl,
          decoration: InputDecoration(
            labelText: 'Tên cửa hàng',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
            prefixIcon: Icon(Icons.storefront),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              widget.store.updateStoreInfoById(widget.storeId, widget.info.copyWith(name: nameCtrl.text.trim()));
              context.read<UIStore>().showToast('Đã cập nhật!');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary500, foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Lưu', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm() {
    final storeName = widget.info.name.isNotEmpty ? widget.info.name : widget.storeId;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text('Xóa cửa hàng?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFFEF4444))),
          ],
        ),
        content: Text('Xóa tài khoản "$storeName"?', style: TextStyle(fontSize: 14, color: AppColors.slate600)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            onPressed: () {
              widget.store.deleteStore(widget.storeId);
              context.read<UIStore>().showToast('Đã xoá cửa hàng "$storeName"');
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEF4444), foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Khóa ngay', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// SPARKLINE PAINTER
// ═══════════════════════════════════════════════════════════
class SparklinePainter extends CustomPainter {
  final List<double> data;
  final Color color;

  SparklinePainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty || data.every((val) => val == 0)) return;

    final paint = Paint()
      ..color = color
      ..strokeWidth = 2.0
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        colors: [color.withValues(alpha: 0.4), color.withValues(alpha: 0.0)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    final double maxVal = data.reduce(max) == 0 ? 1 : data.reduce(max);
    final double minVal = data.reduce(min);
    final double range = maxVal - minVal;

    final path = Path();
    final fillPath = Path();
    final stepX = data.length > 1 ? size.width / (data.length - 1) : size.width;

    for (int i = 0; i < data.length; i++) {
      final x = i * stepX;
      final normalizedY = range == 0 ? 0.5 : (data[i] - minVal) / range;
      final y = size.height - (normalizedY * size.height * 0.8 + size.height * 0.1);
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        path.lineTo(x, y);
        fillPath.lineTo(x, y);
      }
    }

    if (data.length > 1) {
      fillPath.lineTo(size.width, size.height);
      fillPath.close();
      canvas.drawPath(fillPath, fillPaint);
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant SparklinePainter oldDelegate) =>
      oldDelegate.data != data || oldDelegate.color != color;
}
