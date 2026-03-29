import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/shared_widgets.dart';

class TablesSection extends StatefulWidget {
  const TablesSection({super.key});

  @override
  State<TablesSection> createState() => _TablesSectionState();
}

class _TablesSectionState extends State<TablesSection> {
  final Set<String> _collapsedAreas = {};
  String _searchQuery = '';

  // Add/Edit panel state
  bool _showPanel = false;
  String? _editingTable; // original name to edit
  final _tableNameCtrl = TextEditingController();
  final _areaCtrl = TextEditingController();
  final _newAreaCtrl = TextEditingController();
  String _newAreaName = '';
  bool _isDefault = false;
  StateSetter? _dialogSetState;

  @override
  void dispose() {
    _tableNameCtrl.dispose();
    _areaCtrl.dispose();
    _newAreaCtrl.dispose();
    super.dispose();
  }

  // ── Default table prefix helpers ────────────────────
  static const _defaultPrefix = '\u2605';
  static bool _isDefaultTable(String raw) => raw.startsWith(_defaultPrefix);
  static String _stripDefault(String raw) => raw.startsWith(_defaultPrefix) ? raw.substring(1) : raw;
  static String _makeDefault(String raw) => '$_defaultPrefix$raw';

  // ── Parse area · table name ──────────────────────────
  static String _areaOf(String raw) {
    final clean = _stripDefault(raw);
    final parts = clean.split(' · ');
    return parts.length > 1 ? parts[0] : 'Mặc định';
  }

  static String _nameOf(String raw) {
    final clean = _stripDefault(raw);
    final parts = clean.split(' · ');
    return parts.length > 1 ? parts.sublist(1).join(' · ') : clean;
  }

  static final _tableAvatarColors = [
    const Color(0xFF10B981),
    const Color(0xFF3B82F6),
    const Color(0xFFF59E0B),
    const Color(0xFF8B5CF6),
    const Color(0xFFEF4444),
    const Color(0xFFEC4899),
  ];

  Color _avatarColor(int i) => _tableAvatarColors[i % _tableAvatarColors.length];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final tables = store.currentTables;

