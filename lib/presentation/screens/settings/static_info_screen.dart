import 'package:flutter/material.dart';

import '../../theme/app_colors.dart';

/// Generic title+body screen shared by Privacy Policy, Terms of Service, and
/// Privacy & Security — all three are a single block of text with no other
/// structure, so one widget covers all of them.
class StaticInfoScreen extends StatelessWidget {
  final String title;
  final String body;

  const StaticInfoScreen({super.key, required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: Text(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: SingleChildScrollView(
          child: Text(
            body,
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}
