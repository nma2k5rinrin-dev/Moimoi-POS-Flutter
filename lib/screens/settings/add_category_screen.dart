import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../models/category_model.dart';
import '../../utils/constants.dart';

class AddCategoryPanel extends StatefulWidget {
  final VoidCallback onClose;
  final CategoryModel? existingCategory;

  const AddCategoryPanel({
    super.key,
    required this.onClose,
    this.existingCategory,
  });

  @override
  State<AddCategoryPanel> createState() => _AddCategoryPanelState();
}

class _AddCategoryPanelState extends State<AddCategoryPanel>
    with SingleTickerProviderStateMixin {
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  int _selectedColorIndex = 0;
  String _selectedEmoji = '☕';

  late final AnimationController _animCtrl;
  late final Animation<double> _fadeAnim;
  late final Animation<Offset> _slideAnim;

  bool get _isEditMode => widget.existingCategory != null;

  static const _colorPalette = [
    Color(0xFF10B981), // emerald
    Color(0xFF3B82F6), // blue
    Color(0xFFF59E0B), // amber
    Color(0xFFEF4444), // red
    Color(0xFF8B5CF6), // violet
    Color(0xFFF97316), // orange
    Color(0xFFEC4899), // pink
  ];

  @override
  void initState() {
    super.initState();
    final cat = widget.existingCategory;
    if (cat != null) {
      _nameCtrl.text = cat.name;
      if (cat.emoji.isNotEmpty) _selectedEmoji = cat.emoji;
      if (cat.color.isNotEmpty) {
        try {
          final hex = cat.color.replaceFirst('#', '');
          final savedColor = Color(int.parse('FF$hex', radix: 16));
          final idx = _colorPalette.indexWhere((c) => c.value == savedColor.value);
          if (idx >= 0) _selectedColorIndex = idx;
        } catch (_) {}
      }
    }

    _animCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _fadeAnim = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  void _closeWithAnimation() async {
    await _animCtrl.reverse();
    widget.onClose();
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: FadeTransition(
      opacity: _fadeAnim,
      child: Stack(
        children: [
          // ── Dim Overlay ─────────────────────
          Positioned.fill(
            child: GestureDetector(
              onTap: _closeWithAnimation,
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.4),
                ),
              ),
            ),
          ),

          // ── Panel ───────────────────────────
          Positioned(
            left: 0,
            right: 0,
            top: MediaQuery.of(context).padding.top + 40,
            bottom: MediaQuery.of(context).viewInsets.bottom,
            child: Center(
            child: SlideTransition(
              position: _slideAnim,
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: 480,
                  maxHeight: MediaQuery.of(context).size.height * 0.85 - MediaQuery.of(context).viewInsets.bottom,
                ),
                margin: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 40,
                      offset: const Offset(0, 12),
                    ),
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ── Panel Header ──────────────
                    _buildHeader(),

                    // ── Form Body ────────────────
                    Flexible(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // ── Icon Picker ──────
                            _buildIconSection(),
                            const SizedBox(height: 18),

                            // ── Tên danh mục ─────
                            _buildLabel('Tên danh mục'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _nameCtrl,
                              hint: 'VD: Đồ uống, Món chính...',
                              icon: Icons.edit,
                            ),
                            const SizedBox(height: 18),

                            // ── Mô tả ────────────
                            _buildLabel('Mô tả (tùy chọn)'),
                            const SizedBox(height: 6),
                            _buildTextField(
                              controller: _descCtrl,
                              hint: 'Mô tả ngắn về danh mục',
                              icon: Icons.description_outlined,
                            ),
                            const SizedBox(height: 18),

                            // ── Màu danh mục ─────
                            _buildLabel('Màu danh mục'),
                            const SizedBox(height: 6),
                            _buildColorPicker(),
                            const SizedBox(height: 18),

                            // ── Action Buttons ───
                            _buildButtons(),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ),
          ),
        ],
      ),
    ),
    );
  }

  // ── Panel Header with gradient ──────────────────
  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppColors.emerald50, Colors.white],
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.category_rounded,
              color: AppColors.emerald600, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _isEditMode ? 'Sửa danh mục' : 'Thêm danh mục',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.slate800,
              ),
            ),
          ),
          GestureDetector(
            onTap: _closeWithAnimation,
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.slate100,
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Icon(Icons.close, size: 18, color: AppColors.slate500),
            ),
          ),
        ],
      ),
    );
  }

  // ── Icon Section ────────────────────────────────
  Widget _buildIconSection() {
    return Center(
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              final result = await _showEmojiPickerDialog();
              if (result != null) {
                setState(() => _selectedEmoji = result);
              }
            },
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.emerald50,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.emerald200,
                  width: 2,
                ),
              ),
              child: Center(
                child: Text(_selectedEmoji, style: const TextStyle(fontSize: 36)),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Chọn icon danh mục',
            style: TextStyle(
              fontSize: 13,
              color: AppColors.slate400,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  static const _emojis = [
    '🔥','💛','💚','💙','💜','🖤','💔','❣','💕','💞',
    '💓','💗','💖','💘','💝','💟','👏','🙏','🤝','👍',
    '👎','👊','✊','🤛','🤜','🤞','✌','🤘','👌','👈',
    '👉','👆','👇','☝','✋','🤚','🖐','🖖','👋','🤙',
    '💪','🖕','✍','🤳','💅','💍','💄','💋','👄','👅',
    '👂','👃','👣','👁','👀','🗣','👤','👥','👶','👦',
    '👧','👨','👩','👱','👴','👵','👲','👳','👮','👷',
    '💂','🕵','🤶','🎅','👸','🤴','👰','🤵','👼','🤰',
    '🙇','💁','🙅','🙆','🙋','🙎','🙍','💇','💆','🕴',
    '💃','🕺','👯','🚶','🏃','👫','👭','👬','💑','👪',
    '👚','👕','👖','👔','👗','👙','👘','👠','👡','👢',
    '👞','👟','👒','🎩','🎓','👑','⛑','🎒','👝','👛',
    '👜','💼','👓','🕶','🌂','☂',
    '⌚','📱','📲','💻','⌨','🖥','🖨','🖱','🖲','🕹',
    '🗜','💽','💾','💿','📀','📼','📷','📸','📹','🎥',
    '📽','🎞','📞','☎','📟','📠','📺','📻','🎙','🎚',
    '🎛','⏱','⏲','⏰','🕰','⌛','⏳','📡','🔋','🔌',
    '💡','🔦','🕯','🗑','🛢','💸','💵','💴','💶','💷',
    '💰','💳','💎','⚖','🔧','🔨','⚒','🛠','⛏','🔩',
    '🧱','⚙','⛓','🔫','💣','🔪','🗡','⚔','🛡','🚬',
    '🏺','🔮','📿','💈','⚗','🔭','🔬','🕳','💊','💉',
    '🌡','🚽','🚰','🚿','🛁','🛀','🛎','🔑','🗝','🚪',
    '🛋','🛏','🛌','🖼','🛍','🛒','🎁','🎈','🎏','🎀',
    '🎊','🎉','🎎','🏮','🎐',
    '✉','📩','📨','📧','💌','📥','📤','📦','🏷','📪',
    '📫','📬','📭','📮','📯','📜','📃','📄','📑','📊',
    '📈','📉','🗒','🗓','📆','📅','📇','🗃','🗳','🗄',
    '📋','📁','📂','🗂','🗞','📰','📓','📔','📒','📕',
    '📗','📘','📙','📚','📖','🔖','🔗','📎','🖇','📐',
    '📏','📌','📍','✂','🖊','🖋','✒','🖌','🖍','📝',
    '✏','🔍','🔎','🔏','🔐','🔒','🔓',
    '🐶','🐱','🐭','🐹','🐰','🦊','🐻','🐼','🐨','🐯',
    '🦁','🐮','🐷','🐽','🐸','🐵','🙊','🙉','🐒','🐔',
    '🐧','🐦','🐤','🐣','🐥','🦆','🦅','🦉','🦇','🐺',
    '🐗','🐴','🦄','🐝','🐛','🦋','🐌','🐚','🐞','🐜',
    '🕷','🕸','🐢','🐍','🦎','🦂','🦀','🦑','🐙','🦐',
    '🐠','🐟','🐡','🐬','🦈','🐳','🐋','🐊','🐆','🐅',
    '🐃','🐂','🐄','🦌','🐪','🐫','🐘','🦏','🦍','🐎',
    '🐖','🐐','🐏','🐑','🐕','🐩','🐈','🐓','🦃','🕊',
    '🐇','🐁','🐀','🐿','🐾','🐉','🐲',
    '🌵','🎄','🌲','🌳','🌴','🌱','🌿','☘','🍀','🎍',
    '🎋','🍃','🍂','🍁','🍄','🌾','💐','🌷','🌹','🥀',
    '🌻','🌼','🌸','🌺','🌎','🌍','🌏','🌕','🌑','🌙',
    '💫','⭐','🌟','✨','⚡','🔥','💥','☄','☀','🌤',
    '⛅','🌈','☁','🌊','💧','💦','☔',
    '🍏','🍎','🍐','🍊','🍋','🍌','🍉','🍇','🍓','🍈',
    '🍒','🍑','🍍','🥝','🥑','🍅','🍆','🥒','🥕','🌽',
    '🌶','🥔','🍠','🌰','🥜','🍯','🥐','🍞','🥖','🧀',
    '🥚','🍳','🥓','🥞','🍤','🍗','🍖','🍕','🌭','🍔',
    '🍟','🥙','🌮','🌯','🥗','🥘','🍝','🍜','🍲','🍥',
    '🍣','🍱','🍛','🍚','🍙','🍘','🍢','🍡','🍧','🍨',
    '🍦','🍰','🎂','🍮','🍭','🍬','🍫','🍿','🍩','🍪',
    '🥛','🍼','☕','🍵','🍶','🍺','🍻','🥂','🍷','🥃',
    '🍸','🍹','🍾','🥄','🍴','🍽',
    '⚽','🏀','🏈','⚾','🎾','🏐','🏉','🎱','🏓','🏸',
    '🥅','🏒','🏑','🏏','⛳','🏹','🎣','🥊','🥋','⛸',
    '🎿','⛷','🏂','🏋','🤺','🏌','🏄','🏊','🤽','🚣',
    '🏇','🚴','🚵','🎽','🏅','🎖','🥇','🥈','🥉','🏆',
    '🏵','🎗','🎫','🎟','🎪','🎭','🎨','🎬','🎤','🎧',
    '🎼','🎹','🥁','🎷','🎺','🎸','🎻','🎲','🎯','🎳',
    '🎮','🎰',
    '🚗','🚕','🚙','🚌','🚎','🏎','🚓','🚑','🚒','🚐',
    '🚚','🚛','🚜','🛴','🚲','🛵','🏍','🚨','🚔','🚍',
    '🚘','🚖','🚡','🚠','🚟','🚃','🚋','🚞','🚝','🚄',
    '🚅','🚈','🚂','🚆','🚇','🚊','🚉','🚁','🛩','✈',
    '🛫','🛬','🚀','🛰','💺','🛶','⛵','🛥','🚤','🛳',
    '⛴','🚢','⚓','🚧','⛽','🚏','🚦','🚥','🗺','🗿',
    '🗽','⛲','🗼','🏰','🏯','🏟','🎡','🎢','🎠','⛱',
    '🏖','🏝','⛰','🏔','🗻','🌋','🏜','🏕','⛺','🛤',
    '🛣','🏗','🏭','🏠','🏡','🏘','🏚','🏢','🏬','🏣',
    '🏤','🏥','🏦','🏨','🏪','🏫','🏩','💒','🏛','⛪',
    '🕌','🕍','🕋','⛩','🗾','🎑','🏞','🌅','🌄','🌠',
    '🎇','🎆','🌇','🌆','🏙','🌃','🌌','🌉','🌁',
    '☮','✝','☪','🕉','☸','✡','🔯','🕎','☯','☦',
    '🛐','⛎','♈','♉','♊','♋','♌','♍','♎','♏',
    '♐','♑','♒','♓','🆔','⚛','☢','☣','🆚','💮',
    '🅰','🅱','🆎','🆑','🅾','🆘','❌','⭕','🛑','⛔',
    '📛','🚫','💯','💢','♨','🚷','🚯','🚳','🚱','🔞',
    '📵','🚭','❗','❕','❓','❔','🔅','🔆','〽','⚠',
    '🚸','🔱','⚜','🔰','♻','✅','💹','❇','✳','❎',
    '🌐','💠','🌀','💤','🏧','🚾','♿','🅿','🈳','🛂',
    '🛃','🛄','🛅','🚹','🚺','🚼','🚻','🚮','🎦','📶',
    '🏳','🏴','🏁','🚩','🏳',
  ];

  Future<String?> _showEmojiPickerDialog() {
    return showDialog<String>(
      context: context,
      builder: (ctx) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 400,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Chọn biểu tượng',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800,
                              color: AppColors.slate800)),
                      GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: const Icon(Icons.close_rounded, color: AppColors.slate400, size: 22),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    height: 300,
                    decoration: BoxDecoration(
                      color: AppColors.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: GridView.builder(
                      padding: const EdgeInsets.all(8),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 10,
                        mainAxisSpacing: 4,
                        crossAxisSpacing: 4,
                      ),
                      itemCount: _emojis.length,
                      itemBuilder: (_, i) {
                        return GestureDetector(
                          onTap: () => Navigator.pop(ctx, _emojis[i]),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Center(
                              child: Text(_emojis[i],
                                style: const TextStyle(fontSize: 20)),
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
        );
      },
    );
  }

  // ── Label ───────────────────────────────────────
  Widget _buildLabel(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: AppColors.slate600,
      ),
    );
  }

  // ── Text Field ──────────────────────────────────
  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
  }) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: const TextStyle(color: AppColors.slate400, fontSize: 14),
        prefixIcon: Icon(icon, color: AppColors.slate400, size: 18),
        filled: true,
        fillColor: Colors.white,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.slate200),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.emerald400),
        ),
      ),
    );
  }

  // ── Color Picker ────────────────────────────────
  Widget _buildColorPicker() {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: List.generate(_colorPalette.length, (i) {
        final isSelected = i == _selectedColorIndex;
        return GestureDetector(
          onTap: () => setState(() => _selectedColorIndex = i),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _colorPalette[i],
              shape: BoxShape.circle,
              border: isSelected
                  ? Border.all(
                      color: Colors.white,
                      width: 3,
                      strokeAlign: BorderSide.strokeAlignInside,
                    )
                  : null,
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: _colorPalette[i].withValues(alpha: 0.5),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: isSelected
                ? const Icon(Icons.check, color: Colors.white, size: 18)
                : null,
          ),
        );
      }),
    );
  }

  // ── Action Buttons ──────────────────────────────
  Widget _buildButtons() {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: _closeWithAnimation,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.red500, width: 1),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.close, size: 20, color: AppColors.red500),
                  SizedBox(width: 8),
                  Text(
                    'Hủy bỏ',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppColors.red500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: GestureDetector(
            onTap: _saveCategory,
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                color: AppColors.emerald500,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_isEditMode ? Icons.save : Icons.add_circle,
                      size: 20, color: Colors.white),
                  const SizedBox(width: 8),
                  Text(
                    _isEditMode ? 'Lưu thay đổi' : 'Thêm danh mục',
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
        ),
      ],
    );
  }

  // ── Save Category ───────────────────────────────
  void _saveCategory() {
    final store = context.read<AppStore>();
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      store.showToast('Tên danh mục không được trống', 'error');
      return;
    }

    final colorHex = '#${_colorPalette[_selectedColorIndex].value.toRadixString(16).padLeft(8, '0').substring(2).toUpperCase()}';

    if (_isEditMode) {
      store.updateCategory(CategoryModel(
        id: widget.existingCategory!.id,
        name: name,
        storeId: widget.existingCategory!.storeId,
        emoji: _selectedEmoji,
        color: colorHex,
      ));
      store.showToast('Đã cập nhật danh mục "$name"!');
    } else {
      store.addCategory(name, emoji: _selectedEmoji, color: colorHex);
      store.showToast('Đã thêm danh mục "$name"!');
    }
    _closeWithAnimation();
  }
}
