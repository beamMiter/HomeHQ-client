import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/appliance.dart';
import '../repositories/appliances_repository.dart';
import '../services/api_client.dart' show apiClientProvider;

final appliancesRepoProvider = Provider<AppliancesRepository>(
  (ref) => AppliancesRepository(ref.watch(apiClientProvider).dio),
);

/// Whether the server has an appliance source. Costs no vendor call. Null
/// when the server can't be asked.
final appliancesStatusProvider = FutureProvider.autoDispose<AppliancesStatus?>(
  (ref) => ref.watch(appliancesRepoProvider).status(),
);

/// The clock the appliance screens read "checked 10 s ago" against. A
/// provider so a test can set the time.
final appliancesClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

/// How fresh the appliance list is.
class ApplianceSync {
  const ApplianceSync({this.checkedAt, this.failing = false});

  /// When the app last got the list from the server (the app's own clock).
  final DateTime? checkedAt;

  /// The last try to check failed: what is shown is what was known at
  /// [checkedAt].
  final bool failing;
}

class ApplianceSyncNotifier extends Notifier<ApplianceSync> {
  @override
  ApplianceSync build() => const ApplianceSync();

  void checked(DateTime at) => state = ApplianceSync(checkedAt: at);
  void failed() =>
      state = ApplianceSync(checkedAt: state.checkedAt, failing: true);
}

final applianceSyncProvider =
    NotifierProvider<ApplianceSyncNotifier, ApplianceSync>(
      ApplianceSyncNotifier.new,
    );

/// The appliances, with their current state.
///
/// The screens that show them keep them fresh (see ApplianceLiveUpdates):
/// someone else may switch one, or the server's safety switch-off may fire.
/// A check that fails keeps what was known on screen and says so, rather than
/// blanking the page.
class AppliancesNotifier extends AsyncNotifier<List<Appliance>> {
  /// Commands on their way, by appliance: a check landing meanwhile must not
  /// put back the state from before the command.
  final Map<String, int> _inFlight = {};

  @override
  Future<List<Appliance>> build() async {
    final items = await ref.watch(appliancesRepoProvider).list();
    _checked();
    return items;
  }

  void _checked() => ref
      .read(applianceSyncProvider.notifier)
      .checked(ref.read(appliancesClockProvider)());

  /// Asks the server for fresh data (skipping its cache). A failure keeps the
  /// list on screen (marked as not up to date) and is rethrown.
  Future<void> reload() async {
    final repo = ref.read(appliancesRepoProvider);
    try {
      final items = await repo.list(refresh: true);
      if (!ref.mounted) return;
      state = AsyncData(_keepInFlight(items));
      _checked();
    } catch (e, st) {
      if (!ref.mounted) rethrow;
      if (state.hasValue) {
        ref.read(applianceSyncProvider.notifier).failed();
      } else {
        state = AsyncError(e, st);
      }
      rethrow;
    }
  }

  /// A check in the background: never throws, never blanks the list.
  Future<void> check() async {
    if (!state.hasValue) return;
    try {
      final items = await ref.read(appliancesRepoProvider).list();
      if (!ref.mounted) return;
      state = AsyncData(_keepInFlight(items));
      _checked();
    } catch (_) {
      if (ref.mounted) ref.read(applianceSyncProvider.notifier).failed();
    }
  }

  /// [fresh] from the server, except appliances with a command on its way,
  /// which keep what the app is showing for them.
  List<Appliance> _keepInFlight(List<Appliance> fresh) {
    if (_inFlight.isEmpty) return fresh;
    final shown = {for (final a in state.value ?? const <Appliance>[]) a.id: a};
    return [
      for (final a in fresh)
        if (_inFlight.containsKey(a.id) && shown[a.id] != null)
          shown[a.id]!
        else
          a,
    ];
  }

  /// Adds an appliance and shows it at once. Throws what the server refused.
  Future<Appliance> add({
    required String name,
    required String kind,
    String? room,
    String? brand,
    String? model,
  }) async {
    final made = await ref
        .read(appliancesRepoProvider)
        .add(name: name, kind: kind, room: room, brand: brand, model: model);
    if (ref.mounted) {
      state = AsyncData([...?state.value, made]);
    }
    return made;
  }

  /// Removes an appliance and drops it from the list at once.
  Future<void> remove(String id) async {
    await ref.read(appliancesRepoProvider).remove(id);
    if (ref.mounted) {
      state = AsyncData([
        for (final a in state.value ?? const <Appliance>[])
          if (a.id != id) a,
      ]);
    }
  }

  /// Sets one capability.
  ///
  /// Shows [value] at once (a power command shows as "switching" until the
  /// server answers), sends it, then shows what the appliance reports back,
  /// marked unconfirmed when it could not be read back. If it fails the
  /// appliance goes back to how it was and the error is rethrown for the
  /// screen to word. Afterwards the list is checked again, for the server's
  /// own account of it (since when, when it switches itself off).
  Future<void> command(String id, String capability, Object value) async {
    final current = state.value;
    if (current == null) return;
    final before = current.where((a) => a.id == id).firstOrNull;
    if (before == null) return;

    _inFlight[id] = (_inFlight[id] ?? 0) + 1;
    _put(id, (a) {
      final next = a.withState({...a.state, capability: value});
      return capability == Appliance.power && value is bool
          ? next.switching(value)
          : next;
    });
    try {
      final res = await ref
          .read(appliancesRepoProvider)
          .command(id, capability, value);
      if (!ref.mounted) return;
      _done(id);
      _put(
        id,
        (a) => a
            .withState({...a.state, ...res.state}, unconfirmed: !res.confirmed)
            .switching(null),
      );
      ref.invalidate(applianceEventsProvider(id));
      unawaited(check());
    } catch (_) {
      if (ref.mounted) {
        _done(id);
        _put(id, (_) => before);
      }
      rethrow;
    }
  }

  void _done(String id) {
    final n = (_inFlight[id] ?? 1) - 1;
    if (n <= 0) {
      _inFlight.remove(id);
    } else {
      _inFlight[id] = n;
    }
  }

  void _put(String id, Appliance Function(Appliance) change) {
    final list = state.value;
    if (list == null) return;
    state = AsyncData([for (final a in list) a.id == id ? change(a) : a]);
  }
}

final appliancesProvider =
    AsyncNotifierProvider.autoDispose<AppliancesNotifier, List<Appliance>>(
      AppliancesNotifier.new,
    );

/// The last few commands sent to one appliance.
final applianceEventsProvider = FutureProvider.autoDispose
    .family<List<ApplianceEvent>, String>(
      (ref, id) => ref.watch(appliancesRepoProvider).events(id),
    );
