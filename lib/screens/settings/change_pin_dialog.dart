import 'dart:math' show sin, pi;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../store/app_store.dart';
import '../../utils/constants.dart';

/// 3-step PIN change dialog matching the .pen design:
///   Step 1: Verify current PIN
///   Step 2: Enter new PIN
///   Step 3: Confirm new PIN
/// Auto-focuses numeric keyboard and auto-submits when 4 digits entered.
class ChangePinDialog extends StatefulWidget {
  /// If true, this is a "set new PIN" flow (skip step 1).
  final bool isFirstTimeSetup;

  const ChangePinDialog({super.key, this.isFirstTimeSetup = false});

  @override
  State<ChangePinDialog> createState() => _ChangePinDialogState();
}

class _ChangePinDialogState extends State<ChangePinDialog>
    with SingleTickerProviderStateMixin {
  late int _step; // 1, 2, or 3
  String _currentInput = '';
  String _newPin = '';
  String? _error;
  bool _success = false;

  late AnimationController _shakeController;
  late Animation<double> _shakeAnimation;

  // 4 focus nodes for visual feedback (but we use a hidden TextField)
  final _hiddenFocusNode = FocusNode();
  final _hiddenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _step = widget.isFirstTimeSetup ? 2 : 1;

    _shakeController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    _shakeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _shakeController, curve: Curves.easeOut),
    );

    // Auto-focus after build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _hiddenFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _shakeController.dispose();
    _hiddenFocusNode.dispose();
    _hiddenController.dispose();
    super.dispose();
  }

  int get _totalSteps => widget.isFirstTimeSetup ? 2 : 3;
  int get _displayStep =>
      widget.isFirstTimeSetup ? (_step - 1) : _step;

  String get _stepTitle {
    switch (_step) {
      case 1:
        return 'Xác thực mã PIN';
      case 2:
        return 'Đặt mã PIN mới';
      case 3:
        return 'Xác nhận mã PIN';
      default:
        return '';
    }
  }

  String get _stepSubtitle {
    switch (_step) {
      case 1:
        return 'Nhập mã PIN hiện tại để xác minh';
      case 2:
        return 'Nhập mã PIN mới 4 số';
      case 3:
        return 'Nhập lại mã PIN mới để xác nhận';
      default:
        return '';
    }
  }

  String get _inputLabel {
    switch (_step) {
      case 1:
        return 'Nhập mã PIN hiện tại';
      case 2:
        return 'Nhập mã PIN mới';
      case 3:
        return 'Xác nhận lại mã PIN mới';
      default:
        return '';
    }
  }

  void _onInputChanged(String value) {
    // Only allow digits, max 4
    final filtered = value.replaceAll(RegExp(r'[^0-9]'), '');
    if (filtered.length > 4) return;

    setState(() {
      _currentInput = filtered;
      _error = null;
    });

    // Auto-submit when 4 digits
    if (filtered.length == 4) {
      Future.delayed(const Duration(milliseconds: 200), () {
        _handleSubmit();
      });
    }
  }

  void _handleSubmit() {
    if (_currentInput.length != 4) return;

    final store = context.read<AppStore>();
    final currentPin = store.currentUser?.pin;

    switch (_step) {
      case 1: // Verify current PIN
        if (_currentInput != currentPin) {
          _triggerError('Mã PIN không đúng');
          return;
        }
        _goToNextStep();
        break;

      case 2: // Enter new PIN
        _newPin = _currentInput;
        _goToNextStep();
        break;

      case 3: // Confirm new PIN
        if (_currentInput != _newPin) {
          _triggerError('Mã PIN không khớp, vui lòng nhập lại');
          return;
        }
        _savePin();
        break;
    }
  }

  void _goToNextStep() {
    setState(() {
      _step++;
      _currentInput = '';
      _error = null;
    });
    _hiddenController.clear();
    _hiddenFocusNode.requestFocus();
  }

  void _goToPreviousStep() {
    setState(() {
      _step--;
      _currentInput = '';
      _error = null;
      if (_step == 2) _newPin = '';
    });
    _hiddenController.clear();
    _hiddenFocusNode.requestFocus();
  }

  bool get _canGoBack {
    if (widget.isFirstTimeSetup) return _step > 2;
    return _step > 1;
  }

  void _triggerError(String message) {
    setState(() {
      _error = message;
      _currentInput = '';
    });
    _hiddenController.clear();
    _shakeController.forward(from: 0);
    HapticFeedback.heavyImpact();
    _hiddenFocusNode.requestFocus();
  }

  Future<void> _savePin() async {
    final store = context.read<AppStore>();
    await store.updateUser(store.currentUser!.username, {'pin': _newPin});
    if (!mounted) return;
    setState(() {
      _success = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: _success ? _buildSuccess() : _buildPinEntry(),
    );
  }

  Widget _buildPinEntry() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Step badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.emerald50,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Bước $_displayStep/$_totalSteps',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.emerald600,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // PIN icon
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.emerald50,
              borderRadius: BorderRadius.circular(32),
            ),
            child: const Icon(
              Icons.pin_outlined,
              size: 32,
              color: AppColors.emerald500,
            ),
          ),
          const SizedBox(height: 20),

          // Title
          Text(
            _stepTitle,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.slate800,
            ),
          ),
          const SizedBox(height: 6),

          // Subtitle
          Text(
            _stepSubtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.slate400,
            ),
          ),
          const SizedBox(height: 24),

          // Input label
          Text(
            _inputLabel,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.slate600,
            ),
          ),
          const SizedBox(height: 12),

          // PIN boxes
          AnimatedBuilder(
            animation: _shakeAnimation,
            builder: (context, child) {
              final offset = sin(_shakeAnimation.value * pi * 4) * 8 * (1 - _shakeAnimation.value);
              return Transform.translate(
                offset: Offset(offset, 0),
                child: child,
              );
            },
            child: GestureDetector(
              onTap: () => _hiddenFocusNode.requestFocus(),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (index) {
                  final hasValue = index < _currentInput.length;
                  final isActive = index == _currentInput.length && index < 4;
                  final hasError = _error != null;

                  return Container(
                    width: 52,
                    height: 56,
                    margin: EdgeInsets.only(left: index > 0 ? 16 : 0),
                    decoration: BoxDecoration(
                      color: hasError
                          ? AppColors.red50
                          : isActive
                              ? Colors.white
                              : hasValue
                                  ? Colors.white
                                  : AppColors.slate50,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: hasError
                            ? AppColors.red400
                            : isActive
                                ? AppColors.emerald500
                                : hasValue
                                    ? AppColors.emerald500
                                    : AppColors.slate200,
                        width: hasError || isActive || hasValue ? 2 : 1.5,
                      ),
                    ),
                    child: Center(
                      child: hasValue
                          ? Text(
                              '•',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w700,
                                color: hasError
                                    ? AppColors.red500
                                    : AppColors.slate800,
                              ),
                            )
                          : isActive
                              ? _buildCursor()
                              : null,
                    ),
                  );
                }),
              ),
            ),
          ),

          // Hidden text field for keyboard input
          SizedBox(
            height: 0,
            child: Opacity(
              opacity: 0,
              child: TextField(
                focusNode: _hiddenFocusNode,
                controller: _hiddenController,
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(4),
                ],
                onChanged: _onInputChanged,
                autofocus: true,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Progress dots
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(4, (index) {
              return Container(
                width: 8,
                height: 8,
                margin: EdgeInsets.only(left: index > 0 ? 8 : 0),
                decoration: BoxDecoration(
                  color: index < _currentInput.length
                      ? AppColors.emerald500
                      : AppColors.slate200,
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),

          // Error message
          if (_error != null) ...[
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 14, color: AppColors.red500),
                const SizedBox(width: 4),
                Text(
                  _error!,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: AppColors.red500,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 24),

          // Buttons: Back (if applicable) + Cancel
          Row(
            children: [
              if (_canGoBack) ...[
                Expanded(
                  child: InkWell(
                    onTap: _goToPreviousStep,
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.slate200),
                      ),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.slate500),
                          SizedBox(width: 6),
                          Text(
                            'Quay lại',
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.slate500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: InkWell(
                  onTap: () => Navigator.of(context).pop(),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.red200),
                      color: AppColors.red50,
                    ),
                    child: const Center(
                      child: Text(
                        'Huỷ',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.red500,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCursor() {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 500),
      builder: (context, value, child) {
        return AnimatedOpacity(
          opacity: (DateTime.now().millisecondsSinceEpoch ~/ 530) % 2 == 0
              ? 1.0
              : 0.0,
          duration: const Duration(milliseconds: 100),
          child: Container(
            width: 2,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.emerald500,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSuccess() {
    return Container(
      constraints: const BoxConstraints(maxWidth: 380),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 40,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Success icon
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.emerald50,
              borderRadius: BorderRadius.circular(40),
            ),
            child: const Icon(
              Icons.check_circle,
              size: 48,
              color: AppColors.emerald500,
            ),
          ),
          const SizedBox(height: 24),

          const Text(
            'Đổi mã PIN thành công!',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.slate800,
            ),
          ),
          const SizedBox(height: 8),

          const Text(
            'Mã PIN của bạn đã được cập nhật.\nSử dụng mã PIN mới cho lần\nđăng nhập tiếp theo.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
              color: AppColors.slate400,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),

          // Confirm button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton.icon(
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.check, size: 20),
              label: const Text(
                'Xác nhận',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald500,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shows the Change PIN dialog.
/// Returns `true` if PIN was successfully changed.
Future<bool?> showChangePinDialog(
  BuildContext context, {
  bool isFirstTimeSetup = false,
}) {
  return showGeneralDialog<bool>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Change PIN',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: const Duration(milliseconds: 300),
    pageBuilder: (context, animation, secondaryAnimation) {
      return ChangePinDialog(isFirstTimeSetup: isFirstTimeSetup);
    },
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      return ScaleTransition(
        scale: CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutBack,
        ),
        child: FadeTransition(
          opacity: animation,
          child: child,
        ),
      );
    },
  );
}
