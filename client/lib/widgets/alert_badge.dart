// lib/widgets/alert_badge.dart
import 'package:flutter/material.dart';
import '../l10n/l10n.dart';
import '../models/medicine_alert.dart';

class AlertBadge extends StatelessWidget {
  final MedicineAlert? alert;
  final bool dense;
  const AlertBadge({super.key, required this.alert, this.dense = true});

  @override
  Widget build(BuildContext context) {
    if (alert == null) {
      return _chip(
        context,
        label: context.l10n.medAlertNone,
        color: Colors.grey.shade200,
        fg: Colors.grey.shade700,
        dense: dense,
      );
    }
    final a = alert!;
    final on = a.enabled;
    final l10n = context.l10n;
    final label = on
        ? l10n.medAlertOn('${a.minQty ?? '-'}', '${a.expiryWindowDays ?? '-'}')
        : l10n.medAlertOff;
    return _chip(
      context,
      label: label,
      color: on ? Colors.blue.shade50 : Colors.grey.shade200,
      fg: on ? Colors.blue.shade800 : Colors.grey.shade600,
      dense: dense,
    );
  }

  Widget _chip(
    BuildContext context, {
    required String label,
    required Color color,
    required Color fg,
    required bool dense,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 10 : 12,
        vertical: dense ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: fg.withValues(alpha: .2)), // 👈 แก้ตรงนี้
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(color: fg, fontWeight: FontWeight.w600),
      ),
    );
  }
}
