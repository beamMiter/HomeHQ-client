import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:video_player/video_player.dart';

import '../l10n/l10n.dart';
import '../models/home_camera.dart';
import '../repositories/cameras_repository.dart';
import '../shared/app_colors.dart';
import '../state/cameras_provider.dart';
import '../state/screen_awake.dart';
import '../utils/app_orientation.dart';
import '../widgets/cameras/camera_strip.dart';
import '../widgets/cameras/camera_switches.dart';
import '../widgets/cameras/ptz_pad.dart';
import '../widgets/toast.dart';
import 'cameras_screen.dart' show cameraErrorText;

/// Plays cameras live, one at a time, and lets you move between them.
///
///  * swipe left/right (or tap the strip) to change camera without going back;
///  * hold a direction to turn a camera that can turn;
///  * switch the camera's own privacy / motion / person detection;
///  * full screen for a bigger picture.
///
/// Only the camera on screen is streamed; the others show their last still
/// picture. It stops by itself after [idleLimit]: a stream left open drains the
/// battery and the account's allowance while nobody watches.
///
/// While a picture is playing the phone is kept from auto-locking. When the
/// app leaves the foreground (screen locked, another app) the stream is
/// closed, and a fresh one is opened on return: a stream held across a sleep
/// is stale, which is what used to leave a frozen picture behind.
class CameraPlayerScreen extends ConsumerStatefulWidget {
  const CameraPlayerScreen({
    super.key,
    required this.id,
    this.camera,
    this.idleLimit = const Duration(minutes: 5),
  });

  final String id;

  /// What the grid already knew; used until the list is loaded.
  final HomeCamera? camera;
  final Duration idleLimit;

  @override
  ConsumerState<CameraPlayerScreen> createState() => _CameraPlayerScreenState();
}