    // Apply search
    var display = tables.toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      display = display.where((t) => _stripDefault(t).toLowerCase().contains(q)).toList();
    }

    // Separate default tables from area groups
    final defaultTables = display.where((t) => _isDefaultTable(t)).toList();
    final nonDefaultTables = display.where((t) => !_isDefaultTable(t)).toList();

    // Group non-default by area
    final Map<String, List<String>> areaGroups = {};
    for (final t in nonDefaultTables) {
      final area = _areaOf(t);
      areaGroups.putIfAbsent(area, () => []);
      areaGroups[area]!.add(t);
    }

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  const SizedBox(height: 12),
                  // ── Search Bar ──────────────────────
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 20, color: AppColors.slate400),
                        const SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: const InputDecoration(
                              hintText: 'Tìm kiếm bàn...',
                              hintStyle: TextStyle(fontSize: 14, color: AppColors.slate400),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: const TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // ── Scrollable List ───────
                  Expanded(
                    child: (defaultTables.isEmpty && areaGroups.isEmpty)
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.table_restaurant_outlined, size: 48, color: AppColors.slate300),
                                const SizedBox(height: 12),
                                const Text('Chưa có bàn nào',
                                    style: TextStyle(color: AppColors.slate400, fontSize: 14, fontWeight: FontWeight.w500)),
                                const SizedBox(height: 4),
                                const Text('Hãy thêm bàn đầu tiên!',
                                    style: TextStyle(color: AppColors.slate400, fontSize: 13)),
                              ],
                            ),
                          )
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              ...defaultTables.map((raw) {
                                final stripped = _stripDefault(raw);
                                final displayName = _nameOf(stripped);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: GestureDetector(
                                    onTap: () => _openEditPanel(raw),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: AppColors.slate200),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            width: 40, height: 40,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFFFF7ED),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(Icons.shopping_bag_outlined, size: 20, color: Color(0xFFF59E0B)),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(displayName,
                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                                          ),
                                          GestureDetector(
                                            onTap: () {
                                              store.showConfirm(
                                                'Xóa bàn "$displayName"?',
                                                () => store.removeTable(raw),
                                                title: 'Xóa bàn?',
                                                description: 'Bạn có chắc muốn xóa bàn này?',
                                                icon: Icons.shopping_bag_outlined,
                                                itemName: displayName,
                                              );
                                            },
                                            child: Container(
                                              width: 36, height: 36,
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFFEF2F2),
                                                borderRadius: BorderRadius.circular(10),
                                              ),
                                              child: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                );
                              }),
                              if (defaultTables.isNotEmpty && areaGroups.isNotEmpty)
                                const SizedBox(height: 4),
                              ...areaGroups.entries.map((entry) {
                                final areaName = entry.key;
                                final areaTables = entry.value;
                                final isCollapsed = _collapsedAreas.contains(areaName);
                                return Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    clipBehavior: Clip.antiAlias,
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: AppColors.slate200),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => setState(() {
                                            isCollapsed ? _collapsedAreas.remove(areaName) : _collapsedAreas.add(areaName);
                                          }),
                                          child: Row(
                                            children: [
                                              const Icon(Icons.location_on_rounded, size: 16, color: AppColors.emerald600),
                                              const SizedBox(width: 6),
                                              Expanded(
                                                child: Text(areaName,
                                                    style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.slate800)),
                                              ),
                                              if (areaName != 'Mặc định')
                                                GestureDetector(
                                                  onTap: () => _showRenameAreaDialog(areaName),
                                                  child: Container(
                                                    width: 28, height: 28,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.slate100,
                                                      borderRadius: BorderRadius.circular(8),
                                                    ),
                                                    child: const Icon(Icons.edit, size: 14, color: AppColors.emerald500),
                                                  ),
                                                ),
                                              const SizedBox(width: 8),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: AppColors.emerald50,
                                                  borderRadius: BorderRadius.circular(10),
                                                ),
                                                child: Text('${areaTables.length} bàn',
                                                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.emerald600)),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(isCollapsed ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_up,
                                                  size: 18, color: AppColors.slate400),
                                            ],
                                          ),
                                        ),
                                        if (!isCollapsed)
                                          ...areaTables.asMap().entries.map((e) {
                                            final idx = e.key;
                                            final raw = e.value;
                                            final displayName = _nameOf(raw);
                                            final initials = displayName.length >= 2
                                                ? displayName.substring(0, 2).toUpperCase()
                                                : displayName.toUpperCase();
                                            final color = _avatarColor(idx);
                                            return Padding(
                                              padding: const EdgeInsets.only(top: 10),
                                              child: GestureDetector(
                                                onTap: () => _openEditPanel(raw),
                                                child: Container(
                                                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.slate50,
                                                    borderRadius: BorderRadius.circular(14),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 40, height: 40,
                                                        decoration: BoxDecoration(
                                                          color: color.withValues(alpha: 0.15),
                                                          borderRadius: BorderRadius.circular(20),
                                                        ),
                                                        child: Center(
                                                          child: Text(initials,
                                                              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: color)),
                                                        ),
                                                      ),
                                                      const SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment: CrossAxisAlignment.start,
                                                          children: [
                                                            Text(displayName,
                                                                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.slate800)),
                                                            const SizedBox(height: 2),
                                                            Text(areaName, style: const TextStyle(fontSize: 12, color: AppColors.slate500)),
                                                          ],
                                                        ),
                                                      ),
                                                      GestureDetector(
                                                        onTap: () {
                                                          store.showConfirm(
                                                            'Xóa bàn "$displayName"?',
                                                            () => store.removeTable(raw),
                                                            title: 'Xóa bàn?',
                                                            description: 'Bạn có chắc muốn xóa bàn này?',
                                                            icon: Icons.table_restaurant_outlined,
                                                            itemName: displayName,
                                                            itemSubtitle: areaName,
                                                            avatarInitials: initials,
                                                            avatarColor: color,
                                                          );
                                                        },
                                                        child: Container(
                                                          width: 36, height: 36,
                                                          decoration: BoxDecoration(
                                                            color: const Color(0xFFFEF2F2),
                                                            borderRadius: BorderRadius.circular(10),
                                                          ),
                                                          child: const Icon(Icons.delete_outline, size: 20, color: Color(0xFFEF4444)),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ),
                                            );
                                          }),
                                      ],
                                    ),
                                  ),
                                );
                              }),
                            ],
                          ),
                  ),
                  const SizedBox(height: 12),
                  // ── Add Button ─────────────────────────────
                  GestureDetector(
                    onTap: _openAddPanel,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.emerald500,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.add_circle_outline, size: 20, color: Colors.white),
                          SizedBox(width: 8),
                          Text('Thêm bàn mới', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _showRenameAreaDialog(String oldAreaName) {
    final controller = TextEditingController(text: oldAreaName);
    final store = context.read<AppStore>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Text('Sửa khu vực', style: TextStyle(fontWeight: FontWeight.w700)),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Nhập tên khu vực mới...',
              filled: true,
              fillColor: AppColors.slate50,
              prefixIcon: const Icon(Icons.location_on_outlined, color: AppColors.emerald500, size: 18),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.slate200)),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: AppColors.emerald400)),
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Hủy', style: TextStyle(color: AppColors.slate500))),
          ElevatedButton(
            onPressed: () {
              final newName = controller.text.trim();
              if (newName.isEmpty || newName == oldAreaName) {
                Navigator.pop(ctx);
                return;
              }
              store.renameArea(oldAreaName, newName);
              store.showToast('Đã đổi tên khu vực thành "$newName"');
              Navigator.pop(ctx);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Lưu'),
          ),
        ],
      ),
    );
  }

  void _openAddPanel() {
    _editingTable = null;
    _tableNameCtrl.clear();
    _areaCtrl.clear();
    _newAreaCtrl.clear();
    _newAreaName = '';
    _isDefault = false;
    _showTablePanelDialog();
  }

  void _openEditPanel(String rawTableName) {
    _editingTable = rawTableName;
    _isDefault = _isDefaultTable(rawTableName);
    final stripped = _stripDefault(rawTableName);
    _areaCtrl.text = _areaOf(stripped) == 'Mặc định' ? '' : _areaOf(stripped);
    _tableNameCtrl.text = _nameOf(stripped);
    _newAreaCtrl.clear();
    _newAreaName = '';
    _showTablePanelDialog();
  }

  void _showTablePanelDialog() {
    showGeneralDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      useRootNavigator: true,
      transitionDuration: Duration.zero,
      pageBuilder: (ctx, _, _) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            _dialogSetState = setDialogState;
            return _buildTableFormPanel(context.read<AppStore>());
          },
        );
      },
    );
  }

  void _closePanel() {
    Navigator.of(context, rootNavigator: true).pop();
    setState(() => _showPanel = false);
  }

  Widget _buildTableFormPanel(AppStore store) {
    final isEditing = _editingTable != null;
    return Material(
      type: MaterialType.transparency,
      child: SizedBox.expand(
        child: GestureDetector(
          onTap: _closePanel,
          child: Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 2, sigmaY: 2),
              child: GestureDetector(
                onTap: () {},
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: Container(
                          constraints: const BoxConstraints(maxWidth: 480),
                          margin: const EdgeInsets.symmetric(horizontal: 24),
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 40, offset: const Offset(0, 12)),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.table_restaurant_rounded, color: AppColors.emerald600, size: 22),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(isEditing ? 'Sửa bàn' : 'Thêm bàn mới',
                                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: AppColors.slate800)),
                                  ),
                                  GestureDetector(
                                    onTap: _closePanel,
                                    child: Container(
                                      width: 32, height: 32,
                                      decoration: BoxDecoration(color: AppColors.slate100, borderRadius: BorderRadius.circular(16)),
                                      child: const Icon(Icons.close, size: 18, color: AppColors.slate500),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 20),
                              const Text('Khu vực (tùy chọn)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600)),
                              const SizedBox(height: 6),
                              Builder(builder: (ctx) {
                                final allTables = store.currentTables;
                                final existingAreas = <String>{};
                                for (final t in allTables) {
                                  final parts = t.split(' · ');
                                  if (parts.length > 1) existingAreas.add(parts[0]);
                                }
                                final areaList = existingAreas.toList()..sort();
                                final currentAreaText = _areaCtrl.text.trim();
                                final isNewArea = currentAreaText.isNotEmpty && !areaList.contains(currentAreaText);

                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Builder(builder: (ctx) {
                                      final areaFieldKey = GlobalKey();
                                      final displayText = areaList.contains(currentAreaText)
                                          ? currentAreaText
                                          : (isNewArea ? 'Thêm khu vực mới...' : 'Chọn khu vực hoặc thêm mới');
                                      return GestureDetector(
                                        key: areaFieldKey,
                                        onTap: () {
                                          final renderBox = areaFieldKey.currentContext?.findRenderObject() as RenderBox?;
                                          if (renderBox == null) return;
                                          final position = renderBox.localToGlobal(Offset.zero);
                                          final fieldSize = renderBox.size;
                                          showMenu<String>(
                                            context: areaFieldKey.currentContext!,
                                            position: RelativeRect.fromLTRB(position.dx, position.dy + fieldSize.height, position.dx + fieldSize.width, 0),
                                            items: [
                                              const PopupMenuItem<String>(value: '', child: Text('Mặc định (không có khu vực)')),
                                              ...areaList.map((a) => PopupMenuItem<String>(value: a, child: Text(a))),
                                              const PopupMenuItem<String>(value: 'NEW', child: Text('+ Thêm khu vực mới...', style: TextStyle(color: AppColors.emerald600))),
                                            ],
                                          ).then((v) {
                                            if (v == null) return;
                                            if (v == 'NEW') {
                                              _dialogSetState?.call(() {
                                                _areaCtrl.clear();
                                                _newAreaName = 'NEW';
                                              });
                                            } else {
                                              _dialogSetState?.call(() {
                                                _areaCtrl.text = v;
                                                _newAreaName = '';
                                              });
                                            }
                                          });
                                        },
                                        child: Container(
                                          height: 48,
                                          padding: const EdgeInsets.symmetric(horizontal: 14),
                                          decoration: BoxDecoration(color: AppColors.slate50, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.slate200)),
                                          child: Row(children: [
                                            const Icon(Icons.location_on_outlined, size: 20, color: AppColors.slate400),
                                            const SizedBox(width: 10),
                                            Expanded(child: Text(displayText, style: const TextStyle(fontSize: 14))),
                                            const Icon(Icons.keyboard_arrow_down, size: 20, color: AppColors.slate400),
                                          ]),
                                        ),
                                      );
                                    }),
                                    if (_newAreaName == 'NEW') ...[
                                      const SizedBox(height: 12),
                                      SettingsDialogField(controller: _newAreaCtrl, label: 'Tên khu vực mới'),
                                    ],
                                  ],
                                );
                              }),
                              const SizedBox(height: 16),
                              SettingsDialogField(controller: _tableNameCtrl, label: 'Tên bàn/Số bàn (VD: Bàn 01)'),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  const Text('Ghim bàn? (Phục vụ liên tục)', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.slate600)),
                                  const Spacer(),
                                  Switch.adaptive(
                                    value: _isDefault,
                                    onChanged: (v) => _dialogSetState?.call(() => _isDefault = v),
                                    activeTrackColor: AppColors.emerald500,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              ElevatedButton(
                                onPressed: () => _saveTable(store),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: AppColors.emerald500,
                                  foregroundColor: Colors.white,
                                  minimumSize: const Size(double.infinity, 52),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                ),
                                child: Text(isEditing ? 'Cập nhật' : 'Thêm bàn', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _saveTable(AppStore store) {
    final name = _tableNameCtrl.text.trim();
    if (name.isEmpty) { store.showToast('Vui lòng nhập tên bàn', 'error'); return; }

    var area = _newAreaName == 'NEW' ? _newAreaCtrl.text.trim() : _areaCtrl.text.trim();
    final String fullName = (area.isNotEmpty && area != 'Mặc định') ? '$area · $name' : name;
    final finalName = _isDefault ? _makeDefault(fullName) : fullName;

    if (_editingTable != null) {
      store.updateTable(_editingTable!, finalName);
      store.showToast('Đã cập nhật bàn "$name"');
    } else {
      store.addTable(finalName);
      store.showToast('Đã thêm bàn "$name"');
    }
    _closePanel();
  }
}
