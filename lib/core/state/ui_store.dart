import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:moimoi_pos/core/models/confirm_dialog_data.dart';
import 'package:moimoi_pos/core/utils/constants.dart';
import 'package:moimoi_pos/core/services/background_service.dart';

/// Standalone UIStore — manages theme, toast, confirm dialog, search/category
/// selection, and sadmin view. Replaces the old UIStore mixin.
class UIStore extends ChangeNotifier {
  BuildContext? rootContext;

  // ── Global App Visual State ───────────────────────────────
  bool isDarkMode = false;
  AppTheme activeTheme = AppTheme.emerald;
  bool isBackgroundServiceEnabled = true;

  // ── Toast State ───────────────────────────────────────────
  String? toastMessage;
  String toastType = 'success'; // 'success', 'error', 'info', 'warning'

  // ── Modal & Dialog State ────────────────────────────────
  bool isUpgradeModalOpen = false;
  ConfirmDialogData? confirmDialog;

  // ── Navigation & Selection State ────────────────────────
  String selectedCategory = 'all';
  String searchQuery = '';

  Timer? searchDebounce;

  // ── Scroll to Top Stream ──────────────────────────────────
  final StreamController<String> _scrollToTopController =
      StreamController<String>.broadcast();
  Stream<String> get scrollToTopStream => _scrollToTopController.stream;

  void triggerScrollToTop(String path) {
    _scrollToTopController.add(path);
  }

  void clearUIState() {
    toastMessage = null;
    toastType = 'success';
    isUpgradeModalOpen = false;
    confirmDialog = null;
    selectedCategory = 'all';
    searchQuery = '';
    searchDebounce?.cancel();
  }

  // ── Theme Management ────────────────────────────────────
  Future<void> initTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      isDarkMode = prefs.getBool('isDarkMode') ?? false;
      isBackgroundServiceEnabled = prefs.getBool('isBackgroundEnabled') ?? true;
      
      final themeIndex = prefs.getInt('activeTheme') ?? AppTheme.emerald.index;
      activeTheme = AppTheme.values[themeIndex];
      
      AppColors.switchTheme(isDarkMode);
      AppColors.switchColorTheme(activeTheme);
      notifyListeners();
    } catch (e) {
      debugPrint('[Theme] Error loading theme: $e');
    }
  }

  Future<void> toggleTheme() async {
    isDarkMode = !isDarkMode;
    AppColors.switchTheme(isDarkMode);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isDarkMode', isDarkMode);
    } catch (e) {
      debugPrint('[Theme] Error saving theme: $e');
    }
  }

  Future<void> changeColorTheme(AppTheme newTheme) async {
    activeTheme = newTheme;
    AppColors.switchColorTheme(activeTheme);
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('activeTheme', activeTheme.index);
    } catch (e) {
      debugPrint('[Theme] Error saving color theme: $e');
    }
  }

  Future<void> toggleBackgroundService(bool val, {String? storeId}) async {
    isBackgroundServiceEnabled = val;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isBackgroundEnabled', val);
    
    if (val) {
      BackgroundServiceHelper.startService(storeId);
    } else {
      BackgroundServiceHelper.stopService();
    }
    notifyListeners();
  }

  // ── Toast Functions ─────────────────────────────────────
  void showToast(String message, [String type = 'success']) {
    toastMessage = message;
    toastType = type;
    notifyListeners();

    // Clear toast after 1.8 seconds if it hasn't changed
    Future.delayed(const Duration(milliseconds: 1800), () {
      if (toastMessage == message) {
        toastMessage = null;
        notifyListeners();
      }
    });
  }

  // ── Dialog Functions ────────────────────────────────────
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
    VoidCallback? onCancel,
    String? title,
    String? description,
    String? itemName,
    String? itemSubtitle,
    IconData? icon,
    String? avatarInitials,
    Color? avatarColor,
    String? confirmLabel,
  }) {
    showConfirmDialog(
      ConfirmDialogData(
        title: title ?? 'Xác nhận?',
        message: message,
        onConfirm: onConfirm,
        onCancel: onCancel,
        description: description,
        itemName: itemName,
        itemSubtitle: itemSubtitle,
        icon: icon,
        avatarInitials: avatarInitials,
        avatarColor: avatarColor,
        confirmLabel: confirmLabel,
      ),
    );
  }

  void closeConfirm() {
    confirmDialog = null;
    notifyListeners();
  }

  // ── Selection Functions ─────────────────────────────────
  void setCategory(String category) {
    selectedCategory = category;
    searchQuery = '';
    searchDebounce?.cancel();
    notifyListeners();
  }

  void setSearchQuery(String query) {
    searchQuery = query;
    if (query.isNotEmpty && selectedCategory != 'all') {
      selectedCategory = 'all';
    }
    searchDebounce?.cancel();
    searchDebounce = Timer(const Duration(milliseconds: 200), () {
      notifyListeners();
    });
  }

  @override
  void dispose() {
    searchDebounce?.cancel();
    _scrollToTopController.close();
    super.dispose();
  }
}
