import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../shared/app_colors.dart';
import '../state/locale_provider.dart';

/// Bottom sheet to pick the app language: follow the device, Thai or English.
Future<void> showLanguageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    backgroundColor: Colors.white,
    builder: (_) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final chosen = ref.watch(localeProvider);

    // Language names are written in their own language on purpose: someone
    // who can't read the current one must still find theirs.
    final options = <(Locale?, String)>[
      (null, l10n.languageSystem),
      (const Locale('th'), 'ไทย'),
      (const Locale('en'), 'English'),
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.languageTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            for (final (locale, label) in options)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(label),
                trailing: chosen?.languageCode == locale?.languageCode
                    ? const Icon(Icons.check_rounded, color: AppColors.softBlue)
                    : null,
                onTap: () {
                  ref.read(localeProvider.notifier).select(locale);
                  Navigator.of(context).pop();
                },
              ),
          ],
        ),
      ),
    );
  }
}
