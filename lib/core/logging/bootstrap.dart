import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'file_logger.dart';

/// Starts the app with file logging in place.
///
/// Everything runs inside a guarded zone so an uncaught error lands in the log
/// rather than vanishing — on a desktop GUI build there is no console to print
/// to, which is exactly when things fail silently. Also records the environment
/// (version, platform, exe path) that a bug report needs.
Future<void> bootstrapAndRun(Widget app) async {
  await runZonedGuarded(() async {
    WidgetsFlutterBinding.ensureInitialized();
    await FileLogger.instance.init();

    // Flutter's own errors (widget build failures, etc.).
    final priorOnError = FlutterError.onError;
    FlutterError.onError = (details) {
      logLine('FLUTTER ERROR: ${details.exception}\n${details.stack}');
      priorOnError?.call(details);
    };
    // Errors from the platform side that never reach the zone.
    PlatformDispatcher.instance.onError = (error, stack) {
      logLine('PLATFORM ERROR: $error\n$stack');
      return true;
    };

    await _logEnvironment();

    // Mobile-only; on desktop this throws MissingPluginException, and a failure
    // here must not take the app down.
    try {
      await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    } catch (e) {
      logLine('setPreferredOrientations skipped: $e');
    }

    runApp(app);
  }, (error, stack) {
    logLine('UNCAUGHT: $error\n$stack');
  });
}

Future<void> _logEnvironment() async {
  try {
    final info = await PackageInfo.fromPlatform();
    logLine('app ${info.version}+${info.buildNumber} (${info.packageName})');
  } catch (e) {
    logLine('package info unavailable: $e');
  }
  logLine('platform: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
  logLine('exe: ${Platform.resolvedExecutable}');
  if (!Platform.isAndroid && !Platform.isIOS) {
    // The SoftEther binaries are expected next to the executable; report whether
    // they are actually there, since a missing bundle is a silent failure.
    final dir = File(Platform.resolvedExecutable).parent.path;
    final se = Directory('$dir${Platform.pathSeparator}softether');
    logLine('softether dir: ${se.path} exists=${se.existsSync()}');
    if (se.existsSync()) {
      final names = se.listSync().map((e) => e.uri.pathSegments.last).toList();
      logLine('softether contents: $names');
    }
  }
}
