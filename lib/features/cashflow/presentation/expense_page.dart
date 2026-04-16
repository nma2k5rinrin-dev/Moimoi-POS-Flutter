import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:reorderable_grid_view/reorderable_grid_view.dart';
import 'package:moimoi_pos/features/cashflow/logic/cashflow_store_standalone.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';
import 'package:moimoi_pos/core/widgets/single_date_picker_dialog.dart';
import 'package:moimoi_pos/features/cashflow/presentation/income_page.dart'
    show showAddCategoryDialog;
import 'package:moimoi_pos/features/cashflow/models/transaction_category_model.dart';
import 'package:moimoi_pos/features/cashflow/models/transaction_model.dart';

class ExpensePage extends StatefulWidget {
  final bool asDialog;
  final DateTime? initialDate;
  final VoidCallback? onSaved;
  final bool embedded;
  final VoidCallback? onBack;
  final Transaction? initialTransaction;
  const ExpensePage({
    super.key,
    this.asDialog = false,
    this.initialDate,
    this.onSaved,
    this.embedded = false,
    this.onBack,
    this.initialTransaction,
  });

  @override
  ExpensePageState createState() => ExpensePageState();
}

class ExpensePageState extends State<ExpensePage> {
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  int _selectedCategory = 0;
  late DateTime _selectedDate;
  bool _isEditMode = false;

  final List<TransactionCategory> _defaultCategories = [];

  List<TransactionCategory> _getCategories(CashflowStore store) {
    final customCats = store.currentCustomThuChiCategories
        .where((c) => c.type == 'chi')
        .toList();
    return [
      TransactionCategory(
        type: 'chi',
        emoji: '+',
        label: 'Thêm mới',
        color: AppColors.slate400,
        isCustom: false,
      ),
      ..._defaultCategories,
      ...customCats,
    ];
  }

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    if (widget.initialTransaction != null) {
      final t = widget.initialTransaction!;
      final rawStr = t.amount.toStringAsFixed(0);
      final formatted = rawStr.replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );
      _amountCtrl.text = formatted;
      _noteCtrl.text = t.note;

