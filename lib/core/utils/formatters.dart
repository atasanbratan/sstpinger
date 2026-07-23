import 'dart:math';

/// Pure formatting helpers shared across the UI. Keep display formatting here
/// rather than re-implementing it inside widgets.
class Formatters {
  Formatters._();

  static const List<String> _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', //
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];

  /// `HH:MM:SS`, e.g. a connection uptime.
  static String duration(Duration d) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}'
        ':${two(d.inSeconds.remainder(60))}';
  }

  /// `Mon D, YYYY  HH:MM` in local time, or `Unknown` when null.
  static String date(DateTime? date) {
    if (date == null) return 'Unknown';
    final local = date.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '${_months[local.month - 1]} ${local.day}, ${local.year}  $h:$m';
  }

  /// Remaining time until [expireTime], e.g. `2 months, 3 days left`,
  /// `12 days left`, `Less than a day left`, or `Expired`.
  static String remaining(DateTime? expireTime) {
    if (expireTime == null) return 'Unknown';
    final diff = expireTime.difference(DateTime.now());
    if (diff.isNegative) return 'Expired';
    final totalDays = diff.inDays;
    if (totalDays == 0) return 'Less than a day left';
    if (totalDays < 30) {
      return '$totalDays ${totalDays == 1 ? 'day' : 'days'} left';
    }
    final months = totalDays ~/ 30;
    final days = totalDays % 30;
    final monthsPart = '$months ${months == 1 ? 'month' : 'months'}';
    if (days == 0) return '$monthsPart left';
    return '$monthsPart, $days ${days == 1 ? 'day' : 'days'} left';
  }

  /// Human-readable byte count, e.g. `1.5 MB`.
  static String bytes(int value) => _humanize(value, _byteSuffixes);

  /// Human-readable transfer rate, e.g. `1.5 MB/s`.
  static String speed(int bytesPerSecond) =>
      _humanize(bytesPerSecond, _speedSuffixes);

  static const List<String> _byteSuffixes = ['B', 'KB', 'MB', 'GB'];
  static const List<String> _speedSuffixes = ['B/s', 'KB/s', 'MB/s', 'GB/s'];

  static String _humanize(int value, List<String> suffixes) {
    if (value <= 0) return '0 ${suffixes.first}';
    var i = (log(value) / log(1024)).floor();
    i = i.clamp(0, suffixes.length - 1);
    return '${(value / pow(1024, i)).toStringAsFixed(1)} ${suffixes[i]}';
  }
}
