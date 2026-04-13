import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'package:moimoi_pos/core/widgets/crop/square_crop_dialog.dart';

Uint8List _decodeStoreImage(String dataUri) {
  final base64Part = dataUri.split(',').last;
  return base64Decode(base64Part);
}

class StoreInfoSection extends StatefulWidget {
  final VoidCallback? onCancel;
  const StoreInfoSection({super.key, this.onCancel});

  @override
  State<StoreInfoSection> createState() => _StoreInfoSectionState();
}

class _StoreInfoSectionState extends State<StoreInfoSection> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _taxIdController = TextEditingController();
  final _openHoursController = TextEditingController();
  final _bankNameController = TextEditingController();
  final _bankAccountController = TextEditingController();
  final _bankOwnerController = TextEditingController();
  String _qrImageUrl = '';
  bool _showTotalProducts = true;

  @override
  void initState() {
    super.initState();
    final store = context.read<ManagementStore>();
    final info = store.currentStoreInfo;
    _nameController.text = info.name;
    _phoneController.text = info.phone;
    _addressController.text = info.address;
    _taxIdController.text = info.taxId;
    _openHoursController.text = info.openHours;
    _bankNameController.text = info.bankId;
    _bankAccountController.text = info.bankAccount;
    _bankOwnerController.text = info.bankOwner;
    _qrImageUrl = info.qrImageUrl;
    _showTotalProducts = info.showTotalProducts;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _taxIdController.dispose();
    _openHoursController.dispose();
    _bankNameController.dispose();
    _bankAccountController.dispose();
    _bankOwnerController.dispose();
    super.dispose();
  }

  Future<void> _pickStoreLogo(ManagementStore store) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    if (!mounted) return;

    final prepared = await prepareImageBytes(bytes);
    if (!mounted) return;
    final base64Result = await showSquareCropDialog(
      context,
      imageBytes: prepared,
      borderRadius: 24,
    );
    if (base64Result != null) {
      String imageData = base64Result;
      try {
        imageData = await CloudflareService.uploadBase64(
          base64Data: base64Result,
          folder: 'logos',
        );
      } catch (e) {
        debugPrint('[StoreInfoSection] Logo upload failed: $e');
      }
      final info = store.currentStoreInfo.copyWith(logoUrl: imageData);
      store.updateStoreInfo(info);
      setState(() {});
    }
  }

  Future<void> _pickQrImage(ManagementStore store) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
    );
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    if (!mounted) return;

    final prepared = await prepareImageBytes(bytes);
    if (!mounted) return;
    final base64Result = await showSquareCropDialog(
      context,
      imageBytes: prepared,
      borderRadius: 12,
      title: 'Điều chỉnh ảnh QR',
    );
    if (base64Result != null && mounted) {
      String imageData = base64Result;
      try {
        imageData = await CloudflareService.uploadBase64(
          base64Data: base64Result,
          folder: 'qr',
        );
      } catch (e) {
        debugPrint('[StoreInfoSection] QR upload failed: $e');
      }
      setState(() => _qrImageUrl = imageData);
      store.showToast('Đã chọn ảnh QR. Ấn Lưu để áp dụng.');
    }
  }

  Future<Uint8List> prepareImageBytes(Uint8List bytes) async {
    // In a real implementation, this might resize or optimize the image.
    // For now, it returns the bytes as is to fulfill the requirement.
    return bytes;
  }

  void _saveStoreInfo(ManagementStore store) {
    final info = store.currentStoreInfo.copyWith(
      name: _nameController.text.trim(),
      phone: _phoneController.text.trim(),
      address: _addressController.text.trim(),
      taxId: _taxIdController.text.trim(),
      openHours: _openHoursController.text.trim(),
      bankId: _bankNameController.text.trim(),
      bankAccount: _bankAccountController.text.trim(),
      bankOwner: _bankOwnerController.text.trim(),
      qrImageUrl: _qrImageUrl,
      showTotalProducts: _showTotalProducts,
    );
    store.updateStoreInfo(info);
    store.showToast('Cập nhật thông tin thành công!');

    if (widget.onCancel != null) {
      widget.onCancel!();
    } else {
      if (Navigator.canPop(context)) Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<ManagementStore>();
    final info = store.currentStoreInfo;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      children: [
                        _buildLogoHeader(store, info),
                        SizedBox(height: 20),
                        _buildBasicFields(),
                        SizedBox(height: 20),
                        _buildBankSeparator(),
                        SizedBox(height: 16),
                        _buildBankFields(),
                        SizedBox(height: 20),
                        Divider(color: AppColors.slate200),
                        SizedBox(height: 12),
                        _buildTotalProductsToggle(),
                        SizedBox(height: 12),
                        Divider(color: AppColors.slate200),
                        SizedBox(height: 16),
                        _buildQrSection(store),
                        SizedBox(height: 20),
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        _buildBottomActions(store),
      ],
    );
  }

  Widget _buildLogoHeader(ManagementStore store, StoreInfoModel info) {
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.slate200, width: 1.5),
                  image: info.logoUrl.isNotEmpty
                      ? DecorationImage(
                          image: CloudflareService.isUrl(info.logoUrl)
                              ? CachedNetworkImageProvider(info.logoUrl)
                              : MemoryImage(_decodeStoreImage(info.logoUrl))
                                    as ImageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: info.logoUrl.isEmpty
                    ? Icon(
                        Icons.storefront,
                        size: 36,
                        color: AppColors.emerald500,
                      )
                    : null,
              ),
              Positioned(
                bottom: -2,
                right: -2,
                child: GestureDetector(
                  onTap: () => _pickStoreLogo(store),
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AppColors.emerald500,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.cardBg, width: 2),
                    ),
                    child: Icon(
                      Icons.camera_alt,
                      size: 14,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: 8),
        Text(
          info.name.isNotEmpty ? info.name : 'Moimoi POS',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.slate800,
          ),
        ),
        SizedBox(height: 4),
        _buildPlanBadge(info),
      ],
    );
  }

  Widget _buildPlanBadge(StoreInfoModel info) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: info.isPremium ? Color(0xFFECFDF5) : AppColors.emerald50,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            info.isPremium ? Icons.workspace_premium : Icons.verified_rounded,
            size: 13,
            color: AppColors.emerald500,
          ),
          SizedBox(width: 4),
          Text(
            info.isPremium ? 'Gói Premium' : 'Gói cơ bản',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.emerald600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBasicFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _SettingsField(
                label: 'Tên cửa hàng',
                controller: _nameController,
                hint: 'Moimoi POS',
                prefixIcon: Icons.storefront_outlined,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _SettingsField(
                label: 'Số điện thoại',
                controller: _phoneController,
                hint: '028 1234 5678',
                keyboardType: TextInputType.phone,
                prefixIcon: Icons.phone_outlined,
              ),
            ),
          ],
        ),
        SizedBox(height: 12),
        _SettingsField(
          label: 'Địa chỉ',
          controller: _addressController,
          hint: '123 Nguyễn Huệ, Q.1, TP.HCM',
          prefixIcon: Icons.location_on_outlined,
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SettingsField(
                label: 'Mã số thuế',
                controller: _taxIdController,
                hint: '0312345678',
                prefixIcon: Icons.receipt_long_outlined,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _TimeRangePickerField(
                label: 'Giờ mở cửa',
                controller: _openHoursController,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBankSeparator() {
    return Row(
      children: [
        Expanded(child: Divider(color: AppColors.slate200)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Thanh toán ngân hàng',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.slate400,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.slate200)),
      ],
    );
  }

  Widget _buildBankFields() {
    return Column(
      children: [
        _SettingsField(
          label: 'Tên ngân hàng',
          controller: _bankNameController,
          hint: 'Nhập tên ngân hàng. VD: Vietcombank',
          prefixIcon: Icons.account_balance_outlined,
        ),
        SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _SettingsField(
                label: 'Số tài khoản',
                controller: _bankAccountController,
                hint: '0123 4567 8910',
                keyboardType: TextInputType.number,
                prefixIcon: Icons.credit_card_outlined,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: _SettingsField(
                label: 'Chủ tài khoản',
                controller: _bankOwnerController,
                hint: 'NGUYEN VAN A',
                prefixIcon: Icons.person_outline,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTotalProductsToggle() {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Hiển thị Tổng Sản Phẩm Đang Xử Lý',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.slate700,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Hiển thị nút Xem Danh Sách Tổng Hợp các sản phẩm đang xử lý trong tab Đang Xử Lý.',
                style: TextStyle(fontSize: 12, color: AppColors.slate500),
              ),
            ],
          ),
        ),
        SizedBox(width: 16),
        Switch(
          value: _showTotalProducts,
          onChanged: (v) => setState(() => _showTotalProducts = v),
          activeTrackColor: AppColors.emerald500,
        ),
      ],
    );
  }

  Widget _buildQrSection(ManagementStore store) {
    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Ảnh QR thanh toán',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.slate600,
            ),
          ),
        ),
        SizedBox(height: 12),
        if (_qrImageUrl.isNotEmpty)
          _buildActiveQr(store)
        else
          _buildQrPicker(store),
      ],
    );
  }

  Widget _buildActiveQr(ManagementStore store) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _pickQrImage(store),
          child: Container(
            width: 200,
            height: 200,
            decoration: BoxDecoration(
              color: AppColors.slate50,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.slate200),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: CloudflareService.isUrl(_qrImageUrl)
                  ? CachedNetworkImage(
                      imageUrl: _qrImageUrl,
                      fit: BoxFit.contain,
                    )
                  : Image.memory(
                      _decodeStoreImage(_qrImageUrl),
                      fit: BoxFit.contain,
                    ),
            ),
          ),
        ),
        SizedBox(width: 10),
        IconButton(
          onPressed: () => setState(() => _qrImageUrl = ''),
          icon: Icon(Icons.delete_outline, color: AppColors.red500),
        ),
      ],
    );
  }

  Widget _buildQrPicker(ManagementStore store) {
    return GestureDetector(
      onTap: () => _pickQrImage(store),
      child: Container(
        width: 200,
        height: 200,
        decoration: BoxDecoration(
          color: AppColors.slate50,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.slate200),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.qr_code_rounded, size: 40, color: AppColors.slate300),
            Text(
              'Chọn ảnh QR',
              style: TextStyle(fontSize: 12, color: AppColors.slate400),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(ManagementStore store) {
    return Padding(
      padding: EdgeInsets.fromLTRB(9, 8, 9, 16),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 600),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  if (widget.onCancel != null) {
                    widget.onCancel!();
                  } else {
                    if (Navigator.canPop(context)) Navigator.pop(context);
                  }
                },
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.slate50,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.slate200),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.slate500,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Hủy bỏ',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.slate600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: GestureDetector(
                onTap: () => _saveStoreInfo(store),
                child: Container(
                  height: 52,
                  decoration: BoxDecoration(
                    color: AppColors.emerald500,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.save_rounded, size: 18, color: Colors.white),
                      SizedBox(width: 6),
                      Text(
                        'Lưu thay đổi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
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
      ),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  const _SettingsField({
    required this.label,
    required this.controller,
    this.hint,
    this.keyboardType,
    this.prefixIcon,
  });
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.slate700,
          ),
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.slate50,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: AppColors.slate400)
                : null,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  final Widget child;
  const _SectionCard({required this.child});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
      ),
      child: child,
    );
  }
}

