import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../state/bills_provider.dart';
import '../widgets/toast.dart';
import '../l10n/friendly_error.dart';
import '../l10n/l10n.dart';
import '../l10n/labels.dart';

class BillFormScreen extends ConsumerStatefulWidget {
  const BillFormScreen({super.key});

  @override
  ConsumerState<BillFormScreen> createState() => _BillFormScreenState();
}

class _BillFormScreenState extends ConsumerState<BillFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();

  String _type = 'electric';
  String _status = 'unpaid';
  DateTime? _due;

  @override
  void dispose() {
    _title.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDueDate() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: _due ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 3),
    );
    if (d != null) {
      // ตั้งเวลา default เป็น 23:59 ของวันนั้น
      _due = DateTime(d.year, d.month, d.day, 23, 59);
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final createState = ref.watch(billCreateProvider);
    final dateLabel = _due == null
        ? l10n.billFormPickDue
        : DateFormat('yyyy-MM-dd 23:59').format(_due!);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.billsNew)),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Type
              DropdownButtonFormField<String>(
                initialValue: _type,
                decoration: InputDecoration(labelText: l10n.billFormType),
                items: [
                  for (final t in const [
                    'electric',
                    'water',
                    'internet',
                    'phone',
                  ])
                    DropdownMenuItem(
                      value: t,
                      child: Text(billTypeLabel(l10n, t)),
                    ),
                ],
                onChanged: (v) => setState(() => _type = v ?? 'electric'),
              ),
              const SizedBox(height: 12),

              // Title
              TextFormField(
                controller: _title,
                decoration: InputDecoration(labelText: l10n.billFormTitle),
                validator: (v) => (v == null || v.trim().isEmpty)
                    ? l10n.billFormTitleRequired
                    : null,
              ),
              const SizedBox(height: 12),

              // Amount
              TextFormField(
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: l10n.billFormAmount),
                validator: (v) {
                  final x = double.tryParse((v ?? '').trim());
                  if (x == null) return l10n.billFormAmountInvalid;
                  if (x <= 0) return l10n.billFormAmountPositive;
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Due date
              InkWell(
                onTap: _pickDueDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: l10n.billDetailDueDate,
                  ),
                  child: Text(
                    dateLabel,
                    style: TextStyle(
                      color: _due == null
                          ? Colors.black.withValues(alpha: .45)
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Status
              DropdownButtonFormField<String>(
                initialValue: _status,
                decoration: InputDecoration(labelText: l10n.billDetailStatus),
                items: [
                  DropdownMenuItem(
                    value: 'unpaid',
                    child: Text(l10n.billStatusUnpaid),
                  ),
                  DropdownMenuItem(
                    value: 'paid',
                    child: Text(l10n.billStatusPaid),
                  ),
                ],
                onChanged: (v) => setState(() => _status = v ?? 'unpaid'),
              ),
              const SizedBox(height: 12),

              // Note
              TextFormField(
                controller: _note,
                minLines: 2,
                maxLines: 5,
                decoration: InputDecoration(labelText: l10n.billFormNote),
              ),
              const SizedBox(height: 20),

              // Submit
              FilledButton.icon(
                onPressed: createState.isLoading
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        if (_due == null) {
                          AppToast.error(l10n.billFormPickDueFirst);
                          return;
                        }
                        if (_due!.isBefore(DateTime.now())) {
                          AppToast.error(l10n.billFormDuePast);
                          return;
                        }

                        await ref
                            .read(billCreateProvider.notifier)
                            .submit(
                              type: _type,
                              title: _title.text.trim(),
                              amount: double.parse(_amount.text.trim()),
                              dueDate: _due!,
                              status: _status,
                              note: _note.text.trim().isEmpty
                                  ? null
                                  : _note.text.trim(),
                            );

                        final s = ref.read(billCreateProvider);
                        if (!context.mounted) return;
                        if (!s.hasError) {
                          AppToast.success(l10n.billFormCreated);
                          Navigator.of(context).pop(true);
                        } else {
                          AppToast.error(friendlyError(l10n, s.error));
                        }
                      },
                icon: createState.isLoading
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.save),
                label: Text(l10n.commonSave),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
