import 'dart:io';

/// Appends diagnostics to a log file on disk.
///
/// Desktop GUI builds have no console the user can read (double-clicking the exe
/// on Windows shows nothing), so tunnel failures are otherwise invisible. Every
/// line is timestamped and flushed immediately — a crash must not lose the line
/// that explains it.
///
/// The file lives in a per-user data directory and is truncated at each launch,
/// so what you send is the current session only:
///
///   * Windows: `%LOCALAPPDATA%\SSTPShield\sstp-shield.log`
///   * Linux:   `~/.local/share/sstp-shield/sstp-shield.log`
class FileLogger {
  FileLogger._();
  static final FileLogger instance = FileLogger._();

  IOSink? _sink;
  String? _path;

  /// Where the log is being written, once [init] has run.
  String? get path => _path;

  /// Opens (and truncates) the log file. Safe to call once at startup; failures
  /// are swallowed — logging must never stop the app from running.
  Future<void> init({String appName = 'SSTPShield'}) async {
    if (_sink != null) return;
    try {
      final dir = Directory(_logDir(appName));
      if (!dir.existsSync()) dir.createSync(recursive: true);
      final file = File('${dir.path}${Platform.pathSeparator}sstp-shield.log');
      _sink = file.openWrite(mode: FileMode.write); // truncate per session
      _path = file.path;
      log('--- log opened: ${file.path}');
    } catch (_) {
      _sink = null;
    }
  }

  String _logDir(String appName) {
    if (Platform.isWindows) {
      final base = Platform.environment['LOCALAPPDATA'] ??
          Platform.environment['APPDATA'] ??
          Directory.systemTemp.path;
      return '$base\\$appName';
    }
    final home = Platform.environment['HOME'] ?? Directory.systemTemp.path;
    return '$home/.local/share/sstp-shield';
  }

  /// Writes one timestamped line to the log (and stdout, for terminal runs).
  void log(String message) {
    final line = '${DateTime.now().toIso8601String()} $message';
    // ignore: avoid_print
    print(line);
    try {
      _sink?.writeln(line);
      // Flush every line: a crash must not swallow the reason for the crash.
      _sink?.flush();
    } catch (_) {/* never let logging break the app */}
  }

  Future<void> close() async {
    try {
      await _sink?.flush();
      await _sink?.close();
    } catch (_) {/* ignore */}
    _sink = null;
  }
}

/// Shorthand for [FileLogger.instance.log].
void logLine(String message) => FileLogger.instance.log(message);
