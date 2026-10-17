/// One part of a whole: a bill type or a purchase category.
class SpendSlice {
  const SpendSlice({required this.key, required this.amount, this.count = 0});

  final String key;
  final double amount;
  final int count;

  factory SpendSlice.fromJson(Map<String, dynamic> j) => SpendSlice(
    key: (j['key'] ?? '').toString(),
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    count: (j['count'] as num?)?.toInt() ?? 0,
  );
}

/// One month of the trend.
class SpendPoint {
  const SpendPoint({
    required this.month,
    required this.bills,
    required this.purchases,
  });

  /// "2026-10".
  final String month;
  final double bills;
  final double purchases;

  double get total => bills + purchases;

  factory SpendPoint.fromJson(Map<String, dynamic> j) => SpendPoint(
    month: (j['month'] ?? '').toString(),
    bills: (j['bills'] as num?)?.toDouble() ?? 0,
    purchases: (j['purchases'] as num?)?.toDouble() ?? 0,
  );
}

/// One day of the month: what was paid out that day.
class DayPoint {
  const DayPoint({required this.day, this.bills = 0, this.purchases = 0});

  final int day;
  final double bills;
  final double purchases;

  double get total => bills + purchases;

  factory DayPoint.fromJson(Map<String, dynamic> j) => DayPoint(
    day: (j['day'] as num?)?.toInt() ?? 0,
    bills: (j['bills'] as num?)?.toDouble() ?? 0,
    purchases: (j['purchases'] as num?)?.toDouble() ?? 0,
  );
}

/// An unpaid bill, soonest first.
class UpcomingBill {
  const UpcomingBill({
    required this.id,
    required this.title,
    required this.type,
    required this.amount,
    required this.daysLeft,
    required this.overdue,
  });

  final String id;
  final String title;
  final String type;
  final double amount;

  /// Negative once it is overdue.
  final int daysLeft;
  final bool overdue;

  factory UpcomingBill.fromJson(Map<String, dynamic> j) => UpcomingBill(
    id: (j['id'] ?? '').toString(),
    title: (j['title'] ?? '').toString(),
    type: (j['type'] ?? '').toString(),
    amount: (j['amount'] as num?)?.toDouble() ?? 0,
    daysLeft: (j['days_left'] as num?)?.toInt() ?? 0,
    overdue: j['overdue'] == true,
  );
}

/// The spending dashboard for one month.
class Spending {
  const Spending({
    required this.month,
    required this.totalSpent,
    required this.previousMonth,
    required this.previousSpent,
    required this.billsPaid,
    required this.billsPaidCount,
    required this.billsByType,
    required this.unpaid,
    required this.unpaidCount,
    required this.overdue,
    required this.overdueCount,
    required this.purchasesSpent,
    required this.purchasesCount,
    required this.purchasesByCategory,
    required this.excludedCount,
    required this.openCount,
    required this.openEstimated,
    required this.trend,
    required this.upcoming,
    this.daily = const [],
    this.previousDaily = const [],
    this.throughDay = 0,
  });

  final String month;
  final double totalSpent;
  final String previousMonth;
  final double previousSpent;

  final double billsPaid;
  final int billsPaidCount;
  final List<SpendSlice> billsByType;
  final double unpaid;
  final int unpaidCount;
  final double overdue;
  final int overdueCount;

  final double purchasesSpent;
  final int purchasesCount;
  final List<SpendSlice> purchasesByCategory;
  final int excludedCount;
  final int openCount;
  final double openEstimated;

  final List<SpendPoint> trend;
  final List<UpcomingBill> upcoming;

  /// Every day of the month, and of the month before.
  final List<DayPoint> daily;
  final List<DayPoint> previousDaily;

  /// How far the month has got: today's date in the current month, the last
  /// day for a past one, 0 for one still to come.
  final int throughDay;

  /// The running total at the end of each day, for [days]: what was spent so
  /// far by then.
  static List<double> runningTotal(List<DayPoint> days) {
    var sum = 0.0;
    return [for (final d in days) sum += d.total];
  }

  /// Nothing went out in the month.
  bool get isEmpty => totalSpent <= 0;

  /// The change on the month before, as a whole percent; null when there was
  /// nothing then to compare with.
  int? get changePercent {
    if (previousSpent <= 0) return null;
    return ((totalSpent - previousSpent) / previousSpent * 100).round();
  }

  factory Spending.fromJson(Map<String, dynamic> j) {
    Map<String, dynamic> obj(String k) =>
        j[k] is Map ? (j[k] as Map).cast<String, dynamic>() : const {};
    List<T> items<T>(Object? raw, T Function(Map<String, dynamic>) f) => [
      for (final e in (raw as List? ?? const []))
        if (e is Map) f(e.cast<String, dynamic>()),
    ];
    double num0(Map<String, dynamic> m, String k) =>
        (m[k] as num?)?.toDouble() ?? 0;
    int int0(Map<String, dynamic> m, String k) => (m[k] as num?)?.toInt() ?? 0;

    final b = obj('bills'), p = obj('purchases');
    return Spending(
      month: (j['month'] ?? '').toString(),
      totalSpent: num0(j, 'total_spent'),
      previousMonth: (j['previous_month'] ?? '').toString(),
      previousSpent: num0(j, 'previous_spent'),
      billsPaid: num0(b, 'paid'),
      billsPaidCount: int0(b, 'paid_count'),
      billsByType: items(b['by_type'], SpendSlice.fromJson),
      unpaid: num0(b, 'unpaid'),
      unpaidCount: int0(b, 'unpaid_count'),
      overdue: num0(b, 'overdue'),
      overdueCount: int0(b, 'overdue_count'),
      purchasesSpent: num0(p, 'spent'),
      purchasesCount: int0(p, 'count'),
      purchasesByCategory: items(p['by_category'], SpendSlice.fromJson),
      excludedCount: int0(p, 'excluded_count'),
      openCount: int0(p, 'open_count'),
      openEstimated: num0(p, 'open_estimated'),
      trend: items(j['trend'], SpendPoint.fromJson),
      upcoming: items(j['upcoming'], UpcomingBill.fromJson),
      daily: items(j['daily'], DayPoint.fromJson),
      previousDaily: items(j['previous_daily'], DayPoint.fromJson),
      throughDay: int0(j, 'through_day'),
    );
  }
}
