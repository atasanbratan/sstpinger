import 'package:flutter/material.dart';

import '../../core/utils/country_flag.dart';
import '../../domain/entities/vpn_server.dart';
import '../theme/app_colors.dart';

/// One server in the list: circular flag, name over a subtitle, latency, and a
/// chevron. The selected row is marked by a left accent bar and a tinted
/// background.
class ServerRow extends StatelessWidget {
  final VpnServer server;
  final bool isSelected;
  final bool isBookmarked;
  final VoidCallback onTap;
  final VoidCallback onBookmarkToggle;

  const ServerRow({
    super.key,
    required this.server,
    required this.isSelected,
    required this.isBookmarked,
    required this.onTap,
    required this.onBookmarkToggle,
  });

  /// Latency bucket colour: fast (<80ms), medium (<150ms), slow otherwise.
  static Color _pingColor(int ping) {
    if (ping < 80) return AppColors.pingGood;
    if (ping < 150) return AppColors.pingMedium;
    return AppColors.pingBad;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: isSelected ? AppColors.rowSelected : AppColors.row,
            border: Border(
              left: BorderSide(
                color: isSelected ? AppColors.accent : Colors.transparent,
                width: 3,
              ),
            ),
          ),
          padding: const EdgeInsets.fromLTRB(13, 10, 8, 10),
          child: Row(
            children: [
              // Circular flag badge.
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.surfaceDeep,
                ),
                child: Text(
                  countryFlagEmoji(server.countryShort),
                  style: const TextStyle(fontSize: 18),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      server.country.toUpperCase(),
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
                      server.hostname,
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
              const SizedBox(width: 8),
              Text(
                server.ping != null ? '${server.ping}ms' : 'n/a',
                style: TextStyle(
                  color: server.ping != null
                      ? _pingColor(server.ping!)
                      : AppColors.textFaint,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                tooltip: isBookmarked ? 'Remove bookmark' : 'Bookmark',
                onPressed: onBookmarkToggle,
                icon: Icon(
                  isBookmarked
                      ? Icons.bookmark_rounded
                      : Icons.bookmark_border_rounded,
                  color: isBookmarked ? AppColors.accent : AppColors.textFaint,
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                color: AppColors.textFaint,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
