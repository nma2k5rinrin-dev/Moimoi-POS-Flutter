import 'package:flutter/material.dart';
import 'package:moimoi_pos/core/state/base_mixin.dart';
import 'package:moimoi_pos/core/models/confirm_dialog_data.dart';

mixin UIStore on ChangeNotifier, BaseMixin {
  bool isUpgradeModalOpen = false;
  ConfirmDialogData? confirmDialog;

  // POS Order state
  String selectedCategory = '';
  String searchQuery = '';

  void setUpgradeModalOpen(bool open) {
    isUpgradeModalOpen = open;
    notifyListeners();
  }

  void showConfirmDialog(ConfirmDialogData data) {
    confirmDialog = data;
    notifyListeners();
  }

  void showConfirm(
    String message,
    VoidCallback onConfirm, {
    String? title,
    String? description,
    String? itemName,
    String? itemSubtitle,
    IconData? icon,
    String? avatarInitials,
    Color? avatarColor,
    String? confirmLabel,
  }) {
    showConfirmDialog(ConfirmDialogData(
      title: title ?? 'Xác nhận?',
      message: message,
      onConfirm: onConfirm,
      description: description,
      itemName: itemName,
      itemSubtitle: itemSubtitle,
      icon: icon,
      avatarInitials: avatarInitials,
      avatarColor: avatarColor,
      confirmLabel: confirmLabel,
    ));
  }

  void closeConfirm() {
    confirmDialog = null;
    notifyListeners();
  }

  void setSelectedCategory(String category) {
    selectedCategory = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    notifyListeners();
  }
}