      var s = t.time;
      if (s.endsWith('Z')) s = s.substring(0, s.length - 1);
      final plussIdx = s.indexOf('+');
      if (plussIdx != -1) s = s.substring(0, plussIdx);
      _selectedDate = DateTime.tryParse(s) ?? DateTime.now();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        final store = context.read<CashflowStore>();
        final cats = _getCategories(store);
        final idx = cats.indexWhere((c) => c.label == t.category);
        if (idx != -1) setState(() => _selectedCategory = idx);
      });
    }
  }

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
            if (!widget.embedded && !widget.asDialog)
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    if (!widget.asDialog) ...[
                      GestureDetector(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          if (widget.onSaved != null) {
                            widget.onSaved!();
                          } else if (widget.embedded && widget.onBack != null) {
                            widget.onBack!();
                          } else {
                            if (GoRouter.of(context).canPop()) {
                              context.pop();
                            } else {
                              context.go('/settings?tab=cashflow');
                            }
                          }
                        },
                        child: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: AppColors.slate100,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.arrow_back_rounded,
                            color: AppColors.slate800,
                            size: 20,
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                    ],
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: AppColors.red50,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.trending_down_rounded,
                        color: AppColors.red500,
                        size: 22,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Nhập khoản chi',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppColors.slate800,
                            ),
                          ),
                          Text(
                            'Thêm giao dịch chi mới',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // ── Content ─────────────────────────
            Expanded(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: widget.asDialog ? 0 : 20,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: 600),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 8),

                      // ── Amount, Note & Date ──────────────
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          const SizedBox(height: 4),
                          Text(
                            'SỐ TIỀN CHI',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.2,
                              color: AppColors.slate500,
                            ),
                          ),
                          const SizedBox(height: 4),
                          TextField(
                            controller: _amountCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              height: 1.1,
                              fontWeight: FontWeight.w700,
                              color: Theme.of(context).brightness == Brightness.dark
                                  ? AppColors.red400
                                  : AppColors.red500,
                              letterSpacing: -1,
                            ),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              _ThousandSeparatorFormatter(),
                            ],
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: '0',
                              hintStyle: TextStyle(
                                fontSize: 28,
                                height: 1.1,
                                fontWeight: FontWeight.w700,
                                color: AppColors.slate300,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Theme.of(context).cardColor,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.slate200),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.edit_note_rounded,
                                        size: 20,
                                        color: AppColors.slate400,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: TextField(
                                          controller: _noteCtrl,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w500,
                                            color: Theme.of(context).brightness == Brightness.dark
                                                ? Colors.white
                                                : AppColors.slate700,
                                          ),
                                          decoration: InputDecoration(
                                            hintText: 'Thêm ghi chú...',
                                            hintStyle: TextStyle(
                                              fontSize: 14,
                                              fontStyle: FontStyle.italic,
                                              color: AppColors.slate400,
                                            ),
                                            border: InputBorder.none,
                                            contentPadding: EdgeInsets.zero,
                                            isDense: true,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              GestureDetector(
                                onTap: () async {
                                  FocusScope.of(context).unfocus();
                                  final picked = await showCompactDatePicker(
                                    context: context,
                                    initialDate: _selectedDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now(),
                                  );
                                  if (picked != null) {
                                    setState(() => _selectedDate = picked);
                                  }
                                },
                                child: Container(
                                  height: 44,
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: AppColors.red50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: AppColors.red200.withOpacity(0.5)),
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.calendar_month_rounded,
                                        size: 18,
                                        color: AppColors.red600,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        '${_selectedDate.day.toString().padLeft(2, "0")}/${_selectedDate.month.toString().padLeft(2, "0")}/${_selectedDate.year}',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.red600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      SizedBox(height: 14),

                      // ── Panel 2: Category + Note + Date ──
                      Expanded(
                        child: SingleChildScrollView(
                          padding: EdgeInsets.only(bottom: 24),
                          child: Column(
                            children: [
                              _panel(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          'Chọn loại chi',
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: AppColors.slate700,
                                          ),
                                        ),
                                        Spacer(),
                                        GestureDetector(
                                          onTap: () => setState(
                                            () => _isEditMode = !_isEditMode,
                                          ),
                                          child: Container(
                                            padding: EdgeInsets.symmetric(
                                              horizontal: 16,
                                              vertical: 8,
                                            ),
                                            decoration: BoxDecoration(
                                              color: _isEditMode
                                                  ? AppColors.emerald100
                                                  : AppColors.slate100,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                if (!_isEditMode) ...[
                                                  Icon(
                                                    Icons.tune_rounded,
                                                    size: 16,
                                                    color: AppColors.slate500,
                                                  ),
                                                  SizedBox(width: 6),
                                                ],
                                                Text(
                                                  _isEditMode
                                                      ? 'Xong'
                                                      : 'Chỉnh sửa',
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w600,
                                                    color: _isEditMode
                                                        ? AppColors.emerald600
                                                        : AppColors.slate600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 12),
                                    _buildCategoryGrid(),
                                  ],
                                ),
                              ),

                              SizedBox(height: 14),

                              // ── Buttons ─────────────
                              if (!widget.asDialog)
                                Row(
                                  children: [
                                    Expanded(
                                      child: GestureDetector(
                                        onTap: () {
                                          HapticFeedback.lightImpact();
                                          if (widget.onSaved != null) {
                                            widget.onSaved!();
                                          } else if (widget.embedded &&
                                              widget.onBack != null) {
                                            widget.onBack!();
                                          } else {
                                            if (GoRouter.of(context).canPop()) {
                                              context.pop();
                                            } else {
                                              context.go(
                                                '/settings?tab=cashflow',
                                              );
                                            }
                                          }
                                        },
                                        child: Container(
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: AppColors.slate50,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            border: Border.all(
                                              color: AppColors.slate200,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
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
                                        onTap: _handleSave,
                                        child: Container(
                                          height: 52,
                                          decoration: BoxDecoration(
                                            color: AppColors.red500,
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Icon(
                                                Icons.save_rounded,
                                                size: 18,
                                                color: Colors.white,
                                              ),
                                              SizedBox(width: 6),
                                              Text(
                                                'Lưu',
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
                            ],
                          ),
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

  Widget _panel({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(widget.asDialog ? 12 : 20),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.slate200),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildCategoryItem(
    TransactionCategory cat,
    int index, {
    bool isSelected = false,
    bool isAdd = false,
  }) {
    return GestureDetector(
      key: ValueKey(cat.id ?? 'item_$index'),
      onTap: () {
        HapticFeedback.lightImpact();
        if (_isEditMode) return;
        if (isAdd) {
          _showAddCategoryDialog();
        } else {
          setState(() => _selectedCategory = index);
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AnimatedContainer(
                duration: Duration(milliseconds: 200),
                width: isSelected ? 64 : 56,
                height: isSelected ? 64 : 56,
                decoration: BoxDecoration(
                  color: isSelected
                      ? cat.color
                      : isAdd
                      ? AppColors.slate100
                      : cat.color.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: cat.color.withValues(alpha: 0.35),
                            blurRadius: 12,
                            offset: Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: Text(
                    cat.emoji,
                    style: TextStyle(fontSize: isSelected ? 42 : 36),
                  ),
                ),
              ),
              SizedBox(height: 6),
              Text(
                cat.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected
                      ? cat.color
                      : (AppColors.cardBg != Colors.white
                            ? AppColors.slate400
                            : AppColors.slate500),
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (isSelected && !_isEditMode)
                Container(
                  margin: EdgeInsets.only(top: 3),
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: cat.color,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          if (_isEditMode && cat.isCustom)
            Positioned(
              top: 0,
              right: 0,
              child: GestureDetector(
                onTap: () => _showManageCategoryOptions(index, cat),
                child: Container(
                  padding: EdgeInsets.all(2),
                  decoration: BoxDecoration(
                    color: AppColors.slate100,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.remove_circle,
                    color: AppColors.red500,
                    size: 16,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCategoryGrid() {
    final store = context.watch<CashflowStore>();
    final currentCats = _getCategories(store);

    if (_isEditMode) {
      final customCats = store.currentCustomThuChiCategories
          .where((c) => c.type == 'chi')
          .toList();
      return ReorderableGridView.count(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        childAspectRatio: 0.85,
        shrinkWrap: true,
        physics: NeverScrollableScrollPhysics(),
        onReorder: (oldIndex, newIndex) {
          final element = customCats.removeAt(oldIndex);
          customCats.insert(newIndex, element);
          store.updateThuChiCategoryOrder(customCats);
        },
        children: customCats.asMap().entries.map((entry) {
          final i = entry.key;
          final cat = entry.value;
          return _buildCategoryItem(cat, i, isSelected: false, isAdd: false);
        }).toList(),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        mainAxisSpacing: 8,
        crossAxisSpacing: 4,
        childAspectRatio: 0.85,
      ),
      itemCount: currentCats.length,
      itemBuilder: (context, i) {
        final cat = currentCats[i];
        final isSelected = i == _selectedCategory;
        final isAdd = i == 0;
        return _buildCategoryItem(cat, i, isSelected: isSelected, isAdd: isAdd);
      },
    );
  }

  void _showAddCategoryDialog() {
    showAddCategoryDialog(
      context: context,
      type: 'chi',
      onSave: (name, emoji, color) {
        final store = context.read<CashflowStore>();
        store.addTransactionCategory(
          TransactionCategory(
            type: 'chi',
            emoji: emoji,
            label: name,
            color: color,
            isCustom: true,
          ),
        );
        setState(() {
          _selectedCategory =
              _getCategories(context.read<CashflowStore>()).length - 1;
        });
      },
    );
  }

  void _showManageCategoryOptions(int index, TransactionCategory cat) {
    showAnimatedDialog(
      context: context,
      barrierColor: Colors.black38,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: EdgeInsets.symmetric(horizontal: 32),
              padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 16,
                    offset: Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Tùy chỉnh danh mục',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.slate800,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '${cat.emoji} ${cat.label}',
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.slate500,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(ctx);
                            final store = context.read<CashflowStore>();
                            store.deleteTransactionCategory(cat.id!);
                            setState(() {
                              if (_selectedCategory == index) {
                                _selectedCategory = 0;
                              } else if (_selectedCategory > index) {
                                _selectedCategory -= 1;
                              }
                            });
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.red50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.delete_outline,
                                  color:
                                      Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? AppColors.red400
                                      : AppColors.red600,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Xoá',
                                  style: TextStyle(
                                    color:
                                        Theme.of(context).brightness ==
                                            Brightness.dark
                                        ? AppColors.red400
                                        : AppColors.red600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            HapticFeedback.lightImpact();
                            Navigator.pop(ctx);
                            showAddCategoryDialog(
                              context: context,
                              type: 'chi',
                              initialName: cat.label,
                              initialEmoji: cat.emoji,
                              initialColor: cat.color,
                              onSave: (name, emoji, color) {
                                final store = context.read<CashflowStore>();
                                store.updateTransactionCategory(
                                  TransactionCategory(
                                    id: cat.id,
                                    storeId: cat.storeId,
                                    type: 'chi',
                                    emoji: emoji,
                                    label: name,
                                    color: color,
                                    isCustom: true,
                                  ),
                                );
                                setState(() {
                                  _selectedCategory = index;
                                });
                              },
                            );
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Ink(
                            padding: EdgeInsets.symmetric(vertical: 12),
                            decoration: BoxDecoration(
                              color: AppColors.emerald50,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  Icons.edit_outlined,
                                  color: AppColors.emerald600,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Sửa',
                                  style: TextStyle(
                                    color: AppColors.emerald600,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
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
      },
    );
  }

  void submit() => _handleSave();

  void _handleSave() async {
    final rawText = _amountCtrl.text.replaceAll(',', '');
    final amount = double.tryParse(rawText) ?? 0;
    if (amount <= 0) {
      final store = context.read<CashflowStore>();
      store.showToast('Vui lòng nhập số tiền hợp lệ', 'error');
      return;
    }
    final store = context.read<CashflowStore>();

    if (widget.initialTransaction != null) {
      await store.updateTransaction(
        id: widget.initialTransaction!.id,
        amount: amount,
        category: _getCategories(store)[_selectedCategory].label,
        note: _noteCtrl.text.trim(),
        date: _selectedDate,
      );
      if (!mounted) return;
      store.showToast('Đã lưu thay đổi!');
    } else {
      await store.addTransaction(
        type: 'chi',
        amount: amount,
        category: _getCategories(store)[_selectedCategory].label,
        note: _noteCtrl.text.trim(),
        date: _selectedDate,
      );
      if (!mounted) return;
      store.showToast('Đã lưu khoản chi thành công!');
    }

    if (widget.onSaved != null) {
      widget.onSaved!();
    } else if (widget.embedded && widget.onBack != null) {
      widget.onBack!();
    } else {
      if (GoRouter.of(context).canPop()) {
        context.pop();
      } else {
        context.go('/settings?tab=cashflow');
      }
    }
  }
}

// ── Thousand separator formatter ─────────────────────────
class _ThousandSeparatorFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final digits = newValue.text.replaceAll(',', '');
    if (digits.isEmpty) return newValue.copyWith(text: '');
    final formatted = digits.replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+(?!\d))'),
      (m) => '${m[1]},',
    );
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }
}
