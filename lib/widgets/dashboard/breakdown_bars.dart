import 'package:flutter/material.dart';

import '../../models/spending.dart';
import '../../shared/app_colors.dart';
import 'money.dart';

/// A part-to-whole as bars, longest first: one colour for the whole set (the
/// names already tell the bars apart), the amount at the tip, the longest bar
/// filling the track.
///
/// More than [maxRows] parts are folded: the tail becomes one row, [otherLabel].
class BreakdownBars extends StatelessWidget {
  const BreakdownBars({
    super.key,
    required this.slices,
    required this.color,
    required this.labelFor,
    required this.otherLabel,
    this.maxRows = 6,
  });

  final List<SpendSlice> slices;
  final Color color;
  final String Function(String key) labelFor;
  final String otherLabel;
  final int maxRows;

  List<SpendSlice> get _rows {
    final sorted = [...slices]..sort((a, b) => b.amount.compareTo(a.amount));
    if (sorted.length <= maxRows) return sorted;
    final head = sorted.take(maxRows - 1).toList();
    final tail = sorted.skip(maxRows - 1);
    return [
      ...head,
      SpendSlice(
        key: '__other__',
        amount: tail.fold(0.0, (s, e) => s + e.amount),
        count: tail.fold(0, (s, e) => s + e.count),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final rows = _rows;
    if (rows.isEmpty) return const SizedBox.shrink();
    final top = rows.first.amount <= 0 ? 1.0 : rows.first.amount;
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        r.key == '__other__' ? otherLabel : labelFor(r.key),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          color: AppColors.textMain,
                          fontWeight: FontWeight.w600,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      baht(r.amount),
                      style: const TextStyle(
                        color: AppColors.deepNavy,
                        fontWeight: FontWeight.w800,
                        fontSize: 13.5,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                // The track, and the bar on it: thin, square at the baseline,
                // rounded at the tip.
                LayoutBuilder(
                  builder: (context, box) {
                    final w = box.maxWidth * (r.amount / top).clamp(0.02, 1.0);
                    return Stack(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: const Color(0xFFF1F4FA),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          width: w,
                          height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            borderRadius: const BorderRadius.horizontal(
                              right: Radius.circular(4),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
      ],
    );
  }
}
