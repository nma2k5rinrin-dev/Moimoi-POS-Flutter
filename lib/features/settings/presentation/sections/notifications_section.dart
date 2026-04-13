import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import 'package:moimoi_pos/core/state/app_store.dart';
import 'package:moimoi_pos/core/state/audio_store_standalone.dart' as standalone_audio;
import 'package:moimoi_pos/core/utils/constants.dart';

class NotificationsSection extends StatefulWidget {
  final VoidCallback? onCancel;
  const NotificationsSection({super.key, this.onCancel});

  @override
  State<NotificationsSection> createState() => _NotificationsSectionState();
}

class _NotificationsSectionState extends State<NotificationsSection> {
  int _selectedTab = 0; // 0 for New Order, 1 for Payment
  String? _selectedNotificationSound;
  String? _selectedPaymentSound;

  // Custom device sounds picked by the user
  String? _customNotifName;
  String? _customPaymentName;

  final List<Map<String, String>> _sounds = [
    {'name': 'Chuông bàn lễ tân', 'path': 'sounds/bell.wav'},
    {'name': 'Tiếng Ding', 'path': 'sounds/ding-sound-effect_2.mp3'},
    {'name': 'Tiếng Tiền Giao dịch', 'path': 'sounds/buy_1.mp3'},
    {
      'name': 'Tiếng Chọn (Check Mark)',
      'path': 'sounds/check-mark_oPG7Xo5.mp3',
    },
    {'name': 'Tiếng Chuông Quyền Anh', 'path': 'sounds/boxing-bell.mp3'},
    {'name': 'Tiếng Boom (Vine)', 'path': 'sounds/vine-boom.mp3'},
    {'name': 'Tiếng Bonk', 'path': 'sounds/bonk_7zPAD7C.mp3'},
    {'name': 'Tiếng Vịt kêu (Quack)', 'path': 'sounds/mac-quack.mp3'},
    {'name': 'Tiếng Pop Bong bóng', 'path': 'sounds/pop_7e9Is8L.mp3'},
    {
      'name': 'Tiếng Hài (Pop nổ)',
      'path': 'sounds/comedy_pop_finger_in_mouth_001.mp3',
    },
    {'name': 'Tiếng Tát', 'path': 'sounds/slap-ahh.mp3'},
    {
      'name': 'Tiếng Đấm (Gaming)',
      'path': 'sounds/punch-gaming-sound-effect-hd_RzlG1GE.mp3',
    },
    {'name': 'Tiếng Đấm', 'path': 'sounds/punch_u4LmMsr.mp3'},
    {'name': 'Tiếng Uh', 'path': 'sounds/uh_pjRnSML.mp3'},
    {'name': 'Im lặng (Không phát âm)', 'path': 'mute'},
  ];

