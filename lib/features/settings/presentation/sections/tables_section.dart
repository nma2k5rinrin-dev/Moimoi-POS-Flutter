import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/state/ui_store.dart';
import 'package:moimoi_pos/features/settings/logic/management_store_standalone.dart';
import 'package:moimoi_pos/features/settings/presentation/sections/shared_widgets.dart';
import 'package:flutter_slidable/flutter_slidable.dart';

class TablesSection extends StatefulWidget {
  const TablesSection({super.key});

  @override
  State<TablesSection> createState() => _TablesSectionState();
}

class _TablesSectionState extends State<TablesSection> {
  final Set<String> _collapsedAreas = {};
  String _searchQuery = '';

  // Add/Edit panel state
  // Add/Edit panel state
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
  static final _defaultPrefix = '\u2605';
  static bool _isDefaultTable(String raw) => raw.startsWith(_defaultPrefix);
  static String _stripDefault(String raw) =>
      raw.startsWith(_defaultPrefix) ? raw.substring(1) : raw;
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
    Color(0xFF10B981),
    Color(0xFF3B82F6),
    Color(0xFFF59E0B),
    Color(0xFF8B5CF6),
    Color(0xFFEF4444),
    Color(0xFFEC4899),
  ];

  Color _avatarColor(int i) =>
      _tableAvatarColors[i % _tableAvatarColors.length];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<ManagementStore>();
    final tables = store.currentTables;

    // Apply search
    var display = tables.toList();
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      display = display
          .where((t) => _stripDefault(t).toLowerCase().contains(q))
          .toList();
    }

    // Group all tables by area
    final Map<String, List<String>> areaGroups = {};
    for (final t in display) {
      final isDef = _isDefaultTable(t);
      final area = isDef ? 'Mặc định' : _areaOf(t);
      areaGroups.putIfAbsent(area, () => []);
      areaGroups[area]!.add(t);
    }

    final sortedAreas = areaGroups.keys.toList();
    sortedAreas.sort((a, b) {
      if (a == 'Mặc định') return -1;
      if (b == 'Mặc định') return 1;
      return a.compareTo(b);
    });

    return Column(
      children: [
        Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: 600),
              child: Column(
                children: [
                  SizedBox(height: 12),
                  // ── Search Bar ──────────────────────
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.search, size: 20, color: AppColors.slate400),
                        SizedBox(width: 10),
                        Expanded(
                          child: TextField(
                            onChanged: (v) => setState(() => _searchQuery = v),
                            decoration: InputDecoration(
                              hintText: 'Tìm kiếm bàn...',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: AppColors.slate400,
                              ),
                              border: InputBorder.none,
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                            style: TextStyle(fontSize: 14),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),

                  // ── Scrollable List ───────
                  Expanded(
                    child: areaGroups.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.table_restaurant_outlined,
                                  size: 48,
                                  color: AppColors.slate300,
                                ),
                                SizedBox(height: 12),
                                Text(
                                  'Chưa có bàn nào',
                                  style: TextStyle(
                                    color: AppColors.slate400,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  'Hãy thêm bàn đầu tiên!',
                                  style: TextStyle(
                                    color: AppColors.slate400,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView(
                            padding: EdgeInsets.zero,
                            children: [
                              ...sortedAreas.map((areaName) {
                                final areaTables = areaGroups[areaName]!;
                                final isCollapsed = _collapsedAreas.contains(
                                  areaName,
                                );
                                return Padding(
                                  padding: EdgeInsets.only(bottom: 12),
                                  child: Container(
                                    clipBehavior: Clip.antiAlias,
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: AppColors.cardBg,
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(
                                        color: AppColors.slate200,
                                      ),
                                    ),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () => setState(() {
                                            isCollapsed
                                                ? _collapsedAreas.remove(
                                                    areaName,
                                                  )
                                                : _collapsedAreas.add(areaName);
                                          }),
                                          child: Row(
                                            children: [
                                              Icon(
                                                Icons.location_on_rounded,
                                                size: 16,
                                                color: AppColors.emerald600,
                                              ),
                                              SizedBox(width: 6),
                                              Expanded(
                                                child: Text(
                                                  areaName,
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w700,
                                                    color: AppColors.slate800,
                                                  ),
                                                ),
                                              ),
                                              if (areaName != 'Mặc định')
                                                GestureDetector(
                                                  onTap: () =>
                                                      _showRenameAreaDialog(
                                                        areaName,
                                                      ),
                                                  child: Container(
                                                    width: 28,
                                                    height: 28,
                                                    decoration: BoxDecoration(
                                                      color: AppColors.slate100,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.edit,
                                                      size: 14,
                                                      color:
                                                          AppColors.emerald500,
                                                    ),
                                                  ),
                                                ),
                                              SizedBox(width: 8),
                                              Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 10,
                                                  vertical: 4,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.emerald50,
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                ),
                                                child: Text(
                                                  '${areaTables.length} bàn',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                    color: AppColors.emerald600,
                                                  ),
                                                ),
                                              ),
                                              SizedBox(width: 8),
                                              Icon(
                                                isCollapsed
                                                    ? Icons.keyboard_arrow_down
                                                    : Icons.keyboard_arrow_up,
                                                size: 18,
                                                color: AppColors.slate400,
                                              ),
                                            ],
                                          ),
                                        ),
                                        if (!isCollapsed)
                                          ...areaTables.asMap().entries.map((
                                            e,
                                          ) {
                                            final idx = e.key;
                                            final raw = e.value;
                                            final displayName = _nameOf(raw);
                                            final initials =
                                                displayName.length >= 2
                                                ? displayName
                                                      .substring(0, 2)
                                                      .toUpperCase()
                                                : displayName.toUpperCase();
                                            final color = _avatarColor(idx);
                                            return Padding(
                                              padding: EdgeInsets.only(top: 10),
                                              child: Slidable(
                                                key: ValueKey(raw),
                                                endActionPane: ActionPane(
                                                  motion: DrawerMotion(),
                                                  extentRatio: 0.45,
                                                  children: [
                                                    SlidableAction(
                                                      onPressed: (context) =>
                                                          _openEditPanel(raw),
                                                      backgroundColor:
                                                          AppColors.blue500,
                                                      foregroundColor:
                                                          Colors.white,
                                                      icon: Icons.edit_rounded,
                                                      label: 'Sửa',
                                                    ),
                                                    SlidableAction(
                                                      onPressed: (context) {
                                                        context.read<UIStore>().showConfirm(
                                                          'Xóa bàn "$displayName"?',
                                                          () => store
                                                              .removeTable(raw),
                                                          title: 'Xóa bàn?',
                                                          description:
                                                              'Bạn có chắc muốn xóa bàn này?',
                                                          icon: Icons
                                                              .table_restaurant_outlined,
                                                          itemName: displayName,
                                                          itemSubtitle:
                                                              areaName,
                                                          avatarInitials:
                                                              initials,
                                                          avatarColor: color,
                                                        );
                                                      },
                                                      backgroundColor:
                                                          AppColors.red500,
                                                      foregroundColor:
                                                          Colors.white,
                                                      icon: Icons
                                                          .delete_outline_rounded,
                                                      label: 'Xóa',
                                                      borderRadius:
                                                          BorderRadius.horizontal(
                                                            right:
                                                                Radius.circular(
                                                                  14,
                                                                ),
                                                          ),
                                                    ),
                                                  ],
                                                ),
                                                child: Container(
                                                  padding: EdgeInsets.symmetric(
                                                    horizontal: 14,
                                                    vertical: 12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: AppColors.slate50,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          14,
                                                        ),
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Container(
                                                        width: 40,
                                                        height: 40,
                                                        decoration: BoxDecoration(
                                                          color: color
                                                              .withValues(
                                                                alpha: 0.15,
                                                              ),
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                20,
                                                              ),
                                                        ),
                                                        child: Center(
                                                          child: Text(
                                                            initials,
                                                            style: TextStyle(
                                                              fontSize: 14,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w700,
                                                              color: color,
                                                            ),
                                                          ),
                                                        ),
                                                      ),
                                                      SizedBox(width: 12),
                                                      Expanded(
                                                        child: Column(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .start,
                                                          children: [
                                                            Row(
                                                              children: [
                                                                Flexible(
                                                                  child: Text(
                                                                    displayName,
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          14,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      color: AppColors
                                                                          .slate800,
                                                                    ),
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                                ),
                                                                if (_isDefaultTable(
                                                                  raw,
                                                                )) ...[
                                                                  SizedBox(
                                                                    width: 6,
                                                                  ),
                                                                  Icon(
                                                                    Icons
                                                                        .push_pin_rounded,
                                                                    size: 14,
                                                                    color: AppColors
                                                                        .emerald500,
                                                                  ),
                                                                ],
                                                              ],
                                                            ),
                                                            SizedBox(height: 2),
                                                            Text(
                                                              areaName,
                                                              style: TextStyle(
                                                                fontSize: 12,
                                                                color: AppColors
                                                                    .slate500,
                                                              ),
                                                            ),
                                                          ],
                                                        ),
                                                      ),
                                                      Icon(Icons.chevron_left_rounded, color: AppColors.slate400),
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
                  SizedBox(height: 12),
                  // ── Add Button ─────────────────────────────
                  GestureDetector(
                    onTap: _openAddPanel,
                    child: Container(
                      height: 52,
                      decoration: BoxDecoration(
                        color: AppColors.emerald500,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.add_circle_outline,
                            size: 20,
                            color: Colors.white,
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Thêm bàn mới',
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
                  SizedBox(height: 16),
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
    final store = context.read<ManagementStore>();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text(
          'Sửa khu vực',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        content: SizedBox(
          width: 400,
          child: TextField(
            controller: controller,
            autofocus: true,
            decoration: InputDecoration(
              hintText: 'Nhập tên khu vực mới...',
              filled: true,
              fillColor: AppColors.slate50,
              prefixIcon: Icon(
                Icons.location_on_outlined,
                color: AppColors.emerald500,
                size: 18,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.slate200),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.slate200),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: AppColors.emerald400),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Hủy', style: TextStyle(color: AppColors.slate500)),
          ),
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
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Lưu'),
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
            return _buildTableFormPanel(context.read<ManagementStore>());
          },
        );
      },
    );
  }

  void _closePanel() {
    Navigator.of(context, rootNavigator: true).pop();
  }

  Widget _buildTableFormPanel(ManagementStore store) {
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
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                    ),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: Center(
                        child: Container(
                          constraints: BoxConstraints(maxWidth: 480),
                          margin: EdgeInsets.symmetric(horizontal: 24),
                          padding: EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: AppColors.cardBg,
                            borderRadius: BorderRadius.circular(24),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.12),
                                blurRadius: 40,
                                offset: Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(
                                    Icons.table_restaurant_rounded,
                                    color: AppColors.emerald600,
                                    size: 22,
                                  ),
                                  SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      isEditing ? 'Sửa bàn' : 'Thêm bàn mới',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w800,
                                        color: AppColors.slate800,
                                      ),
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: _closePanel,
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
                              SizedBox(height: 20),
                              if (!_isDefault) ...[
                                Text(
                                  'Khu vực (tùy chọn)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.slate600,
                                  ),
                                ),
                                SizedBox(height: 6),
                                Builder(
                                  builder: (ctx) {
                                    final allTables = store.currentTables;
                                    final existingAreas = <String>{};
                                    for (final t in allTables) {
                                      final parts = _stripDefault(
                                        t,
                                      ).split(' · ');
                                      if (parts.length > 1) {
                                        existingAreas.add(parts[0]);
                                      }
                                    }
                                    final areaList = existingAreas.toList()
                                      ..sort();
                                    final currentAreaText = _areaCtrl.text
                                        .trim();
                                    final isNewArea =
                                        currentAreaText.isNotEmpty &&
                                        !areaList.contains(currentAreaText);

                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Builder(
                                          builder: (ctx) {
                                            final areaFieldKey = GlobalKey();
                                            final displayText =
                                                areaList.contains(
                                                  currentAreaText,
                                                )
                                                ? currentAreaText
                                                : (isNewArea
                                                      ? 'Thêm khu vực mới...'
                                                      : 'Chọn khu vực hoặc thêm mới');
                                            return GestureDetector(
                                              key: areaFieldKey,
                                              onTap: () {
                                                final renderBox =
                                                    areaFieldKey.currentContext
                                                            ?.findRenderObject()
                                                        as RenderBox?;
                                                if (renderBox == null) return;
                                                final position = renderBox
                                                    .localToGlobal(Offset.zero);
                                                final fieldSize =
                                                    renderBox.size;
                                                showMenu<String>(
                                                  context: areaFieldKey
                                                      .currentContext!,
                                                  position:
                                                      RelativeRect.fromLTRB(
                                                        position.dx,
                                                        position.dy +
                                                            fieldSize.height,
                                                        position.dx +
                                                            fieldSize.width,
                                                        0,
                                                      ),
                                                  items: [
                                                    PopupMenuItem<String>(
                                                      value: '',
                                                      child: Text(
                                                        'Mặc định (không có khu vực)',
                                                      ),
                                                    ),
                                                    ...areaList.map(
                                                      (a) =>
                                                          PopupMenuItem<String>(
                                                            value: a,
                                                            child: Text(a),
                                                          ),
                                                    ),
                                                    PopupMenuItem<String>(
                                                      value: 'NEW',
                                                      child: Text(
                                                        '+ Thêm khu vực mới...',
                                                        style: TextStyle(
                                                          color: AppColors
                                                              .emerald600,
                                                        ),
                                                      ),
                                                    ),
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
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: 14,
                                                ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.slate50,
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  border: Border.all(
                                                    color: AppColors.slate200,
                                                  ),
                                                ),
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons
                                                          .location_on_outlined,
                                                      size: 20,
                                                      color: AppColors.slate400,
                                                    ),
                                                    SizedBox(width: 10),
                                                    Expanded(
                                                      child: Text(
                                                        displayText,
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                        ),
                                                      ),
                                                    ),
                                                    Icon(
                                                      Icons.keyboard_arrow_down,
                                                      size: 20,
                                                      color: AppColors.slate400,
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                        if (_newAreaName == 'NEW') ...[
                                          SizedBox(height: 12),
                                          SettingsDialogField(
                                            controller: _newAreaCtrl,
                                            label: 'Tên khu vực mới',
                                          ),
                                        ],
                                      ],
                                    );
                                  },
                                ),
                                SizedBox(height: 16),
                              ],
                              SettingsDialogField(
                                controller: _tableNameCtrl,
                                label: 'Tên bàn/Số bàn (VD: Bàn 01)',
                              ),
                              SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    'Ghim bàn? (Phục vụ liên tục)',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.slate600,
                                    ),
                                  ),
                                  Spacer(),
                                  Switch.adaptive(
                                    value: _isDefault,
                                    onChanged: (v) => _dialogSetState?.call(() {
                                      _isDefault = v;
                                      if (v) {
                                        _areaCtrl.clear();
                                        _newAreaName = '';
                                        _newAreaCtrl.clear();
                                      }
                                    }),
                                    activeTrackColor: AppColors.emerald500,
                                  ),
                                ],
                              ),
                              SizedBox(height: 24),
                              SizedBox(
                                width: double.infinity,
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: () => _saveTable(store),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.emerald500,
                                    foregroundColor: Colors.white,
                                    elevation: 0,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  child: Text(
                                    isEditing ? 'Cập nhật' : 'Thêm bàn',
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
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

  void _saveTable(ManagementStore store) {
    final name = _tableNameCtrl.text.trim();
    if (name.isEmpty) {
      store.showToast('Vui lòng nhập tên bàn', 'error');
      return;
    }

    var area = _newAreaName == 'NEW'
        ? _newAreaCtrl.text.trim()
        : _areaCtrl.text.trim();
    if (_isDefault) {
      area = '';
    }
    final String fullName = (area.isNotEmpty && area != 'Mặc định')
        ? '$area · $name'
        : name;
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
