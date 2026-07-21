import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/app_colors.dart';
import 'settings_card.dart';

/// Username (editable) and device advertising ID (copyable) rows.
class UserProfileCard extends StatelessWidget {
  final String username;
  final String deviceId;
  final VoidCallback onEditUsername;

  const UserProfileCard({
    super.key,
    required this.username,
    required this.deviceId,
    required this.onEditUsername,
  });

  @override
  Widget build(BuildContext context) {
    return SettingsCard(
      child: Column(
        children: [
          Row(
            children: [
              const Icon(Icons.person, color: AppColors.accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Username',
                      style: TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                    Text(
                      username,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.edit, color: Colors.white70, size: 18),
                onPressed: onEditUsername,
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            children: [
              const Icon(
                Icons.phone_android,
                color: AppColors.accentSecondary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Device Advertising ID',
                      style: TextStyle(fontSize: 10, color: Colors.white38),
                    ),
                    Text(
                      deviceId,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: Colors.white70,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.copy, color: Colors.white70, size: 18),
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: deviceId));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Device ID copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
