import 'dart:ui';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../l10n/l10n.dart';

/// Set in `main()`. Null (e.g. in tests) just means the choice isn't saved.
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) => null);

/// The language the user picked, or null to follow the device.
class LocaleController extends Notifier<Locale?> {
  static const _key = 'app_locale';

  @override
  Locale? build() {
    final code = ref.read(sharedPreferencesProvider)?.getString(_key);
    for (final l in kAppLocales) {
      if (l.languageCode == code) return l;
    }
    return null;
  }

  /// Picks a language, or [null] for "same as the device". Saved for next time.
  Future<void> select(Locale? locale) async {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (prefs == null) return;
    if (locale == null) {
      await prefs.remove(_key);
    } else {
      await prefs.setString(_key, locale.languageCode);
    }
  }
}

final localeProvider = NotifierProvider<LocaleController, Locale?>(
  LocaleController.new,
);

/// The language actually in effect: the choice, else what the device asks for.
final effectiveLocaleProvider = Provider<Locale>(
  (ref) =>
      ref.watch(localeProvider) ??
      resolveAppLocale(PlatformDispatcher.instance.locales),
);

/// Keeps `DateFormat('d MMM yyyy')` and friends (which read the process-wide
/// default) in step with the app language. Watch it once, at the root.
final intlDefaultLocaleProvider = Provider<void>((ref) {
  Intl.defaultLocale = ref.watch(effectiveLocaleProvider).languageCode;
});