class _TimeRangePickerField extends StatefulWidget {
  final String label;
  final TextEditingController controller;

  const _TimeRangePickerField({required this.label, required this.controller});

  @override
  State<_TimeRangePickerField> createState() => _TimeRangePickerFieldState();
}

class _TimeRangePickerFieldState extends State<_TimeRangePickerField> {
  String _start = '07:00';
  String _end = '22:00';
  final List<String> _times = [];

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < 24; i++) {
      final h = i.toString().padLeft(2, '0');
      _times.add('$h:00');
      _times.add('$h:30');
    }
    if (widget.controller.text.isEmpty) {
      widget.controller.text = '07:00 - 22:00';
    } else {
      _parseCurrent();
    }
    widget.controller.addListener(_parseCurrent);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_parseCurrent);
    super.dispose();
  }

  void _parseCurrent() {
    final parts = widget.controller.text.split('-');
    if (parts.length == 2 && mounted) {
      final s = parts[0].trim();
      final e = parts[1].trim();
      if (_times.contains(s) && _times.contains(e)) {
        if (_start != s || _end != e) {
          setState(() {
            _start = s;
            _end = e;
          });
        }
      }
    }
  }

  void _update() {
    final newVal = '$_start - $_end';
    if (widget.controller.text != newVal) {
      widget.controller.text = newVal;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.slate700,
          ),
        ),
        SizedBox(height: 6),
        Container(
          height: 52,
          padding: EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppColors.slate50,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 18,
                color: AppColors.slate400,
              ),
              SizedBox(width: 8),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _times.contains(_start) ? _start : '07:00',
                    isExpanded: true,
                    icon: Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: AppColors.slate400,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.slate700,
                      fontWeight: FontWeight.w500,
                    ),
                    items: _times
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _start = v);
                        _update();
                      }
                    },
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  '-',
                  style: TextStyle(
                    color: AppColors.slate400,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Expanded(
                child: DropdownButtonHideUnderline(
                  child: DropdownButton<String>(
                    value: _times.contains(_end) ? _end : '22:00',
                    isExpanded: true,
                    icon: Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: AppColors.slate400,
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.slate700,
                      fontWeight: FontWeight.w500,
                    ),
                    items: _times
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _end = v);
                        _update();
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
