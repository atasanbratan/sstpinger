import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sstpinger/main.dart';

void main() {
  testWidgets('App starts and displays welcome or title', (WidgetTester tester) async {
    const MethodChannel('advertising_id').setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'getAdvertisingId') {
        return '00000000-0000-0000-0000-000000000001';
      }
      return null;
    });

    const MethodChannel('sstp_flutter').setMockMethodCallHandler((MethodCall methodCall) async {
      if (methodCall.method == 'checkLastConnectionStatus') {
        return 'Disconnected';
      }
      return null;
    });

    // Mock sstp response channel as well
    const MethodChannel('responseReceiver').setMockMethodCallHandler((MethodCall methodCall) async {
      return null;
    });

    SharedPreferences.setMockInitialValues({});
    await tester.pumpWidget(const SstpVpnApp());
    for (int i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
    expect(find.text('SSTP SHIELD'), findsWidgets);
  });
}
