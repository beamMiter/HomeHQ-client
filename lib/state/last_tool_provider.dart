import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'locale_provider.dart' show sharedPreferencesProvider;

/// The route of the Home tool the user opened last, so Home can point it out.
/// Saved across launches when shared preferences are available.
class LastToolController extends Notifier<String?> {
  static const _key = 'home_last_tool';

  @override
  String? build() => ref.read(sharedPreferencesProvider)?.getString(_key);

  Future<void> opened(String route) async {
    state = route;
    await ref.read(sharedPreferencesProvider)?.setString(_key, route);
  }
}

final lastToolProvider = NotifierProvider<LastToolController, String?>(
  LastToolController.new,
);
