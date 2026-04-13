import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/widgets/animated_dialogs.dart';

/// An entry in the icon picker: the Phosphor duotone icon + search keywords.
class _IconEntry {
  final PhosphorIconData icon;
  final List<String> keywords;
  _IconEntry(this.icon, this.keywords);
}

// ── Default F&B icons (shown when no search) ──────────────────────
final List<_IconEntry> _defaultFnbIcons = [
  _IconEntry(PhosphorIconsDuotone.coffee, ['coffee', 'cà phê', 'cafe', 'nước']),
  _IconEntry(PhosphorIconsDuotone.coffeeBean, [
    'coffee bean',
    'hạt cà phê',
    'bean',
  ]),
  _IconEntry(PhosphorIconsDuotone.teaBag, ['tea', 'trà', 'túi trà']),
  _IconEntry(PhosphorIconsDuotone.cake, [
    'cake',
    'bánh',
    'sinh nhật',
    'dessert',
  ]),
  _IconEntry(PhosphorIconsDuotone.hamburger, [
    'hamburger',
    'burger',
    'bánh mì kẹp',
  ]),
  _IconEntry(PhosphorIconsDuotone.pizza, ['pizza', 'bánh pizza']),
  _IconEntry(PhosphorIconsDuotone.iceCream, ['ice cream', 'kem', 'đá']),
  _IconEntry(PhosphorIconsDuotone.bowlFood, [
    'bowl food',
    'tô',
    'bát',
    'cơm',
    'phở',
  ]),
  _IconEntry(PhosphorIconsDuotone.bowlSteam, [
    'bowl steam',
    'soup',
    'canh',
    'nóng',
    'mì',
  ]),
  _IconEntry(PhosphorIconsDuotone.cookingPot, [
    'processing pot',
    'nồi',
    'lẩu',
    'nấu',
  ]),
  _IconEntry(PhosphorIconsDuotone.forkKnife, [
    'fork knife',
    'dao dĩa',
    'ăn',
    'restaurant',
    'nhà hàng',
  ]),
  _IconEntry(PhosphorIconsDuotone.martini, [
    'martini',
    'cocktail',
    'rượu',
    'drink',
  ]),
  _IconEntry(PhosphorIconsDuotone.wine, ['wine', 'rượu vang', 'vang']),
  _IconEntry(PhosphorIconsDuotone.beerStein, ['beer', 'bia', 'cốc bia']),
  _IconEntry(PhosphorIconsDuotone.beerBottle, [
    'beer bottle',
    'chai bia',
    'bottle',
  ]),
  _IconEntry(PhosphorIconsDuotone.bread, ['bread', 'bánh mì', 'ổ bánh']),
  _IconEntry(PhosphorIconsDuotone.cookie, ['cookie', 'bánh quy', 'snack']),
  _IconEntry(PhosphorIconsDuotone.orangeSlice, [
    'orange',
    'cam',
    'trái cây',
    'fruit',
  ]),
  _IconEntry(PhosphorIconsDuotone.carrot, ['carrot', 'cà rốt', 'rau']),
  _IconEntry(PhosphorIconsDuotone.pepper, ['pepper', 'ớt', 'cay']),
  _IconEntry(PhosphorIconsDuotone.egg, ['egg', 'trứng']),
  _IconEntry(PhosphorIconsDuotone.eggCrack, [
    'egg crack',
    'trứng rán',
    'ốp la',
  ]),
  _IconEntry(PhosphorIconsDuotone.fish, ['fish', 'cá', 'hải sản']),
  _IconEntry(PhosphorIconsDuotone.shrimp, ['shrimp', 'tôm', 'hải sản']),
  _IconEntry(PhosphorIconsDuotone.cheese, ['cheese', 'phô mai', 'pho mai']),
  _IconEntry(PhosphorIconsDuotone.grains, ['grains', 'ngũ cốc', 'gạo', 'lúa']),
  _IconEntry(PhosphorIconsDuotone.leaf, ['leaf', 'lá', 'organic', 'healthy']),
  _IconEntry(PhosphorIconsDuotone.plant, ['plant', 'cây', 'thực vật']),
  _IconEntry(PhosphorIconsDuotone.pottedPlant, [
    'potted plant',
    'chậu cây',
    'trang trí',
  ]),
  _IconEntry(PhosphorIconsDuotone.fire, [
    'fire',
    'lửa',
    'nóng',
    'hot',
    'nướng',
    'bbq',
  ]),
  _IconEntry(PhosphorIconsDuotone.flame, ['flame', 'ngọn lửa', 'cay']),
  _IconEntry(PhosphorIconsDuotone.drop, ['drop', 'giọt', 'nước', 'water']),
  _IconEntry(PhosphorIconsDuotone.oven, ['oven', 'lò nướng', 'nướng']),
  _IconEntry(PhosphorIconsDuotone.knife, ['knife', 'dao', 'cắt']),
  _IconEntry(PhosphorIconsDuotone.storefront, ['store', 'cửa hàng', 'quán']),
  _IconEntry(PhosphorIconsDuotone.receipt, ['receipt', 'hóa đơn', 'bill']),
  _IconEntry(PhosphorIconsDuotone.shoppingBag, [
    'shopping bag',
    'túi',
    'mang về',
    'takeaway',
  ]),
  _IconEntry(PhosphorIconsDuotone.shoppingCart, ['cart', 'giỏ hàng', 'mua']),
  _IconEntry(PhosphorIconsDuotone.basket, ['basket', 'giỏ', 'rổ']),
  _IconEntry(PhosphorIconsDuotone.callBell, [
    'bell',
    'chuông',
    'gọi',
    'phục vụ',
  ]),
];

