import 'package:flutter/material.dart';

/// Base mixin for common Store helpers.
mixin BaseMixin on ChangeNotifier {
  bool isLoading = false;
  String? toastMessage;
  String toastType = 'success';

  void showToast(String message, [String type = 'success']) {
    toastMessage = message;
    toastType = type;
    notifyListeners();
    // Auto-clear toast after 3 seconds
    Future.delayed(const Duration(seconds: 3), () {
      if (toastMessage == message) {
        toastMessage = null;
        notifyListeners();
      }
    });
  }

  /// Optimistic UI Helper
  void optimistic({
    required VoidCallback apply,
    required Future<void> Function() remote,
    required VoidCallback rollback,
    String errorMsg = 'Có lỗi xảy ra, đã hoàn tác',
  }) {
    apply();
    notifyListeners();
    remote().catchError((e) {
      debugPrint('[Optimistic rollback] $e');
      rollback();
      notifyListeners();
      showToast(errorMsg, 'error');
    });
  }

  void setLoading(bool value) {
    isLoading = value;
    notifyListeners();
  }
}
