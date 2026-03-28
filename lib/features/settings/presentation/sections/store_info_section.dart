import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/features/settings/models/store_info_model.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/services/api/cloudflare_service.dart';
import 'package:moimoi_pos/core/widgets/crop/square_crop_dialog.dart';

Uint8List _decodeStoreImage(String dataUri) {
  final base64Part = dataUri.split(',').last;
  return base64Decode(base64Part);
}

class StoreInfoSection extends StatefulWidget {
  const StoreInfoSection({super.key});

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

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
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

  Future<void> _pickStoreLogo(AppStore store) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    if (!mounted) return;

    final prepared = await prepareImageBytes(bytes);
    if (!context.mounted) return;
    final base64Result = await showSquareCropDialog(
      context,
      imageBytes: prepared,
      borderRadius: 24,
    );
    if (base64Result != null) {
      String imageData = base64Result;
      try {
        imageData = await CloudflareService.uploadBase64(base64Data: base64Result, folder: 'logos');
      } catch (e) {
        debugPrint('[StoreInfoSection] Logo upload failed: $e');
      }
      final info = store.currentStoreInfo.copyWith(logoUrl: imageData);
      store.updateStoreInfo(info);
      setState(() {});
    }
  }

  Future<void> _pickQrImage(AppStore store) async {
    final picker = ImagePicker();
    final XFile? pickedFile = await picker.pickImage(source: ImageSource.gallery);
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    if (!mounted) return;

    final prepared = await prepareImageBytes(bytes);
    if (!context.mounted) return;
    final base64Result = await showSquareCropDialog(
      context,
      imageBytes: prepared,
      borderRadius: 12,
      title: 'Điều chỉnh ảnh QR',
    );
    if (base64Result != null && mounted) {
      String imageData = base64Result;
      try {
        imageData = await CloudflareService.uploadBase64(base64Data: base64Result, folder: 'qr');
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

  void _saveStoreInfo(AppStore store) {
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
    );
    store.updateStoreInfo(info);
    store.showToast('Cập nhật thông tin thành công!');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final info = store.currentStoreInfo;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  _SectionCard(
                    child: Column(
                      children: [
                        _buildLogoHeader(store, info),
                        const SizedBox(height: 20),
                        _buildBasicFields(),
                        const SizedBox(height: 20),
                        _buildBankSeparator(),
                        const SizedBox(height: 16),
                        _buildBankFields(),
                        const SizedBox(height: 16),
                        _buildQrSection(store),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        _buildBottomActions(store),
      ],
    );
  }

  Widget _buildLogoHeader(AppStore store, StoreInfoModel info) {
    return Column(
      children: [
        Center(
          child: Stack(
            children: [
              Container(
                width: 88, height: 88,
                decoration: BoxDecoration(
                  color: AppColors.emerald50,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppColors.slate200, width: 1.5),
                  image: info.logoUrl.isNotEmpty
                      ? DecorationImage(
                          image: CloudflareService.isUrl(info.logoUrl)
                              ? CachedNetworkImageProvider(info.logoUrl)
                              : MemoryImage(_decodeStoreImage(info.logoUrl)) as ImageProvider,
                          fit: BoxFit.cover,
                        )
                      : null,
                ),
                child: info.logoUrl.isEmpty ? const Icon(Icons.storefront, size: 36, color: AppColors.emerald500) : null,
              ),
              Positioned(
                bottom: -2, right: -2,
                child: GestureDetector(
                  onTap: () => _pickStoreLogo(store),
                  child: Container(
                    width: 28, height: 28,
                    decoration: BoxDecoration(color: AppColors.emerald500, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                    child: const Icon(Icons.camera_alt, size: 14, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text(info.name.isNotEmpty ? info.name : 'Moimoi POS', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.slate800)),
        const SizedBox(height: 4),
        _buildPlanBadge(info),
      ],
    );
  }

  Widget _buildPlanBadge(StoreInfoModel info) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: info.isPremium ? const Color(0xFFECFDF5) : const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(info.isPremium ? Icons.workspace_premium : Icons.verified_rounded, size: 13, color: AppColors.emerald500),
          const SizedBox(width: 4),
          Text(info.isPremium ? 'Gói Premium' : 'Gói cơ bản', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.emerald600)),
        ],
      ),
    );
  }

  Widget _buildBasicFields() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _SettingsField(label: 'Tên cửa hàng', controller: _nameController, hint: 'Moimoi POS', prefixIcon: Icons.storefront_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _SettingsField(label: 'Số điện thoại', controller: _phoneController, hint: '028 1234 5678', keyboardType: TextInputType.phone, prefixIcon: Icons.phone_outlined)),
          ],
        ),
        const SizedBox(height: 12),
        _SettingsField(label: 'Địa chỉ', controller: _addressController, hint: '123 Nguyễn Huệ, Q.1, TP.HCM', prefixIcon: Icons.location_on_outlined),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SettingsField(label: 'Mã số thuế', controller: _taxIdController, hint: '0312345678', prefixIcon: Icons.receipt_long_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _SettingsField(label: 'Giờ mở cửa', controller: _openHoursController, hint: '07:00 - 22:00', prefixIcon: Icons.access_time_rounded)),
          ],
        ),
      ],
    );
  }

  Widget _buildBankSeparator() {
    return const Row(
      children: [
        Expanded(child: Divider(color: AppColors.slate200)),
        Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Text('Thanh toán ngân hàng', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate400))),
        Expanded(child: Divider(color: AppColors.slate200)),
      ],
    );
  }

  Widget _buildBankFields() {
    return Column(
      children: [
        _SettingsField(label: 'Tên ngân hàng', controller: _bankNameController, hint: 'Vietcombank', prefixIcon: Icons.account_balance_outlined),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _SettingsField(label: 'Số tài khoản', controller: _bankAccountController, hint: '0123 4567 8910', keyboardType: TextInputType.number, prefixIcon: Icons.credit_card_outlined)),
            const SizedBox(width: 12),
            Expanded(child: _SettingsField(label: 'Chủ tài khoản', controller: _bankOwnerController, hint: 'NGUYEN VAN A', prefixIcon: Icons.person_outline)),
          ],
        ),
      ],
    );
  }

  Widget _buildQrSection(AppStore store) {
    return Column(
      children: [
        const Align(alignment: Alignment.centerLeft, child: Text('Ảnh QR thanh toán', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.slate600))),
        const SizedBox(height: 12),
        if (_qrImageUrl.isNotEmpty)
          _buildActiveQr(store)
        else
          _buildQrPicker(store),
      ],
    );
  }

  Widget _buildActiveQr(AppStore store) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => _pickQrImage(store),
          child: Container(
            width: 200, height: 200,
            decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.slate200)),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(13),
              child: CloudflareService.isUrl(_qrImageUrl)
                  ? CachedNetworkImage(imageUrl: _qrImageUrl, fit: BoxFit.contain)
                  : Image.memory(_decodeStoreImage(_qrImageUrl), fit: BoxFit.contain),
            ),
          ),
        ),
        const SizedBox(width: 10),
        IconButton(onPressed: () => setState(() => _qrImageUrl = ''), icon: const Icon(Icons.delete_outline, color: AppColors.red500)),
      ],
    );
  }

  Widget _buildQrPicker(AppStore store) {
    return GestureDetector(
      onTap: () => _pickQrImage(store),
      child: Container(
        width: 200, height: 200,
        decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.slate200)),
        child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.qr_code_rounded, size: 40, color: AppColors.slate300), Text('Chọn ảnh QR', style: TextStyle(fontSize: 12, color: AppColors.slate400))]),
      ),
    );
  }

  Widget _buildBottomActions(AppStore store) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: ElevatedButton(onPressed: () => _saveStoreInfo(store), child: const Center(child: Text('Lưu thay đổi'))),
    );
  }
}

class _SettingsField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;
  const _SettingsField({required this.label, required this.controller, this.hint, this.keyboardType, this.prefixIcon});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate700)),
        const SizedBox(height: 6),
        TextField(
          controller: controller,
          keyboardType: keyboardType,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: AppColors.slate50,
            prefixIcon: prefixIcon != null ? Icon(prefixIcon, size: 18, color: AppColors.slate400) : null,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: AppColors.slate200)),
      child: child,
    );
  }
}
