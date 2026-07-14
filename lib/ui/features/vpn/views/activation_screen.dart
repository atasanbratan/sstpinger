import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/app_colors.dart';
import '../view_models/vpn_view_model.dart';

class ActivationScreen extends StatefulWidget {
  final VpnViewModel viewModel;

  const ActivationScreen({super.key, required this.viewModel});

  @override
  State<ActivationScreen> createState() => _ActivationScreenState();
}

class _ActivationScreenState extends State<ActivationScreen> {
  bool _isImporting = false;

  Future<void> _pasteFromClipboard() async {
    if (_isImporting) return;

    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim();

    if (text == null || text.isEmpty) {
      _showMessage('Clipboard is empty. Copy your activation code first.');
      return;
    }

    setState(() => _isImporting = true);
    final success = await widget.viewModel.importActivationCode(text);
    if (!mounted) return;
    setState(() => _isImporting = false);

    if (success) {
      _showMessage('Activation successful!', isError: false);
    }
    // Failure is reported by the view model via its error callback.
  }

  void _showMessage(String message, {bool isError = true}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(fontFamily: 'Outfit')),
        backgroundColor: isError ? AppColors.error : Colors.green,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.gradientTop, AppColors.gradientBottom],
          ),
        ),
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Image.asset(
                  'assets/logo/logo.png',
                  width: 96,
                  height: 96,
                ),
                const SizedBox(height: 20),
                const Text(
                  'SSTP SHIELD',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Your Secure Gateway to SSTP VPN Nodes',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.white54),
                ),
                const SizedBox(height: 48),

                // Welcome card
                Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  color: AppColors.surfaceCard,
                  elevation: 8,
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Let\'s Get Started',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Paste your activation code',
                          style: TextStyle(fontSize: 12, color: Colors.white70),
                        ),
                        const SizedBox(height: 20),

                        InkWell(
                          onTap: _pasteFromClipboard,
                          borderRadius: BorderRadius.circular(14),
                          child: Ink(
                            decoration: BoxDecoration(
                              color: AppColors.inputBackground,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: AppColors.accentBorderFaint,
                              ),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 30,
                                    height: 30,
                                    child: _isImporting
                                        ? const CircularProgressIndicator(
                                            strokeWidth: 2.5,
                                            color: AppColors.accent,
                                          )
                                        : const Icon(
                                            Icons.content_paste_rounded,
                                            color: AppColors.accent,
                                            size: 30,
                                          ),
                                  ),
                                  const SizedBox(width: 16),
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _isImporting
                                            ? 'Activating…'
                                            : 'Import activation code',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      const Text(
                                        'Paste from clipboard',
                                        style: TextStyle(color: Colors.white54),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