// ── Extra icons (only shown via search) ───────────────────────────
final List<_IconEntry> _extraIcons = [
  _IconEntry(PhosphorIconsDuotone.orange, ['orange', 'cam', 'quả cam']),
  _IconEntry(PhosphorIconsDuotone.fishSimple, ['fish simple', 'cá đơn giản']),
  _IconEntry(PhosphorIconsDuotone.flower, ['flower', 'hoa']),
  _IconEntry(PhosphorIconsDuotone.flowerLotus, ['lotus', 'sen', 'hoa sen']),
  _IconEntry(PhosphorIconsDuotone.flowerTulip, ['tulip', 'hoa tulip']),
  _IconEntry(PhosphorIconsDuotone.heart, ['heart', 'tim', 'yêu thích']),
  _IconEntry(PhosphorIconsDuotone.star, ['star', 'ngôi sao', 'đánh giá']),
  _IconEntry(PhosphorIconsDuotone.starHalf, ['star half', 'nửa sao']),
  _IconEntry(PhosphorIconsDuotone.sparkle, ['sparkle', 'lấp lánh', 'mới']),
  _IconEntry(PhosphorIconsDuotone.trophy, ['trophy', 'cúp', 'giải thưởng']),
  _IconEntry(PhosphorIconsDuotone.medal, ['medal', 'huy chương', 'giải']),
  _IconEntry(PhosphorIconsDuotone.crown, [
    'crown',
    'vương miện',
    'premium',
    'vip',
  ]),
  _IconEntry(PhosphorIconsDuotone.gift, ['gift', 'quà', 'tặng', 'khuyến mãi']),
  _IconEntry(PhosphorIconsDuotone.percent, [
    'percent',
    'phần trăm',
    'giảm giá',
    'sale',
  ]),
  _IconEntry(PhosphorIconsDuotone.tag, ['tag', 'thẻ', 'nhãn', 'giá']),
  _IconEntry(PhosphorIconsDuotone.thumbsUp, ['thumbs up', 'thích', 'tốt']),
  _IconEntry(PhosphorIconsDuotone.smiley, ['smiley', 'mặt cười', 'vui']),
  _IconEntry(PhosphorIconsDuotone.smileyWink, ['wink', 'nháy mắt']),
  _IconEntry(PhosphorIconsDuotone.bell, ['bell', 'chuông', 'thông báo']),
  _IconEntry(PhosphorIconsDuotone.bellRinging, ['bell ringing', 'chuông reo']),
  _IconEntry(PhosphorIconsDuotone.clock, [
    'clock',
    'đồng hồ',
    'giờ',
    'thời gian',
  ]),
  _IconEntry(PhosphorIconsDuotone.timer, ['timer', 'hẹn giờ', 'bấm giờ']),
  _IconEntry(PhosphorIconsDuotone.thermometer, [
    'thermometer',
    'nhiệt kế',
    'nhiệt độ',
  ]),
  _IconEntry(PhosphorIconsDuotone.thermometerHot, [
    'thermometer hot',
    'nóng',
    'nhiệt',
  ]),
  _IconEntry(PhosphorIconsDuotone.thermometerCold, [
    'thermometer cold',
    'lạnh',
    'đá',
  ]),
  _IconEntry(PhosphorIconsDuotone.sun, [
    'sun',
    'mặt trời',
    'sáng',
    'buổi sáng',
  ]),
  _IconEntry(PhosphorIconsDuotone.moon, [
    'moon',
    'mặt trăng',
    'tối',
    'buổi tối',
  ]),
  _IconEntry(PhosphorIconsDuotone.moonStars, ['moon stars', 'đêm', 'sao']),
  _IconEntry(PhosphorIconsDuotone.snowflake, [
    'snowflake',
    'tuyết',
    'lạnh',
    'đông',
  ]),
  _IconEntry(PhosphorIconsDuotone.campfire, ['campfire', 'lửa trại', 'bbq']),
  _IconEntry(PhosphorIconsDuotone.tree, ['tree', 'cây', 'rừng']),
  _IconEntry(PhosphorIconsDuotone.treePalm, ['palm tree', 'cọ', 'nhiệt đới']),
  _IconEntry(PhosphorIconsDuotone.musicNote, ['music', 'nhạc', 'âm nhạc']),
  _IconEntry(PhosphorIconsDuotone.musicNotes, ['music notes', 'nốt nhạc']),
  _IconEntry(PhosphorIconsDuotone.palette, [
    'palette',
    'bảng màu',
    'nghệ thuật',
  ]),
  _IconEntry(PhosphorIconsDuotone.handbag, ['handbag', 'túi xách']),
  _IconEntry(PhosphorIconsDuotone.bag, ['bag', 'túi']),
  _IconEntry(PhosphorIconsDuotone.lightning, [
    'lightning',
    'sét',
    'nhanh',
    'năng lượng',
  ]),
  _IconEntry(PhosphorIconsDuotone.handHeart, ['hand heart', 'tay tim', 'yêu']),
  _IconEntry(PhosphorIconsDuotone.sunglasses, [
    'sunglasses',
    'kính mát',
    'cool',
  ]),
  _IconEntry(PhosphorIconsDuotone.armchair, [
    'armchair',
    'ghế',
    'ngồi',
    'sofa',
  ]),
  _IconEntry(PhosphorIconsDuotone.sprayBottle, [
    'spray bottle',
    'bình xịt',
    'vệ sinh',
  ]),
  _IconEntry(PhosphorIconsDuotone.invoice, [
    'invoice',
    'hóa đơn',
    'thanh toán',
  ]),
  _IconEntry(PhosphorIconsDuotone.receiptX, ['receipt x', 'hủy đơn']),
  _IconEntry(PhosphorIconsDuotone.acorn, ['acorn', 'hạt', 'sồi']),
];