class _CameraPlayerScreenState extends ConsumerState<CameraPlayerScreen>
    with WidgetsBindingObserver {
  late String _currentId = widget.id;
  late final PageController _pages;

  VideoPlayerController? _controller;
  String _quality = 'hd';
  bool _muted = false;
  bool _starting = true;
  bool _pausedIdle = false;
  bool _fullscreen = false;
  Object? _error;
  Timer? _idle;
  int _openToken = 0;

  // PTZ: a hold is "move for a while, repeat while held, stop on release".
  Timer? _ptzRepeat;
  bool _ptzHeld = false;
  Future<void> _ptzQueue = Future.value();

  // Kept as fields because a "stop" is sent while the screen is being torn
  // down, when reading `ref` or `context` is no longer allowed.
  late final CamerasRepository _repo;
  late final ScreenAwake _awake;
  AppLocalizations _l10n = l10nFor(null);

  /// True while the app is in the background and the stream is closed.
  bool _suspended = false;

  @override
  void initState() {
    super.initState();
    _repo = ref.read(camerasRepoProvider);
    _awake = ref.read(screenAwakeProvider);
    WidgetsBinding.instance.addObserver(this);
    final pages = _pageList(ref.read(camerasProvider).value);
    final start = pages.indexWhere((c) => c.id == widget.id);
    _pages = PageController(initialPage: start < 0 ? 0 : start);
    _open(_currentId);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _awake.hold(false);
    _openToken++; // abandon anything still starting
    _idle?.cancel();
    _ptzRepeat?.cancel();
    if (_ptzHeld) _sendPtz(_currentId, 'stop');
    _controller?.dispose();
    _pages.dispose();
    _restorePortrait();
    super.dispose();
  }

  // ── leaving and returning to the app ─────────────────────────────────────

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.inactive:
        // A call, the control centre: the finger is gone, so stop turning.
        _stopPtz();
      case AppLifecycleState.hidden:
      case AppLifecycleState.paused:
        _suspend();
      case AppLifecycleState.resumed:
        _returnToForeground();
      case AppLifecycleState.detached:
        break;
    }
  }

  /// Closes the stream and lets the screen sleep.
  void _suspend() {
    if (_suspended) return;
    _suspended = true;
    _openToken++; // abandon an open still in flight
    _idle?.cancel();
    _stopPtz();
    _awake.hold(false);
    final c = _controller;
    _controller = null;
    c?.dispose();
    if (mounted) {
      setState(() {
        _starting = true; // "connecting" is what greets the return
        _error = null;
        _pausedIdle = false;
      });
    }
  }

  void _returnToForeground() {
    if (!_suspended) return;
    _suspended = false;
    if (!mounted) return;
    // The still picture is old too.
    ref.invalidate(cameraSnapshotProvider(_currentId));
    _open(_currentId);
  }

  // ── what to show ─────────────────────────────────────────────────────────

  /// The cameras that can be swiped between: the online ones.
  List<HomeCamera> _pageList(List<HomeCamera>? all) {
    final online = (all ?? const <HomeCamera>[]).where((c) => c.online);
    if (online.any((c) => c.id == _currentId)) return online.toList();
    final seed =
        widget.camera ??
        HomeCamera(id: widget.id, name: widget.id, online: true);
    return [seed, ...online.where((c) => c.id != seed.id)];
  }

  HomeCamera _current(List<HomeCamera> pages) => pages.firstWhere(
    (c) => c.id == _currentId,
    orElse: () => pages.isNotEmpty
        ? pages.first
        : HomeCamera(id: _currentId, name: _currentId, online: true),
  );

  // ── playback ─────────────────────────────────────────────────────────────

  Future<void> _open(String id) async {
    final token = ++_openToken;
    final old = _controller;
    _idle?.cancel();
    setState(() {
      _controller = null;
      _starting = true;
      _error = null;
      _pausedIdle = false;
    });
    await old?.dispose();

    VideoPlayerController? c;
    try {
      final key = (id: id, quality: _quality);
      // Always a fresh address: a stale one is why people press retry.
      ref.invalidate(cameraLiveProvider(key));
      final live = await ref.read(cameraLiveProvider(key).future);
      if (token != _openToken || !mounted) return;

      c = ref.read(videoControllerFactoryProvider)(Uri.parse(live.url));
      await c.initialize();
      if (token != _openToken || !mounted) {
        await c.dispose();
        return;
      }
      await c.setVolume(_muted ? 0 : 1);
      await c.play();
      if (token != _openToken || !mounted) {
        await c.dispose();
        return;
      }
      setState(() {
        _controller = c;
        _starting = false;
      });
      _awake.hold(true);
      _idle = Timer(widget.idleLimit, _pauseForIdle);
    } catch (e) {
      await c?.dispose();
      if (token != _openToken || !mounted) return;
      _awake.hold(false);
      setState(() {
        _error = e;
        _starting = false;
      });
    }
  }

  void _pauseForIdle() {
    _controller?.pause();
    _awake.hold(false); // nobody is watching: let the phone sleep
    if (mounted) setState(() => _pausedIdle = true);
  }

  void _resume() {
    _controller?.play();
    _awake.hold(true);
    setState(() => _pausedIdle = false);
    _idle?.cancel();
    _idle = Timer(widget.idleLimit, _pauseForIdle);
  }

  void _toggleMute() {
    setState(() => _muted = !_muted);
    _controller?.setVolume(_muted ? 0 : 1);
  }

  Future<void> _toggleLight(String id, bool on) async {
    final l10n = _l10n;
    try {
      await ref.read(cameraSwitchesProvider(id).notifier).set('light', on);
    } catch (_) {
      AppToast.error(l10n.camSwitchFailed);
    }
  }

  void _setQuality(String q) {
    if (q == _quality) return;
    _quality = q;
    _open(_currentId);
  }

  // ── changing camera ──────────────────────────────────────────────────────

  void _onPageChanged(List<HomeCamera> pages, int i) {
    if (i < 0 || i >= pages.length) return;
    final id = pages[i].id;
    if (id == _currentId) return;
    _stopPtz();
    HapticFeedback.selectionClick();
    setState(() => _currentId = id);
    _open(id);
  }

  void _jumpTo(List<HomeCamera> pages, HomeCamera cam) {
    if (!cam.online) {
      AppToast.info(context.l10n.camOfflineToast);
      return;
    }
    final i = pages.indexWhere((c) => c.id == cam.id);
    if (i < 0 || !_pages.hasClients) return;
    _pages.animateToPage(
      i,
      duration: const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
    );
  }

  // ── turning the camera ───────────────────────────────────────────────────

  void _startPtz(String action) {
    final id = _currentId;
    _ptzHeld = true;
    _sendPtz(id, action, durationMs: 1500);
    _ptzRepeat?.cancel();
    // Re-issue a little before the previous move would run out.
    _ptzRepeat = Timer.periodic(
      const Duration(milliseconds: 1300),
      (_) => _sendPtz(id, action, durationMs: 1500),
    );
  }

  void _stopPtz() {
    _ptzRepeat?.cancel();
    if (!_ptzHeld) return;
    _ptzHeld = false;
    _sendPtz(_currentId, 'stop');
  }

  /// Sends in order: a "stop" must never overtake the "move" before it.
  void _sendPtz(String id, String action, {int? durationMs}) {
    final repo = _repo;
    final l10n = _l10n;
    _ptzQueue = _ptzQueue.then((_) async {
      try {
        await repo.ptz(id, action, durationMs: durationMs);
      } catch (e) {
        AppToast.error(
          e is Exception ? cameraErrorText(l10n, e) : l10n.camPtzFailed,
        );
      }
    });
  }

  // ── full screen ──────────────────────────────────────────────────────────

  /// Leaving the player: back to the app's own orientation (portrait), asked
  /// for by name so a screen still showing landscape turns upright.
  void _restorePortrait() {
    try {
      AppOrientation.portrait();
    } catch (_) {}
  }

  void _enterFullscreen() {
    if (_fullscreen) return;
    setState(() => _fullscreen = true);
    _applyFullscreen(true);
  }

  /// Leaves full screen and turns the picture back upright. Always sends the
  /// orientation, even if we didn't force it: the phone may be lying in
  /// landscape because the user turned it.
  void _exitFullscreen() {
    if (_fullscreen) setState(() => _fullscreen = false);
    _applyFullscreen(false);
  }

  void _applyFullscreen(bool on) {
    try {
      if (on) {
        AppOrientation.landscape();
      } else {
        AppOrientation.portrait();
      }
    } catch (_) {
      // Not supported where it isn't (tests, desktop): the layout still works.
    }
  }

  void _goBack() {
    if (_fullscreen) {
      _exitFullscreen();
      return;
    }
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/cameras');
    }
  }

  // ── build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    _l10n = l10n;
    final all = ref.watch(camerasProvider).value;
    final pages = _pageList(all);
    final current = _current(pages);
    final index = pages.indexWhere((c) => c.id == _currentId);

    // The list can arrive (or change) after we opened: keep the page in step.
    if (index >= 0 && _pages.hasClients) {
      final shown = _pages.page?.round();
      if (shown != null && shown != index) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _pages.hasClients) _pages.jumpToPage(index);
        });
      }
    }

    final stage = _Stage(
      pages: pages,
      controller: _pages,
      currentId: _currentId,
      video: _controller,
      starting: _starting,
      error: _error,
      pausedIdle: _pausedIdle,
      onPageChanged: (i) => _onPageChanged(pages, i),
      onRetry: () => _open(_currentId),
      onResume: _resume,
    );

    final hasLight = current.switches.contains('light');
    final lightOn = hasLight
        ? (ref.watch(cameraSwitchesProvider(current.id)).value?['light'] ??
              false)
        : false;

    // Wide layout whenever the screen is wider than tall: forced by us (full
    // screen) or because the phone itself is turned. The portrait layout
    // (picture on top, panel below) does not fit a landscape screen.
    final landscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final wide = _fullscreen || landscape;

    final overlay = _TopBar(
      title: current.name,
      lightOn: hasLight ? lightOn : null,
      onLight: hasLight ? () => _toggleLight(current.id, !lightOn) : null,
      position: pages.length > 1 && index >= 0
          ? l10n.camPosition(index + 1, pages.length)
          : null,
      quality: _quality,
      muted: _muted,
      fullscreen: wide,
      onBack: _goBack,
      onQuality: _setQuality,
      onMute: _toggleMute,
      onFullscreen: () => wide ? _exitFullscreen() : _enterFullscreen(),
    );

    final live =
        _controller != null && !_starting && _error == null && !_pausedIdle;

    final video = AspectRatio(
      aspectRatio: 16 / 9,
      child: Stack(
        fit: StackFit.expand,
        children: [
          stage,
          Positioned(top: 0, left: 0, right: 0, child: overlay),
          if (live) const Positioned(left: 12, bottom: 12, child: _LiveBadge()),
          if (pages.length > 1)
            Positioned(
              bottom: 12,
              left: 0,
              right: 0,
              child: _Dots(count: pages.length, index: index < 0 ? 0 : index),
            ),
        ],
      ),
    );

    if (wide) {
      return PopScope(
        // Back leaves full screen first; from a phone merely turned sideways
        // it leaves the screen like normal.
        canPop: !_fullscreen,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _goBack();
        },
        child: Scaffold(
          backgroundColor: Colors.black,
          // Keeps the controls clear of the notch and the home indicator; the
          // picture just letterboxes in what is left.
          body: SafeArea(
            child: Stack(
              fit: StackFit.expand,
              children: [
                Center(child: video),
                if (current.ptz)
                  Positioned(
                    right: 16,
                    bottom: 16,
                    child: PtzPad(
                      compact: true,
                      onDark: true,
                      zoom: current.zoom,
                      onStart: _startPtz,
                      onStop: _stopPtz,
                    ),
                  ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            video,
            Expanded(
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                child: ColoredBox(
                  color: AppColors.bgSoft,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
                    children: [
                      if (pages.length > 1 || (all?.length ?? 0) > 1) ...[
                        _SectionTitle(l10n.camCameras),
                        const SizedBox(height: 8),
                        CameraStrip(
                          cameras: all ?? pages,
                          currentId: _currentId,
                          onSelect: (c) => _jumpTo(pages, c),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.camSwipeHint,
                          style: const TextStyle(
                            color: AppColors.textMuted,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                      ],
                      if (current.ptz) ...[
                        _Card(
                          title: l10n.camPtzTitle,
                          subtitle: l10n.camPtzHint,
                          child: Center(
                            child: PtzPad(
                              zoom: current.zoom,
                              onStart: _startPtz,
                              onStop: _stopPtz,
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],
                      if (current.switches.isNotEmpty)
                        _Card(
                          title: l10n.camSettingsTitle,
                          child: CameraSwitches(
                            key: ValueKey('switches-${current.id}'),
                            camera: current,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── pieces ───────────────────────────────────────────────────────────────────

/// The swipeable picture area. Only the current page plays; the rest show
/// their still picture, so a swipe always has something to slide.
class _Stage extends ConsumerWidget {
  const _Stage({
    required this.pages,
    required this.controller,
    required this.currentId,
    required this.video,
    required this.starting,
    required this.error,
    required this.pausedIdle,
    required this.onPageChanged,
    required this.onRetry,
    required this.onResume,
  });

  final List<HomeCamera> pages;
  final PageController controller;
  final String currentId;
  final VideoPlayerController? video;
  final bool starting;
  final Object? error;
  final bool pausedIdle;
  final ValueChanged<int> onPageChanged;
  final VoidCallback onRetry;
  final VoidCallback onResume;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return PageView.builder(
      controller: controller,
      itemCount: pages.length,
      onPageChanged: onPageChanged,
      itemBuilder: (context, i) {
        final cam = pages[i];
        final active = cam.id == currentId;
        final v = video;

        return Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Color(0xFF0B0F1A)),
            // The still picture, until (and under) the live one.
            _Poster(id: cam.id),
            if (active && v != null && v.value.isInitialized)
              Center(
                child: AspectRatio(
                  aspectRatio: v.value.aspectRatio == 0
                      ? 16 / 9
                      : v.value.aspectRatio,
                  child: VideoPlayer(v),
                ),
              ),
            if (active && starting)
              _Overlay(text: l10n.camConnecting, busy: true),
            if (active && error != null)
              _Overlay(
                icon: Icons.videocam_off_rounded,
                text:
                    error is Exception &&
                        cameraErrorText(l10n, error) != l10n.camErrUnavailable
                    ? cameraErrorText(l10n, error)
                    : l10n.camPlayerFailed,
                actionLabel: l10n.commonTryAgain,
                onAction: onRetry,
              ),
            if (active && pausedIdle)
              _Overlay(
                icon: Icons.pause_circle_outline_rounded,
                text: l10n.camPausedIdle,
                actionLabel: l10n.camResume,
                onAction: onResume,
              ),
          ],
        );
      },
    );
  }
}

class _Poster extends ConsumerWidget {
  const _Poster({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bytes = ref.watch(cameraSnapshotProvider(id)).value;
    if (bytes == null) return const SizedBox.shrink();
    return Image.memory(
      bytes,
      fit: BoxFit.cover,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.title,
    required this.position,
    required this.quality,
    required this.muted,
    required this.fullscreen,
    required this.onBack,
    required this.onQuality,
    required this.onMute,
    required this.onFullscreen,
    this.lightOn,
    this.onLight,
  });

  /// Null when the camera has no light of its own.
  final bool? lightOn;
  final VoidCallback? onLight;

  final String title;
  final String? position;
  final String quality;
  final bool muted;
  final bool fullscreen;
  final VoidCallback onBack;
  final ValueChanged<String> onQuality;
  final VoidCallback onMute;
  final VoidCallback onFullscreen;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 18),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black87, Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: l10n.commonBack,
            color: Colors.white,
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                    fontSize: 16,
                  ),
                ),
                if (position != null)
                  Text(
                    position!,
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            tooltip: l10n.camQuality,
            initialValue: quality,
            onSelected: onQuality,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'hd', child: Text('HD')),
              PopupMenuItem(value: 'sd', child: Text('SD')),
            ],
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white54),
              ),
              child: Text(
                quality.toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                  fontSize: 12,
                ),
              ),
            ),
          ),
          if (lightOn != null)
            IconButton(
              tooltip: l10n.camSwitchLight,
              color: lightOn! ? const Color(0xFF7DD3FC) : Colors.white,
              onPressed: onLight,
              icon: Icon(
                lightOn!
                    ? Icons.lightbulb_rounded
                    : Icons.lightbulb_outline_rounded,
              ),
            ),
          IconButton(
            tooltip: muted ? l10n.camUnmute : l10n.camMute,
            color: Colors.white,
            onPressed: onMute,
            icon: Icon(
              muted ? Icons.volume_off_rounded : Icons.volume_up_rounded,
            ),
          ),
          IconButton(
            tooltip: fullscreen ? l10n.camExitFullscreen : l10n.camFullscreen,
            color: Colors.white,
            onPressed: onFullscreen,
            icon: Icon(
              fullscreen
                  ? Icons.fullscreen_exit_rounded
                  : Icons.fullscreen_rounded,
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});
  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 18 : 6,
            height: 6,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: i == index ? Colors.white : Colors.white54,
            ),
          ),
      ],
    );
  }
}

class _LiveBadge extends StatelessWidget {
  const _LiveBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.softBlue,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        context.l10n.camLive,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11.5,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(
      fontWeight: FontWeight.w800,
      fontSize: 15,
      color: AppColors.deepNavy,
    ),
  );
}

class _Card extends StatelessWidget {
  const _Card({required this.title, required this.child, this.subtitle});
  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // A Material, not a coloured box: the switches inside paint their ink on
    // the nearest Material, and a box in between would hide it.
    return Material(
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionTitle(title),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle!,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 12.5,
                ),
              ),
            ],
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}

class _Overlay extends StatelessWidget {
  const _Overlay({
    required this.text,
    this.icon,
    this.busy = false,
    this.actionLabel,
    this.onAction,
  });

  final String text;

  /// A camera (or a pause) above the words, so the state reads at a glance.
  final IconData? icon;
  final bool busy;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.black54,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 44, color: Colors.white70),
              const SizedBox(height: 12),
            ],
            if (busy)
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            if (busy) const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                text,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
            ),
            if (actionLabel != null) ...[
              const SizedBox(height: 10),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.softBlue,
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
