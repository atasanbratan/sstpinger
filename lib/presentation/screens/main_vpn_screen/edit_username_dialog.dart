import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// The "Change Username" dialog. [onSave] is only invoked when the trimmed
/// input is non-empty (the untrimmed text is passed through, matching the
/// existing UsernameChanged event's own trimming behavior, if any).
void showEditUsernameDialog(
  BuildContext context, {
  required String currentUsername,
  required ValueChanged<String> onSave,
}) {
  final controller = TextEditingController(text: currentUsername);
  showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text(
          'Change Username',
          style: TextStyle(color: Colors.white, fontFamily: 'Outfit'),
        ),
        content: TextField(
          controller: controller,
          autofocus: true,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter new username',
            hintStyle: TextStyle(color: Colors.white38),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: AppColors.accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                onSave(controller.text);
                Navigator.pop(dialogContext);
              }
            },
            child: const Text('SAVE', style: TextStyle(color: AppColors.accent)),
          ),
        ],
      );
    },
  );
}
