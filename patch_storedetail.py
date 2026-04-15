import re

FILE_PATH = r"d:\Moimoi-POS-Flutter\lib\features\dashboard\presentation\admin\admin_dashboard_page.dart"

with open(FILE_PATH, "r", encoding="utf-8") as f:
    content = f.read()

new_class = """class _StoreDetailPage extends StatefulWidget {
  final String storeId;
  final StoreInfoModel info;
  final ManagementStore store;
  final int colorIndex;

  const _StoreDetailPage({
    required this.storeId,
    required this.info,
    required this.store,
    required this.colorIndex,
  });

  @override
  State<_StoreDetailPage> createState() => _StoreDetailPageState();
}

class _StoreDetailPageState extends State<_StoreDetailPage> {
  bool _isLoadingStats = true;
  int _staffCount = 0;
  int _productCount = 0;
  int _orderCount = 0;
  double _totalRevenue = 0.0;

  @override
  void initState() {
    super.initState();
    _loadStats();
  }

  Future<void> _loadStats() async {
    // Faking a small delay for realistic UX since we don't load full data for SAdmin yet
    await Future.delayed(Duration(milliseconds: 600));
    if (!mounted) return;
    
    // In actual implementation, we would query Supabase for these store-specific metrics
    setState(() {
      _staffCount = widget.store.users
          .where((u) => u.createdBy == widget.storeId && u.role != 'admin')
          .length;
      _productCount = 0; 
      _orderCount = 0;   
      _totalRevenue = 0.0;
      _isLoadingStats = false;
    });
  }

  String _fmtCurrency(double amount) {
    if (amount == 0) return '0đ';
    final formatted = amount.toStringAsFixed(0).replaceAllMapped(
      RegExp(r'(\\d{1,3})(?=(\\d{3})+(?!\\d))'),
      (m) => '${m[1]},',
    );
    return '$formattedđ';
  }

  int get _colorIndex => widget.colorIndex;
  StoreInfoModel get info => widget.info;
  String get storeId => widget.storeId;

  @override
  Widget build(BuildContext context) {
    final colors = _storeColors[_colorIndex % _storeColors.length];
    final storeName = info.name.isNotEmpty ? info.name : storeId;
    final isPremium = info.isPremium;

    final adminUser = context.watch<ManagementStore>().users
        .where((u) => u.username == storeId)
        .firstOrNull;
    final isActive = adminUser?.isOnline ?? false;

    return Scaffold(
      backgroundColor: Color(0xFFF8FAFC),
      body: CustomScrollView(
        slivers: [
          // ── App Bar with Gradient / Header ──
          SliverAppBar(
            expandedHeight: 180,
            pinned: true,
            backgroundColor: colors.first,
            elevation: 0,
            leading: Padding(
              padding: const EdgeInsets.all(8.0),
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.arrow_back_ios_new, size: 16, color: Colors.white),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: colors,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Stack(
                  children: [
                    // Decorative circles
                    Positioned(
                      top: -20,
                      right: -20,
                      child: Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                    Positioned(
                      bottom: -40,
                      left: 20,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          
          // ── Main Content ──
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: Offset(0, -40),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    // 1. Identity Card
                    _buildIdentityCard(storeName, isActive, colors),
                    SizedBox(height: 16),
                    
                    // 2. Metrics Grid
                    _buildMetricsGrid(),
                    SizedBox(height: 16),

                    // 3. Information List
                    _buildInfoSection(),
                    SizedBox(height: 16),

                    // 4. Subscription Card
                    _buildSubscriptionCard(isPremium),
                    SizedBox(height: 16),

                    // 5. Admin Actions
                    _buildAdminActions(),
                    SizedBox(height: 48), // Bottom padding
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 1. IDENTITY CARD
  Widget _buildIdentityCard(String storeName, bool isActive, List<Color> colors) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: AppColors.slate900.withValues(alpha: 0.05), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [BoxShadow(color: colors.first.withValues(alpha: 0.3), blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: Builder(
                  builder: (_) {
                    if (info.logoUrl.isNotEmpty) {
                      if (CloudflareService.isUrl(info.logoUrl)) {
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: CachedNetworkImage(
                            imageUrl: info.logoUrl,
                            fit: BoxFit.cover,
                            errorWidget: (_, __, ___) => Icon(Icons.storefront, color: Colors.white, size: 28),
                          ),
                        );
                      }
                      try {
                        final base64Part = info.logoUrl.split(',').last;
                        final bytes = base64Decode(base64Part);
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          child: Image.memory(bytes, fit: BoxFit.cover),
                        );
                      } catch (_) {}
                    }
                    return Icon(Icons.storefront, color: Colors.white, size: 28);
                  },
                ),
              ),
              SizedBox(width: 16),
              // Name and ID
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            storeName,
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate900),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        SizedBox(width: 8),
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isActive ? AppColors.emerald50 : AppColors.slate100,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: isActive ? AppColors.emerald200 : AppColors.slate200),
                          ),
                          child: Text(
                            isActive ? 'Online' : 'Offline',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: isActive ? AppColors.emerald600 : AppColors.slate500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6),
                    Text(
                      'ID: MM-${storeId.hashCode.abs().toString().padLeft(8, '0')}',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate500),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Tạo ngày: ${info.createdAt != null ? _formatDate(info.createdAt!) : 'N/A'}',
                      style: TextStyle(fontSize: 12, color: AppColors.slate400),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // 2. METRICS GRID
  Widget _buildMetricsGrid() {
    return _isLoadingStats
        ? Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        : Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    _metricCard(Icons.receipt_long, 'Doanh thu', _fmtCurrency(_totalRevenue), AppColors.emerald500, AppColors.emerald50),
                    SizedBox(height: 12),
                    _metricCard(Icons.shopping_bag_outlined, 'Sản phẩm', '$_productCount', Color(0xFF6366F1), Color(0xFFEEF2FF)),
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  children: [
                    _metricCard(Icons.list_alt, 'Đơn hàng', '$_orderCount', Color(0xFFF59E0B), Color(0xFFFEF3C7)),
                    SizedBox(height: 12),
                    _metricCard(Icons.people_outline, 'Nhân sự', '$_staffCount', Color(0xFF3B82F6), Color(0xFFEFF6FF)),
                  ],
                ),
              )
            ],
          );
  }

  Widget _metricCard(IconData icon, String label, String value, Color color, Color bgColor) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: AppColors.slate900.withValues(alpha: 0.03), blurRadius: 10, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.slate500)),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // 3. INFORMATION SECTION
  Widget _buildInfoSection() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.slate900.withValues(alpha: 0.04), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(20, 20, 20, 10),
            child: Text('Thông tin chi tiết', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.slate900)),
          ),
          _infoRow(Icons.location_on_outlined, 'Địa chỉ', info.address.isNotEmpty ? info.address : 'Chưa cập nhật'),
          Divider(height: 1, color: AppColors.slate100, indent: 56),
          _infoRow(Icons.access_time, 'Giờ hoạt động', info.openHours.isNotEmpty ? info.openHours : 'Chưa cập nhật'),
          Divider(height: 1, color: AppColors.slate100, indent: 56),
          _infoRow(Icons.description_outlined, 'Mã số thuế', info.taxId.isNotEmpty ? info.taxId : 'Chưa cập nhật'),
          Divider(height: 1, color: AppColors.slate100, indent: 56),
          _infoRow(Icons.account_balance_outlined, 'Ngân hàng', _getBankString()),
        ],
      ),
    );
  }

  String _getBankString() {
    if (info.bankId.isEmpty && info.bankAccount.isEmpty) return 'Chưa cập nhật';
    return '${info.bankId} • ${info.bankAccount}\\nCTK: ${info.bankOwner}';
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.slate400),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate500)),
                SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate800, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // 4. SUBSCRIPTION CARD
  Widget _buildSubscriptionCard(bool isPremium) {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isPremium ? null : Colors.white,
        gradient: isPremium 
            ? LinearGradient(colors: [Color(0xFFFEF08A), Color(0xFFF59E0B)], begin: Alignment.topLeft, end: Alignment.bottomRight) 
            : null,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: isPremium ? Color(0xFFF59E0B).withValues(alpha: 0.3) : AppColors.slate900.withValues(alpha: 0.04),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
        border: isPremium ? null : Border.all(color: AppColors.slate200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(isPremium ? Icons.workspace_premium : Icons.stars_outlined, color: isPremium ? Colors.white : AppColors.slate400, size: 28),
              SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Gói dịch vụ', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: isPremium ? Colors.white70 : AppColors.slate500)),
                  Text(
                    isPremium ? 'MoiMoi Premium' : 'Gói Cơ Bản',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: isPremium ? Colors.white : AppColors.slate800,
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Hết hạn:', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isPremium ? Colors.white70 : AppColors.slate500)),
              if (isPremium && info.premiumExpiresAt != null)
                Row(
                  children: [
                    Text(
                      _formatDate(info.premiumExpiresAt!),
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: Colors.white),
                    ),
                    if ((info.daysUntilExpiry ?? 0) > 0) ...[
                      SizedBox(width: 8),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                        child: Text(
                          'Còn ${info.daysUntilExpiry} ngày',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: Color(0xFFD97706)),
                        ),
                      ),
                    ],
                  ],
                )
              else
                Text('Không thời hạn', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800)),
            ],
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.read<UIStore>().showToast('Tính năng nâng cấp đang phát triển', 'info'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isPremium ? Colors.white : AppColors.emerald500,
              foregroundColor: isPremium ? Color(0xFFF59E0B) : Colors.white,
              padding: EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              elevation: 0,
            ),
            child: Text(
              isPremium ? 'Gia hạn Premium' : 'Nâng cấp Premium',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }

  // 5. ADMIN ACTIONS
  Widget _buildAdminActions() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.slate900.withValues(alpha: 0.04), blurRadius: 16, offset: Offset(0, 4))],
      ),
      child: Column(
        children: [
          _adminActionItem(Icons.edit_outlined, 'Chỉnh sửa thông tin', AppColors.slate800, () => _showEditStoreDialog(context)),
          Divider(height: 1, color: AppColors.slate100, indent: 56),
          _adminActionItem(Icons.history_outlined, 'Xem nhật ký hoạt động', AppColors.slate800, () => context.read<UIStore>().showToast('Tính năng đang phát triển', 'info')),
          Divider(height: 1, color: AppColors.slate100, indent: 56),
          _adminActionItem(Icons.notifications_active_outlined, 'Gửi thông báo', AppColors.slate800, () => context.read<UIStore>().showToast('Tính năng đang phát triển', 'info')),
          Divider(height: 1, color: AppColors.slate100, indent: 56),
          _adminActionItem(Icons.lock_outline, 'Khóa tài khoản', Color(0xFFEF4444), () => _showDeleteConfirm(context)),
        ],
      ),
    );
  }

  Widget _adminActionItem(IconData icon, String label, Color color, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Icon(icon, size: 22, color: color),
            SizedBox(width: 16),
            Expanded(
              child: Text(
                label,
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: color),
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: AppColors.slate300),
          ],
        ),
      ),
    );
  }

  void _showEditStoreDialog(BuildContext context) {
    final nameCtrl = TextEditingController(text: info.name);
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
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy', style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () {
              if (nameCtrl.text.trim().isEmpty) return;
              widget.store.updateStoreInfoById(storeId, info.copyWith(name: nameCtrl.text.trim()));
              context.read<UIStore>().showToast('Đã cập nhật cửa hàng!');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Lưu thay đổi', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirm(BuildContext context) {
    final storeName = info.name.isNotEmpty ? info.name : storeId;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Color(0xFFEF4444), size: 24),
            SizedBox(width: 8),
            Text('Khóa tài khoản?', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18, color: Color(0xFFEF4444))),
          ],
        ),
        content: Text(
          'Bạn có chắc muốn khóa "$storeName"?\\n\\nThao tác này chưa được hỗ trợ hoàn toàn, tạm thời sẽ thay thế bằng thao tác Xoá tài khoản (cấm truy cập vĩnh viễn).',
          style: TextStyle(fontSize: 14, color: AppColors.slate600, height: 1.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Hủy', style: TextStyle(color: AppColors.slate500, fontWeight: FontWeight.w600))),
          ElevatedButton(
            onPressed: () {
              widget.store.deleteStore(storeId);
              context.read<UIStore>().showToast('Đã xoá cửa hàng "$storeName"');
              Navigator.pop(ctx);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Color(0xFFEF4444),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text('Khóa (Xóa)', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}
"""

# Regex substitution
pattern = re.compile(r"class _StoreDetailPage extends StatelessWidget \{.*?(?=// ═══════════════════════════════════════════════════════════\n// BROADCAST DIALOG)", re.DOTALL)

if pattern.search(content):
    # Pass lambda to return new_class without parsing escape sequences
    new_content = pattern.sub(lambda _: new_class, content)
    with open(FILE_PATH, "w", encoding="utf-8") as f:
        f.write(new_content)
    print("Patched successfully!")
else:
    print("Could not find the target section to patch.")
