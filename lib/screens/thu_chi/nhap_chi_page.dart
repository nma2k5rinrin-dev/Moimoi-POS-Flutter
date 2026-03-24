import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../utils/constants.dart';
import 'nhap_thu_page.dart' show showAddCategoryDialog;

class NhapChiPage extends StatefulWidget {
  final bool embedded;
  final VoidCallback? onBack;
  const NhapChiPage({super.key, this.embedded = false, this.onBack});

  @override
  State<NhapChiPage> createState() => _NhapChiPageState();
}

class _NhapChiPageState extends State<NhapChiPage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int _selectedCategory = 0;
  DateTime _selectedDate = DateTime.now();

  final List<_Cat> _categories = [
    _Cat(emoji: '🍽️', label: 'Nguyên liệu', color: AppColors.red500),
    _Cat(emoji: '🔧', label: 'Biên mức', color: AppColors.blue500),
    _Cat(emoji: '⏰', label: 'Tiền thiết', color: AppColors.amber500),
    _Cat(emoji: '🚚', label: 'Vận chuyển', color: AppColors.violet500),
    _Cat(emoji: '🛠', label: 'Sửa chữa', color: AppColors.orange500),
    _Cat(emoji: '👥', label: 'Lương NV', color: const Color(0xFF9333EA)),
    _Cat(emoji: '📢', label: 'Marketing', color: AppColors.emerald500),
    _Cat(emoji: '📦', label: 'Khác', color: AppColors.slate500),
    _Cat(emoji: '➕', label: 'Thêm mới', color: AppColors.slate400),
  ];

  @override
  void dispose() {
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppColors.slate50,
      child: SafeArea(
        child: Column(
          children: [
            // ── Header ──────────────────────────
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () {
                      if (widget.embedded && widget.onBack != null) {
                        widget.onBack!();
                      } else {
                        context.go('/settings?tab=thu-chi');
                      }
                    },
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: AppColors.slate100,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.arrow_back_rounded,
                          color: AppColors.slate800, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.red50,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.trending_down_rounded,
                        color: AppColors.red500, size: 22),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Nhập khoản chi',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800,
                              color: AppColors.slate800)),
                        Text('Thêm giao dịch chi mới',
                          style: TextStyle(fontSize: 12, color: AppColors.slate500)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── Content ─────────────────────────
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),

                      // ── Amount ──────────────
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFEF2F2), Color(0xFFFEE2E2)],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.red200),
                        ),
                        child: Column(
                          children: [
                            const Text('Số tiền chi',
                              style: TextStyle(fontSize: 13, color: AppColors.red600,
                                  fontWeight: FontWeight.w600)),
                            const SizedBox(height: 8),
                            TextField(
                              controller: _amountCtrl,
                              keyboardType: TextInputType.number,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w800,
                                  color: AppColors.red600),
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                _ThousandSeparatorFormatter(),
                              ],
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                hintText: '0',
                                hintStyle: TextStyle(fontSize: 36, fontWeight: FontWeight.w800,
                                    color: AppColors.red400),
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.7),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('VND',
                                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                    color: AppColors.red600)),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Panel 2: Category + Note + Date ──
                      _panel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Chọn loại chi',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                  color: AppColors.slate700)),
                            const SizedBox(height: 12),
                            _buildCategoryGrid(),

                            const SizedBox(height: 20),

                            const Text('Ghi chú (tùy chọn)',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                  color: AppColors.slate700)),
                            const SizedBox(height: 8),
                            Container(
                              decoration: BoxDecoration(
                                color: AppColors.slate50,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.slate200),
                              ),
                              child: TextField(
                                controller: _noteCtrl,
                                decoration: const InputDecoration(
                                  hintText: 'Thêm ghi chú...',
                                  hintStyle: TextStyle(color: AppColors.slate400, fontSize: 14),
                                  border: InputBorder.none,
                                  contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                  prefixIcon: Icon(Icons.edit_rounded, color: AppColors.slate400, size: 18),
                                ),
                              ),
                            ),

                            const SizedBox(height: 20),

                            const Text('Chọn ngày',
                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600,
                                  color: AppColors.slate700)),
                            const SizedBox(height: 8),
                            GestureDetector(
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now(),
                                );
                                if (picked != null) setState(() => _selectedDate = picked);
                              },
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                decoration: BoxDecoration(
                                  color: AppColors.slate50,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(color: AppColors.slate200),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded,
                                        size: 18, color: AppColors.red500),
                                    const SizedBox(width: 12),
                                    Text(
                                      '${_selectedDate.day.toString().padLeft(2, '0')}/${_selectedDate.month.toString().padLeft(2, '0')}/${_selectedDate.year}',
                                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                                          color: AppColors.slate800),
                                    ),
                                    const Spacer(),
                                    const Icon(Icons.keyboard_arrow_down_rounded,
                                        color: AppColors.slate400),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 14),

                      // ── Buttons ─────────────
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                if (widget.embedded && widget.onBack != null) {
                                  widget.onBack!();
                                } else {
                                  context.go('/settings?tab=thu-chi');
                                }
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
                                    Icon(Icons.close_rounded, size: 18, color: AppColors.slate500),
                                    SizedBox(width: 6),
                                    Text('Hủy bỏ',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                                          color: AppColors.slate600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: GestureDetector(
                              onTap: _handleSave,
                              child: Container(
                                height: 52,
                                decoration: BoxDecoration(
                                  color: AppColors.red500,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.save_rounded, size: 18, color: Colors.white),
                                    SizedBox(width: 6),
                                    Text('Lưu',
                                      style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
                                          color: Colors.white)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 24),
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

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCategoryGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 4,
        childAspectRatio: 0.75,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, i) {
        final cat = _categories[i];
        final isSelected = i == _selectedCategory;
        final isAdd = i == _categories.length - 1;

        return GestureDetector(
          onTap: () {
            if (isAdd) {
              _showAddCategoryDialog();
            } else {
              setState(() => _selectedCategory = i);
            }
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: isSelected ? 50 : 44,
                height: isSelected ? 50 : 44,
                decoration: BoxDecoration(
                  color: isSelected
                      ? cat.color
                      : isAdd
                          ? AppColors.slate100
                          : cat.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [BoxShadow(color: cat.color.withValues(alpha: 0.35),
                          blurRadius: 12, offset: const Offset(0, 4))]
                      : null,
                ),
                child: Center(
                  child: Text(cat.emoji,
                    style: TextStyle(fontSize: isSelected ? 24 : 20),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(cat.label,
                style: TextStyle(fontSize: 10,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? cat.color : AppColors.slate500),
                textAlign: TextAlign.center, maxLines: 1, overflow: TextOverflow.ellipsis),
              if (isSelected)
                Container(
                  margin: const EdgeInsets.only(top: 3),
                  width: 5, height: 5,
                  decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle),
                ),
            ],
          ),
        );
      },
    );
  }

  void _showAddCategoryDialog() {
    showAddCategoryDialog(
      context: context,
      type: 'chi',
      onSave: (name, emoji, color) {
        setState(() {
          _categories.insert(_categories.length - 1,
              _Cat(emoji: emoji, label: name, color: color));
          _selectedCategory = _categories.length - 2;
        });
      },
    );
  }

  void _handleSave() async {
    final rawText = _amountCtrl.text.replaceAll(',', '');
    final amount = double.tryParse(rawText) ?? 0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Vui lòng nhập số tiền hợp lệ')),
      );
      return;
    }
    final store = context.read<AppStore>();
    store.addThuChiTransaction(
      type: 'chi',
      amount: amount,
      category: _categories[_selectedCategory].label,
      note: _noteCtrl.text.trim(),
      date: _selectedDate,
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Đã lưu khoản chi thành công!'),
          backgroundColor: AppColors.red500),
    );
    if (widget.embedded && widget.onBack != null) {
      widget.onBack!();
    } else {
      context.go('/settings?tab=thu-chi');
    }
  }
}

// ── Thousand separator formatter ─────────────────────────
class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final formatted = digits.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]},');
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}

class _Cat {
  final String emoji;
  final String label;
  final Color color;
  const _Cat({required this.emoji, required this.label, required this.color});
}
