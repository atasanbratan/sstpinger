import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// The speedometer action — pings the bookmarks group.
class PingAction extends StatelessWidget {
  final bool isPinging;
  final bool isConnected;
  final VoidCallback onPressed;

  const PingAction({
    super.key,
    required this.isPinging,
    required this.isConnected,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    if (isPinging) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppColors.accent,
          ),
        ),
      );
    }
    return IconButton(
      visualDensity: VisualDensity.compact,
      iconSize: 19,
      tooltip: isConnected ? 'Disconnect to ping' : 'Ping bookmarks',
      onPressed: onPressed,
      icon: Icon(
        Icons.speed_rounded,
        color: isConnected ? AppColors.textFaint : AppColors.accent,
      ),
    );
  }
}
