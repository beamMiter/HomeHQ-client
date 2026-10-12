import 'package:flutter/material.dart';

import '../l10n/l10n.dart';

class ErrorState extends StatelessWidget {
  final String title;
  final Object? error;
  final VoidCallback? onRetry;
  final IconData? icon;

  /// Defaults to the translated "Try again".
  final String? retryLabel;

  const ErrorState({
    super.key,
    required this.title,
    this.error,
    this.onRetry,
    this.icon,
    this.retryLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 48, color: Colors.redAccent),
            const SizedBox(height: 8),
          ],
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          if (error != null)
            Text(
              error is LocalizedError
                  ? (error as LocalizedError).localized(context.l10n)
                  : '$error',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red),
            ),
          const SizedBox(height: 12),
          if (onRetry != null)
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(retryLabel ?? context.l10n.commonTryAgain),
            ),
        ],
      ),
    );
  }
}
