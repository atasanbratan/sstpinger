import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The title bar: settings icon, logo, app name, and version (once loaded).
class MainVpnAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String version;
  final VoidCallback onSettingsTap;

  const MainVpnAppBar({
    super.key,
    required this.version,
    required this.onSettingsTap,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      leading: IconButton(
        icon: const Icon(Icons.settings_outlined, color: Colors.white70),
        tooltip: 'Settings / Profile',
        onPressed: onSettingsTap,
      ),
      title: Row(
        children: [
          Image.asset('assets/logo/logo.png', width: 24, height: 24),
          const SizedBox(width: 8),
          Text(
            'SSTP SHIELD',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              letterSpacing: 2,
              fontSize: 17,
            ),
          ),
          if (version.isNotEmpty) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                'v$version',
                style: const TextStyle(
                  color: AppColors.textFaint,
                  fontSize: 11,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
