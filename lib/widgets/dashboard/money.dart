import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

/// The two series of the dashboard. Fixed, so a bill is always blue and a
/// purchase always orange, on every screen and in every month.
const kBillsColor = Color(0xFF2A78D6);
const kPurchasesColor = Color(0xFFEB6834);

/// The five kinds of bill, in a fixed order and each with its own colour, so a
/// type is the same colour in every month and next to any other (colour follows
/// the entity, never its rank). "Other" is the neutral grey.
const kBillTypeOrder = ['electric', 'water', 'internet', 'phone', 'other'];

const _billTypeColors = {
  'electric': Color(0xFFEDA100),
  'water': Color(0xFF1BAF7A),
  'internet': Color(0xFF6250D6),
  'phone': Color(0xFFE87BA4),
  'other': Color(0xFF94A3B8),
};

/// The colour of a bill type; one the app does not know is "other".
Color billTypeColor(String type) =>
    _billTypeColors[type] ?? _billTypeColors['other']!;

/// The running-total lines: this month in ink, last month in a quiet grey.
const kPaceNowColor = Color(0xFF0F2D5C);
const kPacePrevColor = Color(0xFF8A94A6);

/// Status colours: always shown with an icon and words, never alone.
const kCriticalColor = Color(0xFFD03B3B);
const kWarningColor = Color(0xFFFAB219);
const kGoodColor = Color(0xFF0CA30C);

/// A baht amount as people write it: no satang for a whole amount.
String baht(double v) {
  final whole = v == v.roundToDouble();
  return NumberFormat.currency(
    locale: 'th_TH',
    symbol: '฿',
    decimalDigits: whole ? 0 : 2,
  ).format(v);
}

/// An axis or label amount, short: 950, 1.2K, 12K, 1.2M.
String compactBaht(double v) {
  String trim(double x) {
    final s = x.toStringAsFixed(1);
    return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
  }

  final a = v.abs();
  if (a >= 1000000) return '${trim(v / 1000000)}M';
  if (a >= 10000) return '${(v / 1000).round()}K';
  if (a >= 1000) return '${trim(v / 1000)}K';
  return v.round().toString();
}

/// The top of an axis: the next 1, 2 or 5 times a power of ten above [v].
double niceMax(double v) {
  if (v <= 0) return 100;
  var base = 1.0;
  while (base * 10 <= v) {
    base *= 10;
  }
  for (final m in const [1, 2, 5, 10]) {
    if (base * m >= v) return base * m;
  }
  return base * 10;
}
