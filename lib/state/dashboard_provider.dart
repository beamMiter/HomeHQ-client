import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/spending.dart';
import '../repositories/dashboard_repository.dart';
import '../services/api_client.dart' show apiClientProvider;

final dashboardRepoProvider = Provider<DashboardRepository>(
  (ref) => DashboardRepository(ref.watch(apiClientProvider).dio),
);

/// The month on show, as "YYYY-MM"; null means the current one.
class DashboardMonth extends Notifier<String?> {
  @override
  String? build() => null;

  void pick(String? month) => state = month;
}

final dashboardMonthProvider = NotifierProvider<DashboardMonth, String?>(
  DashboardMonth.new,
);

/// The figures for one month. The key is the month ("YYYY-MM") or null.
final spendingProvider = FutureProvider.autoDispose.family<Spending, String?>(
  (ref, month) => ref.watch(dashboardRepoProvider).spending(month: month),
);
