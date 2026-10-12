import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/l10n.dart';
import '../state/locale_provider.dart';
import 'page_loading.dart';
import 'toast.dart';

/// Shared "reload this screen" pieces, so every feature refreshes the same way.
///
/// A Riverpod refresh keeps the old data on screen while the new request is in
/// flight. That is right for pull-to-refresh (the pull indicator is the
/// progress), but for the refresh *button* it meant nothing visibly changed
/// and the button looked dead. So a button press puts the page-loading spinner
/// over the content for a moment, then reports the outcome.

/// An [AsyncValue] that already has something to show and is fetching again.
/// The first load is not this: the screen has its own full-page loader for it.
extension RefreshingAsync<T> on AsyncValue<T> {
  bool get isReloadingData => isLoading && (hasValue || hasError);
}

/// App-bar refresh action. While [busy] it is disabled, so a second press
/// can't start a second request. It deliberately shows no spinner of its own:
/// the one loading indicator is the page loader in the middle of the screen.
class RefreshButton extends StatelessWidget {
  const RefreshButton({super.key, required this.onPressed, this.busy = false});

  final VoidCallback onPressed;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: context.l10n.refreshTooltip,
      onPressed: busy ? null : onPressed,
      icon: const Icon(Icons.refresh),
    );
  }
}

/// Pull-to-refresh handler. Waits for the real request, so the pull indicator
/// stays exactly as long as the fetch. A failure is not rethrown: the
/// provider ends in an error state that the screen already renders.
Future<void> pullRefresh(Future<Object?> Function() refetch) async {
  try {
    await refetch();
  } catch (_) {}
}

/// Shortest time the page-loading spinner stays up after a button press, so a
/// request that answers in 50 ms still reads as "it reloaded" and not as a
/// flicker.
const kMinReloadLoader = Duration(milliseconds: 400);

/// Which screens are currently showing the button-triggered loading page,
/// by key (e.g. 'bills'). One provider so plain `ConsumerWidget`s can use it
/// too, without owning a flag.
class _Reloading extends Notifier<Set<String>> {
  @override
  Set<String> build() => const {};

  void start(String key) => state = {...state, key};
  void stop(String key) => state = {...state}..remove(key);
}

final _reloadingProvider = NotifierProvider<_Reloading, Set<String>>(
  _Reloading.new,
);

/// Whether the button-triggered reload for [key] is running. Watch it in
/// `build` and hand it to [ReloadOverlay].
bool watchReloading(WidgetRef ref, String key) =>
    ref.watch(_reloadingProvider.select((s) => s.contains(key)));

/// Button refresh: shows the loading page for [key], waits for the real
/// request (and at least [kMinReloadLoader]), then toasts the outcome.
Future<void> runReload(
  WidgetRef ref,
  String key,
  Future<Object?> Function() refetch,
) async {
  final reloading = ref.read(_reloadingProvider.notifier);
  final l10n = l10nFor(ref.read(localeProvider));
  if (ref.read(_reloadingProvider).contains(key)) return; // already running
  reloading.start(key);
  try {
    await Future.wait<Object?>([
      refetch(),
      Future<void>.delayed(kMinReloadLoader),
    ]);
    AppToast.success(l10n.refreshDone);
  } catch (_) {
    AppToast.error(l10n.refreshFailed);
  } finally {
    // The notifier was captured before the await: the screen may be gone.
    reloading.stop(key);
  }
}

/// Covers [child] with the page-loading spinner while [active]. The content
/// underneath stays mounted, so the scroll position and typed text survive.
class ReloadOverlay extends StatelessWidget {
  const ReloadOverlay({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        child,
        if (active)
          Positioned.fill(
            // Opaque enough to read as a loading page, and it also swallows
            // taps, so nothing can be pressed on stale content meanwhile.
            child: ColoredBox(
              color: Theme.of(
                context,
              ).scaffoldBackgroundColor.withValues(alpha: 0.95),
              child: const PageLoading(),
            ),
          ),
      ],
    );
  }
}

/// Lets a non-list state (empty, error) be pulled down to refresh.
///
/// A [RefreshIndicator] only reacts to something scrollable, and an "empty"
/// or "error" message is not, so pulling there did nothing. This makes the
/// message fill the viewport inside an always-scrollable view.
class RefreshableFill extends StatelessWidget {
  const RefreshableFill({
    super.key,
    required this.onRefresh,
    required this.child,
  });

  final Future<void> Function() onRefresh;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: onRefresh,
      child: LayoutBuilder(
        builder: (context, box) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: box.maxHeight),
            child: Center(child: child),
          ),
        ),
      ),
    );
  }
}
