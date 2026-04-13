import 'package:flutter/material.dart';

class AppColors {
  static bool isDarkMode = false;
  // Primary - Emerald
  static Color primary = const Color(0xFF10B981);
  static Color primaryLight = const Color(0xFFD1FAE5);
  static Color primaryDark = const Color(0xFF065F46);

  // ── Dynamic surface / background colors ──
  static Color scaffoldBg = const Color(0xFFF8FAFC);
  static Color cardBg = Colors.white;
  static Color dialogBg = Colors.white;
  static Color dividerColor = const Color(0xFFE2E8F0);
  static Color inputBg = const Color(0xFFF1F5F9);

  // Slate
  static Color slate50 = const Color(0xFFF8FAFC);
  static Color slate100 = const Color(0xFFF1F5F9);
  static Color slate200 = const Color(0xFFE2E8F0);
  static Color slate300 = const Color(0xFFCBD5E1);
  static Color slate400 = const Color(0xFF94A3B8);
  static Color slate500 = const Color(0xFF64748B);
  static Color slate600 = const Color(0xFF475569);
  static Color slate700 = const Color(0xFF334155);
  static Color slate800 = const Color(0xFF1E293B);
  static Color slate900 = const Color(0xFF0F172A);

  // Red
  static Color red50 = const Color(0xFFFEF2F2);
  static Color red100 = const Color(0xFFFEE2E2);
  static Color red200 = const Color(0xFFFECACA);
  static Color red400 = const Color(0xFFF87171);
  static Color red500 = const Color(0xFFEF4444);
  static Color red600 = const Color(0xFFDC2626);

  // Orange
  static Color orange50 = const Color(0xFFFFF7ED);
  static Color orange100 = const Color(0xFFFFEDD5);
  static Color orange200 = const Color(0xFFFED7AA);
  static Color orange500 = const Color(0xFFF97316);
  static Color orange600 = const Color(0xFFEA580C);

  // Amber
  static Color amber50 = const Color(0xFFFFFBEB);
  static Color amber100 = const Color(0xFFFEF3C7);
  static Color amber200 = const Color(0xFFFDE68A);
  static Color amber400 = const Color(0xFFFBBF24);
  static Color amber500 = const Color(0xFFF59E0B);
  static Color amber600 = const Color(0xFFD97706);

  // Blue
  static Color blue50 = const Color(0xFFEFF6FF);
  static Color blue100 = const Color(0xFFDBEAFE);
  static Color blue200 = const Color(0xFFBFDBFE);
  static Color blue400 = const Color(0xFF60A5FA);
  static Color blue500 = const Color(0xFF3B82F6);
  static Color blue600 = const Color(0xFF2563EB);

  // Violet/Purple
  static Color violet50 = const Color(0xFFF5F3FF);
  static Color violet100 = const Color(0xFFEDE9FE);
  static Color violet200 = const Color(0xFFDDD6FE);
  static Color violet500 = const Color(0xFF8B5CF6);
  static Color violet600 = const Color(0xFF7C3AED);
  static Color violet700 = const Color(0xFF6D28D9);

  // Emerald
  static Color emerald50 = const Color(0xFFECFDF5);
  static Color emerald100 = const Color(0xFFD1FAE5);
  static Color emerald200 = const Color(0xFFA7F3D0);
  static Color emerald400 = const Color(0xFF34D399);
  static Color emerald500 = const Color(0xFF10B981);
  static Color emerald600 = const Color(0xFF059669);
  static Color emerald700 = const Color(0xFF047857);
  static Color emerald800 = const Color(0xFF065F46);

