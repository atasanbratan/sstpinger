import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Toggle + fields for overriding the VPN node used for connecting (host,
/// port, VPN username/password), bypassing the fetched server list.
class CustomNodeSettings extends StatelessWidget {
  final bool enabled;
  final ValueChanged<bool> onEnabledChanged;
  final TextEditingController hostController;
  final TextEditingController portController;
  final TextEditingController usernameController;
  final TextEditingController passwordController;

  const CustomNodeSettings({
    super.key,
    required this.enabled,
    required this.onEnabledChanged,
    required this.hostController,
    required this.portController,
    required this.usernameController,
    required this.passwordController,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'USE CUSTOM NODE SETTINGS',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: Colors.white38,
              ),
            ),
            Switch(
              value: enabled,
              activeThumbColor: AppColors.accent,
              onChanged: onEnabledChanged,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (enabled) ...[
          TextField(
            controller: hostController,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'Host IP / Hostname',
              labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: portController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Port',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                flex: 2,
                child: TextField(
                  controller: usernameController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: const InputDecoration(
                    labelText: 'VPN User',
                    labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: AppColors.accent),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: passwordController,
            obscureText: true,
            style: const TextStyle(color: Colors.white, fontSize: 13),
            decoration: const InputDecoration(
              labelText: 'VPN Password',
              labelStyle: TextStyle(color: Colors.white54, fontSize: 12),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: AppColors.accent),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
