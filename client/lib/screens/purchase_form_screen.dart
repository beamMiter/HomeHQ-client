import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/purchase_actions.dart'; 
import '../widgets/toast.dart';
import '../l10n/l10n.dart';

enum PurchaseFormMode { create, edit }

class PurchaseFormScreen extends ConsumerStatefulWidget {
  const PurchaseFormScreen({
    super.key,
    this.mode = PurchaseFormMode.create,
    this.id,
  });

  final PurchaseFormMode mode;
  final String? id;

  @override
  ConsumerState<PurchaseFormScreen> createState() => _PurchaseFormScreenState();
}

class _PurchaseFormScreenState extends ConsumerState<PurchaseFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _title = TextEditingController();
  final _note = TextEditingController();
  final _amount = TextEditingController();

  final _fnTitle = FocusNode();
  final _fnNote = FocusNode();
  final _fnAmount = FocusNode();

  String _currency = 'THB';
  bool _submitting = false;

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    _amount.dispose();
    _fnTitle.dispose();
    _fnNote.dispose();
    _fnAmount.dispose();
    super.dispose();
  }

  String? _validateTitle(String? v) {
    if (v == null || v.trim().isEmpty) {
      return context.l10n.purchFormTitleRequired;
    }
    if (v.trim().length < 3) return context.l10n.purchFormTitleMin;
    return null;
  }

  String? _validateAmount(String? v) {
    if (v == null || v.trim().isEmpty) return null; 
    final parsed = double.tryParse(v.trim());
    if (parsed == null) return context.l10n.commonInvalidNumber;
    if (parsed < 0) return context.l10n.purchFormPositive;
    return null;
  }

  Future<void> _handleSubmit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      await Future.delayed(const Duration(milliseconds: 80));
      _scrollToFirstError();
      return;
    }

    final amountEstimated = _amount.text.trim().isEmpty
        ? null
        : double.tryParse(_amount.text.trim());

    final payload = CreatePurchasePayload(
      title: _title.text.trim(),
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      amountEstimated: amountEstimated,
      currency: _currency,
    );

    setState(() => _submitting = true);
    try {
      final created = await ref.read(createPurchaseProvider(payload).future);

      if (!mounted) return;
      AppToast.success(context.l10n.purchFormCreated);

      context.go('/purchases/${created.id}');
    } catch (e) {
      var message = context.l10n.purchFormError;
      final t = e.runtimeType.toString();
      if (t == 'AuthRequired') {
        message = context.l10n.purchFormSignIn;
      } else if (t == 'ApiError') {
        message = e.toString();
      } else {
        message = e.toString();
      }
      if (mounted) {
        AppToast.error(message);
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _scrollToFirstError() {
    if (_validateTitle(_title.text) != null) {
      _fnTitle.requestFocus();
    } else if (_validateAmount(_amount.text) != null) {
      _fnAmount.requestFocus();
    }
  }

  // จำกัดตัวเลข + จุดเดียว
  final _amountFormatter = <TextInputFormatter>[
    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}$')),
  ];

  @override
  Widget build(BuildContext context) {
    const spacing = 16.0;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.mode == PurchaseFormMode.create
              ? context.l10n.purchFormCreate
              : context.l10n.purchFormEdit,
        ),
        actions: [
          TextButton(
            onPressed: _submitting
                ? null
                : () {
                    FocusScope.of(context).unfocus();
                    context.pop();
                  },
            child: Text(context.l10n.commonCancel),
          ),
        ],
      ),
      body: SafeArea(
        child: AbsorbPointer(
          absorbing: _submitting, 
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(spacing),
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              children: [
                Text(
                  context.l10n.purchFormDetails,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _title,
                          focusNode: _fnTitle,
                          decoration: InputDecoration(
                            labelText: context.l10n.purchFormTitleLabel,
                            hintText: context.l10n.purchFormTitleHint,
                            prefixIcon: Icon(Icons.assignment_outlined),
                          ),
                          textInputAction: TextInputAction.next,
                          validator: _validateTitle,
                          onFieldSubmitted: (_) =>
                              _fnNote.requestFocus(), // next ไป Note
                        ),
                        const SizedBox(height: spacing),
                        TextFormField(
                          controller: _note,
                          focusNode: _fnNote,
                          decoration: InputDecoration(
                            labelText: context.l10n.commonNote,
                            hintText: context.l10n.purchFormNoteHint,
                            alignLabelWithHint: true,
                            prefixIcon: Icon(Icons.notes_outlined),
                          ),
                          minLines: 3,
                          maxLines: 6,
                          keyboardType: TextInputType.multiline,
                          maxLength: 500,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: spacing),

                Text(
                  context.l10n.purchFormBudget,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                Card(
                  elevation: 0,
                  color: theme.colorScheme.surface,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                    side: BorderSide(color: theme.colorScheme.outlineVariant),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      children: [
                        TextFormField(
                          controller: _amount,
                          focusNode: _fnAmount,
                          decoration: InputDecoration(
                            labelText: context.l10n.purchFormEstimated,
                            hintText: context.l10n.purchFormEstimatedHint,
                            prefixIcon: const Icon(Icons.payments_outlined),
                            suffixText: _currency,
                          ),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: _amountFormatter,
                          validator: _validateAmount,
                          onFieldSubmitted: (_) => _handleSubmit(),
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.purchFormCurrency,
                                style: theme.textTheme.labelLarge,
                              ),
                              const SizedBox(height: 8),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'THB',
                                    label: Text('THB'),
                                  ),
                                  ButtonSegment(
                                    value: 'USD',
                                    label: Text('USD'),
                                  ),
                                  ButtonSegment(
                                    value: 'EUR',
                                    label: Text('EUR'),
                                  ),
                                ],
                                selected: {_currency},
                                onSelectionChanged: (s) {
                                  setState(() => _currency = s.first);
                                },
                              ),
                              const SizedBox(height: 6),
                              Text(
                                context.l10n.purchFormOptional,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.hintColor,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 120),
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            icon: _submitting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                _submitting
                    ? context.l10n.purchFormSaving
                    : context.l10n.commonSave,
              ),
            ),
            onPressed: _submitting ? null : _handleSubmit,
          ),
        ),
      ),
    );
  }
}