  static void switchTheme(bool isDark) {
    isDarkMode = isDark;
    if (isDark) {
      // ────── DARK MODE (Facebook-style neutral gray) ──────
      scaffoldBg = const Color(0xFF18191A);
      cardBg = const Color(0xFF242526);
      dialogBg = const Color(0xFF242526);
      dividerColor = const Color(0xFF3E4042);
      inputBg = const Color(0xFF3A3B3C);

      // Slate: neutral gray scale for FB dark
      slate50 = const Color(0xFF18191A); // darkest (bg level)
      slate100 = const Color(0xFF242526); // card level
      slate200 = const Color(0xFF3A3B3C); // subtle border
      slate300 = const Color(0xFF4E4F50); // muted border
      slate400 = const Color(0xFF8A8D91); // placeholder text
      slate500 = const Color(0xFFB0B3B8); // secondary text
      slate600 = const Color(0xFFD2D5DA); // body text
      slate700 = const Color(0xFFE4E6EB); // label text
      slate800 = const Color(0xFFE4E6EB); // heading/title
      slate900 = const Color(0xFFFFFFFF); // strongest text

      // Accent tints: subtle tinted backgrounds
      red50 = const Color(0xFF2D1215);
      red100 = const Color(0xFF3D181B);
      emerald50 = const Color(0xFF1A2E22);
      emerald100 = const Color(0xFF1F3A29);
      blue50 = const Color(0xFF1A2332);
      blue100 = const Color(0xFF1F2B3D);
      amber50 = const Color(0xFF2D2714);
      amber100 = const Color(0xFF3A3119);
      orange50 = const Color(0xFF2D2214);
      orange100 = const Color(0xFF3A2C19);
      violet50 = const Color(0xFF221A2D);
      violet100 = const Color(0xFF2B223A);
    } else {
      // ────── LIGHT MODE (defaults) ──────
      scaffoldBg = const Color(0xFFF8FAFC);
      cardBg = Colors.white;
      dialogBg = Colors.white;
      dividerColor = const Color(0xFFE2E8F0);
      inputBg = const Color(0xFFF1F5F9);

      slate50 = const Color(0xFFF8FAFC);
      slate100 = const Color(0xFFF1F5F9);
      slate200 = const Color(0xFFE2E8F0);
      slate300 = const Color(0xFFCBD5E1);
      slate400 = const Color(0xFF94A3B8);
      slate500 = const Color(0xFF64748B);
      slate600 = const Color(0xFF475569);
      slate700 = const Color(0xFF334155);
      slate800 = const Color(0xFF1E293B);
      slate900 = const Color(0xFF0F172A);

      red50 = const Color(0xFFFEF2F2);
      red100 = const Color(0xFFFEE2E2);
      emerald50 = const Color(0xFFECFDF5);
      emerald100 = const Color(0xFFD1FAE5);
      blue50 = const Color(0xFFEFF6FF);
      blue100 = const Color(0xFFDBEAFE);
      amber50 = const Color(0xFFFFFBEB);
      amber100 = const Color(0xFFFEF3C7);
      orange50 = const Color(0xFFFFF7ED);
      orange100 = const Color(0xFFFFEDD5);
      violet50 = const Color(0xFFF5F3FF);
      violet100 = const Color(0xFFEDE9FE);
    }

    AppTextStyles.update();
  }

  /// Helper: create tinted background from accent color (15% opacity on cardBg)
  static Color tintedBg(Color accentColor) {
    return Color.alphaBlend(accentColor.withValues(alpha: 0.15), cardBg);
  }
}

class AppTextStyles {
  static TextStyle heading1 = TextStyle(
    fontSize: 28,
    fontWeight: FontWeight.w800,
    color: AppColors.slate800,
  );
  static TextStyle heading2 = TextStyle(
    fontSize: 22,
    fontWeight: FontWeight.w700,
    color: AppColors.slate800,
  );
  static TextStyle heading3 = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    color: AppColors.slate800,
  );
  static TextStyle body = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    color: AppColors.slate600,
  );
  static TextStyle bodySmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: AppColors.slate500,
  );
  static TextStyle label = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.slate700,
  );
  static TextStyle price = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w700,
    color: AppColors.emerald500,
  );

  static void update() {
    heading1 = TextStyle(
      fontSize: 28,
      fontWeight: FontWeight.w800,
      color: AppColors.slate800,
    );
    heading2 = TextStyle(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: AppColors.slate800,
    );
    heading3 = TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.w700,
      color: AppColors.slate800,
    );
    body = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: AppColors.slate600,
    );
    bodySmall = TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: AppColors.slate500,
    );
    label = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.slate700,
    );
    price = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: AppColors.emerald500,
    );
  }
}
