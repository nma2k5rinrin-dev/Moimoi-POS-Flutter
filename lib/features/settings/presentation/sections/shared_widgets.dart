import 'package:flutter/material.dart';
import 'package:moimoi_pos/core/utils/constants.dart';

class SettingsSectionCard extends StatelessWidget {
  final Widget child;
  const SettingsSectionCard({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.cardBg,
        border: Border(
          bottom: BorderSide(color: AppColors.slate200, width: 0.5),
        ),
      ),
      child: child,
    );
  }
}

class SettingsTextField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? hint;
  final bool isPassword;
  final bool showPassword;
  final VoidCallback? onToggle;
  final TextInputType? keyboardType;
  final IconData? prefixIcon;

  const SettingsTextField({
    super.key,
    required this.label,
    required this.controller,
    this.hint,
    this.isPassword = false,
    this.showPassword = false,
    this.onToggle,
    this.keyboardType,
    this.prefixIcon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.slate700,
          ),
        ),
        SizedBox(height: 6),
        TextField(
          controller: controller,
          obscureText: isPassword && !showPassword,
          keyboardType: keyboardType,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            color: AppColors.slate800,
          ),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.slate400),
            filled: true,
            fillColor: AppColors.slate50,
            prefixIcon: prefixIcon != null
                ? Icon(prefixIcon, size: 18, color: AppColors.slate400)
                : null,
            contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            suffixIcon: isPassword && onToggle != null
                ? IconButton(
                    icon: Icon(
                      showPassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      color: AppColors.slate400,
                      size: 20,
                    ),
                    onPressed: onToggle,
                  )
                : null,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.slate200),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.slate200),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary500, width: 2),
            ),
          ),
        ),
      ],
    );
  }
}

class SettingsDialogField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final bool isPassword;
  final TextInputType? keyboardType;

  const SettingsDialogField({
    super.key,
    required this.controller,
    required this.label,
    this.isPassword = false,
    this.keyboardType,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      obscureText: isPassword,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(fontSize: 14),
        filled: true,
        fillColor: AppColors.slate50,
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
          borderSide: BorderSide(color: AppColors.primary400),
        ),
      ),
    );
  }
}
