import 'dart:async';
import 'dart:isolate';
import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'l10n/l10n.dart';
import 'router.dart';
import 'state/auth_state.dart';
import 'state/locale_provider.dart';
import 'utils/app_orientation.dart';
import 'state/toast_boundary.dart';
import 'widgets/toast.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Every screen is laid out for portrait; only camera full screen turns.
  AppOrientation.lockPortrait();

  FlutterError.onError = (FlutterErrorDetails details) {
    FlutterError.dumpErrorToConsole(details);
    if (kDebugMode) debugPrint('🛑 [flutter] ${details.exception}');
  };

  PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
    if (kDebugMode) debugPrint('🛑 [platform] $error');
    return true;
  };

  try {
    await dotenv.load(fileName: '.env.development');
    if (kDebugMode) debugPrint('✅ dotenv loaded');
  } catch (e) {
    if (kDebugMode) debugPrint('⚠️ dotenv load failed: $e');
  }

  // Saved language choice, and the date symbols for the languages we ship.
  final prefs = await SharedPreferences.getInstance();
  for (final l in kAppLocales) {
    await initializeDateFormatting(l.languageCode);
  }

  Isolate.current.addErrorListener(
    RawReceivePort((dynamic pair) {
      final List<dynamic> errorAndStack = pair as List<dynamic>;
      if (kDebugMode) debugPrint('🧨 [isolate] ${errorAndStack.first}');
    }).sendPort,
  );

  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const HomeHqApp(),
    ),
  );
}

class HomeHqApp extends ConsumerWidget {
  const HomeHqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(authProvider);
    ref.watch(toastAuthBoundaryProvider); // clears toasts on login/logout
    ref.watch(intlDefaultLocaleProvider); // date formats follow the language
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Home Service',
      // null = follow the device; see resolveAppLocale for the fallback.
      locale: ref.watch(localeProvider),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
      scaffoldMessengerKey: AppToast.messengerKey,
      routerConfig: router,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xFF0B5ED7),
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          elevation: 0.5,
          centerTitle: true,
        ),
        textTheme: const TextTheme(
          bodyMedium: TextStyle(color: Colors.black87),
        ),
      ),
      builder: (context, child) {
        final media = MediaQuery.of(context);
        final baseScale = media.textScaler.scale(1.0);
        final clampedScale = baseScale.clamp(0.9, 1.2);
        return MediaQuery(
          data: media.copyWith(textScaler: TextScaler.linear(clampedScale)),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child:
                child ??
                const Scaffold(body: Center(child: Text('❌ Page not found'))),
          ),
        );
      },
    );
  }
}
