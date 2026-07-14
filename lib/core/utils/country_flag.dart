/// Returns the emoji flag for a two-letter ISO country code (e.g. `US` → 🇺🇸),
/// or a globe when the code is missing or malformed.
String countryFlagEmoji(String countryCode) {
  final code = countryCode.trim().toUpperCase();
  if (code.length != 2) return '🌐';

  const base = 0x1F1E6; // Regional Indicator Symbol Letter A
  const letterA = 0x41; // ASCII 'A'
  final first = code.codeUnitAt(0) - letterA + base;
  final second = code.codeUnitAt(1) - letterA + base;
  return String.fromCharCode(first) + String.fromCharCode(second);
}
