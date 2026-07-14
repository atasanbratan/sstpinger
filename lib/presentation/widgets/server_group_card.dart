import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// A collapsible group of servers, rendered as a rounded card with a header
/// (leading badge, title over a subtitle, trailing actions) and the rows beneath
/// it. Groups start collapsed.
class ServerGroupCard extends StatelessWidget {
  final Widget leading;
  final String title;
  final String subtitle;
  final bool isExpanded;
  final VoidCallback onToggle;

  /// Header actions (e.g. ping this group), shown to the right of the title.
  final List<Widget> actions;

  /// The rows, shown only while expanded.
  final List<Widget> children;

  const ServerGroupCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.isExpanded,
    required this.onToggle,
    this.actions = const [],
    required this.children,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: AppColors.groupHeader,
              child: InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
                  child: Row(
                    children: [
                      AnimatedRotation(
                        turns: isExpanded ? 0.25 : 0,
                        duration: const Duration(milliseconds: 150),
                        child: const Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: AppColors.textMuted,
                        ),
                      ),
                      const SizedBox(width: 6),
                      leading,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13.5,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 11,
                                color: AppColors.textFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      ...actions,
                    ],
                  ),
                ),
              ),
            ),
            if (isExpanded)
              Column(mainAxisSize: MainAxisSize.min, children: children),
          ],
        ),
      ),
    );
  }
}
