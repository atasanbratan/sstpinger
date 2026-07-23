import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// A single settings list row: leading icon, title (+ optional subtitle),
/// and a trailing value/switch/chevron. Replaces the icon+title+trailing
/// `Row` that used to be hand-rolled in every settings card.
class SettingsRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? trailingText;
  final Color? trailingTextColor;
  final bool? switchValue;
  final ValueChanged<bool>? onSwitchChanged;
  final bool showChevron;
  final VoidCallback? onTap;

  const SettingsRow({
    super.key,
    required this.icon,
    this.iconColor = AppColors.accent,
    required this.title,
    this.subtitle,
    this.trailingText,
    this.trailingTextColor,
    this.switchValue,
    this.onSwitchChanged,
    this.showChevron = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        child: Row(
          children: [
            Icon(icon, color: iconColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textFaint,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingText != null) ...[
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 140),
                child: Text(
                  trailingText!,
                  textAlign: TextAlign.right,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: trailingTextColor ?? AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            if (switchValue != null)
              Switch(
                value: switchValue!,
                activeThumbColor: AppColors.accent,
                onChanged: onSwitchChanged,
              ),
            if (showChevron)
              const Icon(Icons.chevron_right_rounded, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }
}
