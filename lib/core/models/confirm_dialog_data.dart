import 'package:flutter/material.dart';

class ConfirmDialogData {
  final String title;
  final String message;
  final VoidCallback onConfirm;
  final VoidCallback? onCancel;
  
  // Extended fields for rich UI
  final String? description;
  final String? confirmLabel;
  final IconData? icon;
  final String? itemName;
  final String? itemSubtitle;
  final Color? avatarColor;
  final String? avatarInitials;

  ConfirmDialogData({
    required this.title,
    required this.message,
    required this.onConfirm,
    this.onCancel,
    this.description,
    this.confirmLabel,
    this.icon,
    this.itemName,
    this.itemSubtitle,
    this.avatarColor,
    this.avatarInitials,
  });
}