  @override
  void initState() {
    super.initState();
    // Load existing custom sound names from audio store
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadCustomSoundNames();
    });
  }

  void _loadCustomSoundNames() {
    final audioStore = context.read<standalone_audio.AudioStore>();
    final notifSound = audioStore.notificationSound;
    final paySound = audioStore.paymentSound;

    if (notifSound.startsWith('device:')) {
      setState(() {
        _customNotifName = _extractFileName(notifSound.substring(7));
      });
    }
    if (paySound.startsWith('device:')) {
      setState(() {
        _customPaymentName = _extractFileName(paySound.substring(7));
      });
    }
  }

  String _extractFileName(String path) {
    final parts = path.split(RegExp(r'[/\\]'));
    return parts.isNotEmpty ? parts.last : path;
  }

  Future<void> _pickCustomSound() async {
    try {
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['mp3', 'wav', 'ogg', 'm4a', 'aac'],
        dialogTitle: 'Chọn file âm thanh',
      );

      if (result != null && result.files.single.path != null) {
        final filePath = result.files.single.path!;
        final fileName = result.files.single.name;
        final devicePath = 'device:$filePath';

        setState(() {
          if (_selectedTab == 0) {
            _selectedNotificationSound = devicePath;
            _customNotifName = fileName;
          } else {
            _selectedPaymentSound = devicePath;
            _customPaymentName = fileName;
          }
        });

        // Preview the picked sound
        final audioStore = context.read<standalone_audio.AudioStore>();
        audioStore.previewNotificationSound(devicePath);
      }
    } catch (e) {
      debugPrint('[NotificationsSection] pickCustomSound error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final audioStore = context.watch<standalone_audio.AudioStore>();

    final currentNotifSound =
        _selectedNotificationSound ?? audioStore.notificationSound;
    final currentPaySound = _selectedPaymentSound ?? audioStore.paymentSound;

    final currentSound = _selectedTab == 0
        ? currentNotifSound
        : currentPaySound;
    final hasChanges =
        (_selectedNotificationSound != null &&
            _selectedNotificationSound != audioStore.notificationSound) ||
        (_selectedPaymentSound != null &&
            _selectedPaymentSound != audioStore.paymentSound);

    // Check if current sound is a custom device file (not in asset list)
    final isCustomDeviceSound = currentSound.startsWith('device:');
    final customName = _selectedTab == 0 ? _customNotifName : _customPaymentName;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 9),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 12),
                  // Tabs
                  Container(
                    height: 48,
                    padding: EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AppColors.slate200,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _buildTabBtn(
                            0,
                            'Đơn mới',
                            Icons.notifications_active_rounded,
                          ),
                        ),
                        Expanded(
                          child: _buildTabBtn(
                            1,
                            'Nhận tiền',
                            Icons.payments_rounded,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 16),
                  Container(
                    padding: EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.cardBg,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.slate200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _selectedTab == 0
                              ? 'Âm thanh thông báo đơn mới'
                              : 'Âm thanh thông báo nhận tiền',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppColors.slate800,
                          ),
                        ),
                        SizedBox(height: 6),
                        Text(
                          _selectedTab == 0
                              ? 'Hệ thống sẽ phát âm báo này ngay khi nhận được đơn đặt món mới.'
                              : 'Hệ thống sẽ phát âm báo này khi khách hàng thanh toán thành công.',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.slate500,
                          ),
                        ),
                        SizedBox(height: 16),

                        // === Custom device sound (show at top if selected) ===
                        if (isCustomDeviceSound && customName != null) ...[
                          _buildCustomSoundItem(
                            name: customName,
                            isSelected: true,
                            onTap: () {
                              audioStore.previewNotificationSound(currentSound);
                            },
                          ),
                          SizedBox(height: 12),
                          Divider(color: AppColors.slate200, height: 1),
                          SizedBox(height: 12),
                        ],

                        // === Preset sound list ===
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _sounds.length,
                          separatorBuilder: (context, index) => SizedBox(height: 8),
                          itemBuilder: (context, index) {
                            final s = _sounds[index];
                            final isSelected = currentSound == s['path'];
                            return GestureDetector(
                              onTap: () {
                                setState(() {
                                  if (_selectedTab == 0) {
                                    _selectedNotificationSound = s['path']!;
                                    // Clear custom name when switching to preset
                                    if (!s['path']!.startsWith('device:')) {
                                      _customNotifName = null;
                                    }
                                  } else {
                                    _selectedPaymentSound = s['path']!;
                                    if (!s['path']!.startsWith('device:')) {
                                      _customPaymentName = null;
                                    }
                                  }
                                });
                                audioStore.previewNotificationSound(s['path']!);
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.emerald50
                                      : AppColors.slate50,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.emerald200
                                        : Colors.transparent,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      s['path'] == 'mute'
                                          ? Icons.volume_off_rounded
                                          : (_selectedTab == 0
                                                ? Icons
                                                      .notifications_active_rounded
                                                : Icons.payments_rounded),
                                      size: 20,
                                      color: isSelected
                                          ? AppColors.emerald600
                                          : AppColors.slate400,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        s['name']!,
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: isSelected
                                              ? FontWeight.w600
                                              : FontWeight.w500,
                                          color: isSelected
                                              ? AppColors.emerald700
                                              : AppColors.slate700,
                                        ),
                                      ),
                                    ),
                                    if (isSelected)
                                      Icon(
                                        Icons.check_circle_rounded,
                                        size: 20,
                                        color: AppColors.emerald500,
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),

                        // === Pick from device button ===
                        if (!kIsWeb) ...[
                          SizedBox(height: 12),
                          GestureDetector(
                            onTap: _pickCustomSound,
                            child: Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.slate50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.slate200,
                                  style: BorderStyle.solid,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: AppColors.amber100,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.folder_open_rounded,
                                      size: 18,
                                      color: AppColors.amber600,
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text(
                                    'Chọn từ thiết bị',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.slate700,
                                    ),
                                  ),
                                  Spacer(),
                                  Text(
                                    '.mp3 .wav .ogg .m4a',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                      color: AppColors.slate400,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
        if (widget.onCancel != null) _buildBottomActions(store, audioStore, hasChanges),
      ],
    );
  }

  Widget _buildCustomSoundItem({
    required String name,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.amber50 : AppColors.slate50,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.amber200 : Colors.transparent,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.amber100
                    : AppColors.slate200,
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(
                Icons.audio_file_rounded,
                size: 16,
                color: isSelected
                    ? AppColors.amber600
                    : AppColors.slate400,
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: isSelected
                          ? AppColors.amber600
                          : AppColors.slate700,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Âm thanh từ thiết bị',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.slate400,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(
                Icons.check_circle_rounded,
                size: 20,
                color: AppColors.amber500,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomActions(AppStore store, standalone_audio.AudioStore audioStore, bool hasChanges) {
    return Padding(
      padding: EdgeInsets.fromLTRB(9, 8, 9, 16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 600),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                onTap: widget.onCancel,
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
                        Icons.arrow_back_rounded,
                        size: 18,
                        color: AppColors.slate500,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Quay lại',
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
                onTap: hasChanges
                    ? () {
                        if (_selectedNotificationSound != null) {
                          audioStore.setNotificationSound(
                            _selectedNotificationSound!,
                          );
                        }
                        if (_selectedPaymentSound != null) {
                          audioStore.setPaymentSound(_selectedPaymentSound!);
                        }
                        store.showToast('Đã lưu thiết lập âm thanh thành công');
                        setState(() {
                          _selectedNotificationSound = null;
                          _selectedPaymentSound = null;
                        });
                        if (widget.onCancel != null) {
                          widget.onCancel!();
                        } else {
                          if (Navigator.canPop(context)) Navigator.pop(context);
                        }
                      }
                    : null,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 52,
                  decoration: BoxDecoration(
                    color: hasChanges
                        ? AppColors.emerald500
                        : AppColors.slate100,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.check_circle_rounded,
                        size: 18,
                        color: hasChanges ? Colors.white : AppColors.slate400,
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Lưu thay đổi',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: hasChanges ? Colors.white : AppColors.slate400,
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

  Widget _buildTabBtn(int index, String label, IconData icon) {
    bool isSelected = _selectedTab == index;
    return GestureDetector(
      onTap: () => setState(() => _selectedTab = index),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.cardBg : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? AppColors.emerald600 : AppColors.slate500,
            ),
            SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
                color: isSelected ? AppColors.emerald700 : AppColors.slate500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
