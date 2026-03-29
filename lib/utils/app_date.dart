import 'package:intl/intl.dart';

final List<DateFormat> _supportedDateFormats = [
  DateFormat('yyyy-MM-dd'),
  DateFormat('dd.MM.yyyy'),
  DateFormat('d.M.yyyy'),
  DateFormat('dd/MM/yyyy'),
  DateFormat('d/M/yyyy'),
  DateFormat('yyyy/MM/dd'),
];

DateTime? tryParseAppDate(String? raw) {
  final value = raw?.trim();
  if (value == null || value.isEmpty) return null;

  final parsed = DateTime.tryParse(value);
  if (parsed != null) {
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  for (final format in _supportedDateFormats) {
    try {
      final match = format.parseStrict(value);
      return DateTime(match.year, match.month, match.day);
    } catch (_) {
      // Try the next supported format.
    }
  }

  return null;
}

String normalizeAppDate(String? raw, {DateTime? fallback}) {
  final parsed = tryParseAppDate(raw) ?? fallback ?? DateTime.now();
  return DateFormat('yyyy-MM-dd').format(parsed);
}

String formatAppDate(String? raw, {String fallback = '-'}) {
  final parsed = tryParseAppDate(raw);
  if (parsed != null) {
    return DateFormat('dd.MM.yyyy').format(parsed);
  }

  final value = raw?.trim();
  if (value == null || value.isEmpty) return fallback;
  return value;
}
