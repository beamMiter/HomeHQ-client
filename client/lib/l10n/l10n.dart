import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';

import 'app_localizations.dart';

export 'app_localizations.dart';

/// Thai is the app's home language, so it is what we fall back to when the
/// device asks for something we don't have.
const kFallbackLocale = Locale('th');

/// Languages the app ships. Order matters for the language picker.
const kAppLocales = <Locale>[Locale('th'), Locale('en')];

/// Picks the app locale for a device that lists [deviceLocales] in order of
/// preference: the first one we support, else [kFallbackLocale].
Locale resolveAppLocale(Iterable<Locale>? deviceLocales) {
  for (final l in deviceLocales ?? const <Locale>[]) {
    for (final s in kAppLocales) {
      if (s.languageCode == l.languageCode) return s;
    }
  }
  return kFallbackLocale;
}

/// Strings for [chosen] (null = follow the device).
///
/// For code with no [BuildContext]: providers, repositories, interceptors.
/// Widgets should use `context.l10n`, which also rebuilds on a language change.
AppLocalizations l10nFor(Locale? chosen) => lookupAppLocalizations(
  chosen ?? resolveAppLocale(ui.PlatformDispatcher.instance.locales),
);

/// An error whose message depends on the app language.
///
/// `toString()` can't know the language, so the UI asks this instead (see
/// `ErrorState`).
abstract interface class LocalizedError {
  String localized(AppLocalizations l10n);
}

extension AppL10nContext on BuildContext {
  /// The app's strings in the current language.
  ///
  /// Falls back to Thai when the tree has no localization delegates (a bare
  /// widget under test), so such trees keep working.
  AppLocalizations get l10n =>
      AppLocalizations.of(this) ?? lookupAppLocalizations(kFallbackLocale);
}
