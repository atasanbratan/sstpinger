/// Compares dotted version strings such as `2.4.0`, `2.4`, or `2.4.0+29`.
///
/// Returns a negative number if [a] is older than [b], 0 if they are the same
/// release, and a positive number if [a] is newer. The build suffix (`+29`) and
/// any pre-release tail (`-beta`) are ignored, and missing components count as
/// zero — so `2.4` and `2.4.0+29` compare equal. Non-numeric components are
/// treated as 0 rather than throwing: a malformed feed must not crash the app.
int compareVersions(String a, String b) {
  final pa = _parts(a);
  final pb = _parts(b);
  final length = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x < y ? -1 : 1;
  }
  return 0;
}

List<int> _parts(String version) => version
    .trim()
    .split('+')
    .first
    .split('-')
    .first
    .split('.')
    .map((part) => int.tryParse(part.trim()) ?? 0)
    .toList();
