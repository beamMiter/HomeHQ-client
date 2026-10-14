import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../state/medicine_provider.dart';

import '../services/medicine_api.dart'; // ใช้ CreateMedicinePayload จาก service
import '../widgets/toast.dart';
import '../l10n/l10n.dart';

class MedicineFormScreen extends ConsumerStatefulWidget {
  const MedicineFormScreen({super.key});

  @override
  ConsumerState<MedicineFormScreen> createState() => _MedicineFormScreenState();
}

class _MedicineFormScreenState extends ConsumerState<MedicineFormScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _form = TextEditingController();
  final _unit = TextEditingController();
  final _category = TextEditingController();

  String? _locationId;

  @override
  void dispose() {
    _name.dispose();
    _form.dispose();
    _unit.dispose();
    _category.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final payload = CreateMedicinePayload(
      name: _name.text.trim(),
      form: _form.text.trim().isEmpty ? null : _form.text.trim(),
      unit: _unit.text.trim().isEmpty ? null : _unit.text.trim(),
      category: _category.text.trim().isEmpty ? null : _category.text.trim(),
      locationId: _locationId,
    );

    await ref.read(createMedicineProvider(payload).future);
    if (mounted) {
      AppToast.success(context.l10n.medFormAdded);
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final locationsAsync = ref.watch(medicineLocationsProvider);

    return Scaffold(
      appBar: AppBar(title: Text(context.l10n.medNew)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: ListView(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: InputDecoration(
                    labelText: context.l10n.medFormName,
                    hintText: context.l10n.medFormNameHint,
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? context.l10n.medFormNameRequired
                      : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _form,
                  decoration: InputDecoration(
                    labelText: context.l10n.medFormForm,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _unit,
                  decoration: InputDecoration(
                    labelText: context.l10n.medFormUnit,
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _category,
                  decoration: InputDecoration(
                    labelText: context.l10n.medFormCategory,
                  ),
                ),
                const SizedBox(height: 12),

                // Location dropdown
                locationsAsync.when(
                  data: (list) => DropdownButtonFormField<String?>(
                    initialValue: _locationId,
                    items: [
                      DropdownMenuItem<String?>(
                        value: null,
                        child: Text(
                          context.l10n.medFormNoLocation,
                          style: TextStyle(color: Theme.of(context).hintColor),
                        ),
                      ),
                      ...list.map(
                        (e) => DropdownMenuItem<String?>(
                          value: e.id,
                          child: Text(e.name ?? e.id),
                        ),
                      ),
                    ],
                    onChanged: (v) => setState(() => _locationId = v),
                    decoration: InputDecoration(
                      labelText: context.l10n.medFormLocation,
                    ),
                  ),
                  loading: () => const LinearProgressIndicator(minHeight: 2),
                  error: (e, st) => Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(context.l10n.medFormLocationsFailed),
                      TextButton(
                        onPressed: () =>
                            ref.invalidate(medicineLocationsProvider),
                        child: Text(context.l10n.commonTryAgain),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: _submit,
                  icon: const Icon(Icons.save_outlined),
                  label: Text(context.l10n.commonSave),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
