import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sstpinger/app/app.dart';
import 'package:sstpinger/app/app_variant.dart';

/// Local variant: activation-code onboarding.
/// Build: `flutter build apk --target lib/main.dart`
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SstpVpnApp(variant: AppVariant.local));
}