// ── All icons combined for search ─────────────────────────────────
final List<_IconEntry> _allIcons = [..._defaultFnbIcons, ..._extraIcons];

/// Shows a modern icon picker dialog with search bar.
/// Returns the index of the selected icon from [_defaultFnbIcons],
/// or null if cancelled.
Future<PhosphorIconData?> showIconPickerDialog(
  BuildContext context, {
  PhosphorIconData? currentIcon,
  required Color accentColor,
}) {
  return showAnimatedDialog<PhosphorIconData?>(
    context: context,
    barrierColor: Colors.transparent,
    builder: (ctx) =>
        _IconPickerDialog(currentIcon: currentIcon, accentColor: accentColor),
  );
}

class _IconPickerDialog extends StatefulWidget {
  final PhosphorIconData? currentIcon;
  final Color accentColor;
  const _IconPickerDialog({this.currentIcon, required this.accentColor});

  @override
  State<_IconPickerDialog> createState() => _IconPickerDialogState();
}

class _IconPickerDialogState extends State<_IconPickerDialog> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<_IconEntry> _filtered = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _filtered = _defaultFnbIcons;
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearch(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) {
      setState(() {
        _filtered = _defaultFnbIcons;
        _isSearching = false;
      });
      return;
    }
    setState(() {
      _isSearching = true;
      _filtered = _allIcons.where((entry) {
        return entry.keywords.any((kw) => kw.contains(q));
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final dialogWidth = (screenSize.width - 48).clamp(280.0, 420.0);
    final gridHeight = (screenSize.height * 0.45).clamp(200.0, 360.0);

    return Stack(
      children: [
        // Blur backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: Container(color: Colors.black.withValues(alpha: 0.3)),
            ),
          ),
        ),
        // Dialog
        Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: dialogWidth,
              margin: EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBg,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 30,
                    offset: Offset(0, 10),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            PhosphorIcon(
                              PhosphorIconsDuotone.gridFour,
                              size: 20,
                              color: widget.accentColor,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Chọn icon',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                                color: AppColors.slate800,
                              ),
                            ),
                          ],
                        ),
                        InkWell(
                          onTap: () => Navigator.pop(context),
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              color: AppColors.slate100,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              Icons.close,
                              size: 18,
                              color: AppColors.slate500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(height: 1, color: AppColors.slate100),

                  // Search bar
                  Padding(
                    padding: EdgeInsets.fromLTRB(16, 14, 16, 6),
                    child: Container(
                      height: 42,
                      decoration: BoxDecoration(
                        color: AppColors.slate50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: Row(
                        children: [
                          SizedBox(width: 12),
                          Icon(
                            Icons.search_rounded,
                            size: 20,
                            color: AppColors.slate400,
                          ),
                          SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _searchCtrl,
                              onChanged: _onSearch,
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.slate700,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Tìm icon... (vd: cà phê, pizza)',
                                hintStyle: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.slate400,
                                ),
                                border: InputBorder.none,
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 8,
                                ),
                              ),
                            ),
                          ),
                          if (_isSearching)
                            GestureDetector(
                              onTap: () {
                                _searchCtrl.clear();
                                _onSearch('');
                              },
                              child: Padding(
                                padding: EdgeInsets.only(right: 10),
                                child: Icon(
                                  Icons.close_rounded,
                                  size: 18,
                                  color: AppColors.slate400,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),

                  // Result info
                  Padding(
                    padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Row(
                      children: [
                        Text(
                          _isSearching
                              ? '${_filtered.length} kết quả'
                              : 'Phổ biến (${_filtered.length})',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.slate400,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Icon grid (scrollable)
                  SizedBox(
                    height: gridHeight,
                    child: _filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                PhosphorIcon(
                                  PhosphorIconsDuotone.magnifyingGlass,
                                  size: 40,
                                  color: AppColors.slate300,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Không tìm thấy icon',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.slate400,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : GridView.builder(
                            padding: EdgeInsets.fromLTRB(16, 0, 16, 16),
                            gridDelegate:
                                SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 5,
                                  mainAxisSpacing: 10,
                                  crossAxisSpacing: 10,
                                ),
                            itemCount: _filtered.length,
                            itemBuilder: (_, i) {
                              final entry = _filtered[i];
                              final isSelected =
                                  widget.currentIcon?.codePoint ==
                                  entry.icon.codePoint;
                              return GestureDetector(
                                onTap: () => Navigator.pop(context, entry.icon),
                                child: AnimatedContainer(
                                  duration: Duration(milliseconds: 180),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? widget.accentColor.withValues(
                                            alpha: 0.12,
                                          )
                                        : AppColors.slate50,
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(
                                      color: isSelected
                                          ? widget.accentColor
                                          : AppColors.slate200,
                                      width: isSelected ? 2 : 1,
                                    ),
                                  ),
                                  child: Tooltip(
                                    message: entry.keywords.first,
                                    child: PhosphorIcon(
                                      entry.icon,
                                      color: isSelected
                                          ? widget.accentColor
                                          : AppColors.slate500,
                                      size: 24,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
