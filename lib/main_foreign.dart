import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sstp_shield/app/app.dart';
import 'package:sstp_shield/app/app_variant.dart';

/// Foreign variant: crypto (BEP20/TRC20) subscription onboarding.
/// Build: `flutter build apk --target lib/main_foreign.dart`
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  runApp(const SstpVpnApp(variant: AppVariant.foreign));
}
