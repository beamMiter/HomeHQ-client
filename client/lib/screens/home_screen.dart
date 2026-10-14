import 'package:flutter/gestures.dart' show kTouchSlop;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../l10n/friendly_error.dart';
import '../l10n/l10n.dart';
import '../models/home_camera.dart';
import '../models/weather.dart';
import '../shared/app_colors.dart';
import '../state/auth_state.dart';
import '../state/cameras_provider.dart';
import '../state/last_tool_provider.dart';
import '../state/location_controller.dart';
import '../state/weather_provider.dart';
import '../widgets/toast.dart';
import '../widgets/user_avatar.dart';

const _pageBackground = Color(0xFFF4F7FC);

// Every tool wears the brand colour; the icon tells them apart.
const _brand = AppColors.softBlue;

/// The greeting for an hour of the day (0–23).
@visibleForTesting
String homeGreeting(int hour, AppLocalizations l10n) {
  if (hour >= 5 && hour < 12) return l10n.homeGreetingMorning;
  if (hour >= 12 && hour < 17) return l10n.homeGreetingAfternoon;
  if (hour >= 17 && hour < 21) return l10n.homeGreetingEvening;
  return l10n.homeGreetingLate;
}

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(authProvider.select((s) => s.user?.name));

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // The header is dark, so the status bar icons go light.
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: _pageBackground,
        body: RefreshIndicator(
          color: AppColors.softBlue,
          backgroundColor: Colors.white,
          onRefresh: () async {
            // Re-check GPS first; weather rebuilds itself when the fix changes.
            ref.invalidate(camerasProvider);
            ref.invalidate(cameraSnapshotProvider);
            await ref.read(locationControllerProvider.notifier).refresh();
            ref.invalidate(currentWeatherProvider);
            await ref.read(currentWeatherProvider.future);
          },
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              _HomeHeader(name: name ?? ''),
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 24, 16, 32),
                child: _ToolsSection(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =====================  Header  =====================

class _HomeHeader extends StatelessWidget {
  const _HomeHeader({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final top = MediaQuery.paddingOf(context).top;
    final now = DateTime.now();
    final who = name.trim();

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A2147), AppColors.deepNavy, Color(0xFF2547C8)],
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(28)),
      ),
      child: Stack(
        children: [
          const Positioned(right: -60, top: -50, child: _Glow(size: 220)),
          Padding(
            padding: EdgeInsets.fromLTRB(20, top + 10, 12, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _AccountEntry(
                        name: who,
                        greeting: homeGreeting(now.hour, l10n),
                      ),
                    ),
                    IconButton(
                      tooltip: l10n.homeNotifications,
                      onPressed: () =>
                          AppToast.info(l10n.homeNotificationsSoon),
                      color: Colors.white,
                      icon: const Icon(Icons.notifications_none_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 26),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Entrance(
                    delay: .2,
                    child: _Weather(date: _dateLine(context, now)),
                  ),
                ),
                const SizedBox(height: 22),
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _LauncherSearch(
                    hintText: l10n.homeSearchHint,
                    onSubmit: (q) => _goTo(context, '/contractors', query: q),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The user's avatar, greeting and name; opens their Account page.
class _AccountEntry extends StatelessWidget {
  const _AccountEntry({required this.name, required this.greeting});
  final String name;
  final String greeting;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        button: true,
        label: context.l10n.accountOpen,
        child: Tooltip(
          message: context.l10n.accountOpen,
          child: InkWell(
            onTap: () => context.push('/account'),
            customBorder: const StadiumBorder(),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 10, 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UserAvatar(name: name, size: 46, onDark: true),
                  const SizedBox(width: 12),
                  Flexible(
                    child: _Entrance(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            greeting,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: .75),
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          if (name.isNotEmpty)
                            Text(
                              name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 19,
                                height: 1.3,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.white.withValues(alpha: .6),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

String _dateLine(BuildContext context, DateTime now) {
  final locale = Localizations.localeOf(context).toString();
  try {
    return DateFormat.MMMMEEEEd(locale).format(now);
  } catch (_) {
    // Date symbols for this language are not loaded (only happens in tests).
    return DateFormat.MMMMEEEEd().format(now);
  }
}

void _goTo(BuildContext context, String route, {String? query}) {
  final uri = Uri(
    path: route,
    queryParameters: {
      if (query != null && query.trim().isNotEmpty) 'q': query.trim(),
    },
  ).toString();
  context.push(uri);
}

/// A soft circle of light behind the header content.
class _Glow extends StatelessWidget {
  const _Glow({required this.size});
  final double size;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.white.withValues(alpha: .06),
        ),
      ),
    );
  }
}

// =====================  Weather  =====================

/// What the weather looks like, as an icon.
IconData _conditionIcon(WeatherCondition c) => switch (c) {
  WeatherCondition.clear => Icons.wb_sunny_rounded,
  WeatherCondition.partlyCloudy => Icons.wb_cloudy_rounded,
  WeatherCondition.fog => Icons.foggy,
  WeatherCondition.drizzle => Icons.grain_rounded,
  WeatherCondition.rain => Icons.water_drop_rounded,
  WeatherCondition.snow => Icons.ac_unit_rounded,
  WeatherCondition.thunderstorm => Icons.thunderstorm_rounded,
  WeatherCondition.unknown => Icons.cloud_queue_rounded,
};

String _conditionLabel(WeatherCondition c, AppLocalizations l10n) =>
    switch (c) {
      WeatherCondition.clear => l10n.weatherClear,
      WeatherCondition.partlyCloudy => l10n.weatherPartlyCloudy,
      WeatherCondition.fog => l10n.weatherFog,
      WeatherCondition.drizzle => l10n.weatherDrizzle,
      WeatherCondition.rain => l10n.weatherRain,
      WeatherCondition.snow => l10n.weatherSnow,
      WeatherCondition.thunderstorm => l10n.weatherThunderstorm,
      WeatherCondition.unknown => l10n.weatherUnknown,
    };

/// Today's weather, straight on the header: no box of its own.
class _Weather extends ConsumerWidget {
  const _Weather({required this.date});
  final String date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final weather = ref.watch(currentWeatherProvider);
    final muted = Colors.white.withValues(alpha: .7);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          date,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: muted, fontSize: 13),
        ),
        const SizedBox(height: 6),
        weather.when(
          loading: () => const SizedBox(
            height: 92,
            child: Align(
              alignment: Alignment.centerLeft,
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  color: Colors.white,
                ),
              ),
            ),
          ),
          error: (e, _) => Row(
            children: [
              const Icon(
                Icons.cloud_off_rounded,
                color: Colors.white,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.homeWeatherFailed,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      friendlyError(l10n, e),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(locationControllerProvider.notifier).refresh(),
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: Text(l10n.commonTryAgain),
              ),
            ],
          ),
          data: (w) => LayoutBuilder(
            builder: (context, box) {
              final width = box.maxWidth;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Big, but never more than half the row, so a narrow phone
                      // with large text shrinks it instead of overflowing.
                      ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: width * .5),
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: _CountUp(
                            value: w.temperature.round(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 56,
                              height: 1,
                              fontWeight: FontWeight.w200,
                              letterSpacing: -2,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          _conditionLabel(w.condition, l10n),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      _Pop(
                        child: Icon(
                          _conditionIcon(w.condition),
                          size: 52,
                          color: w.condition == WeatherCondition.clear
                              ? const Color(0xFFFFD166)
                              : Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 18,
                    runSpacing: 6,
                    children: [
                      _Fact(
                        icon: Icons.air_rounded,
                        text:
                            '${l10n.homeWind} ${w.windSpeed.toStringAsFixed(1)} m/s',
                      ),
                      _Fact(
                        icon: Icons.schedule_rounded,
                        text:
                            '${l10n.homeUpdated} ${DateFormat('HH:mm').format(w.time)}',
                      ),
                    ],
                  ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}

/// A small icon and text on the header; no background.
class _Fact extends StatelessWidget {
  const _Fact({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final color = Colors.white.withValues(alpha: .75);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 6),
        Text(text, style: TextStyle(color: color, fontSize: 13)),
      ],
    );
  }
}

// =====================  Search  =====================

class _LauncherSearch extends StatefulWidget {
  const _LauncherSearch({required this.hintText, required this.onSubmit});
  final String hintText;
  final void Function(String query) onSubmit;

  @override
  State<_LauncherSearch> createState() => _LauncherSearchState();
}

class _LauncherSearchState extends State<_LauncherSearch> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onSubmitted: widget.onSubmit,
      textInputAction: TextInputAction.search,
      style: const TextStyle(color: AppColors.textMain, fontSize: 15),
      decoration: InputDecoration(
        hintText: widget.hintText,
        hintStyle: const TextStyle(color: AppColors.textMuted, fontSize: 14),
        hintMaxLines: 1,
        prefixIcon: const Icon(Icons.search_rounded, color: AppColors.softBlue),
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide(
            color: Colors.white.withValues(alpha: .9),
            width: 2,
          ),
        ),
      ),
    );
  }
}

// =====================  Tools  =====================

class _ToolItem {
  final IconData icon;
  final String label;
  final String route;
  final String caption;
  const _ToolItem(this.icon, this.label, this.route, this.caption);
}

class _ToolsSection extends StatefulWidget {
  const _ToolsSection();

  @override
  State<_ToolsSection> createState() => _ToolsSectionState();
}

class _ToolsSectionState extends State<_ToolsSection>
    with SingleTickerProviderStateMixin {
  static const _count = 6;

  late final AnimationController _reveal = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 750),
  );

  /// One slice of the reveal per tile, so they come in one after another.
  late final List<CurvedAnimation> _slots = [
    for (var i = 0; i < _count; i++)
      CurvedAnimation(
        parent: _reveal,
        curve: Interval(
          i / _count * .55,
          i / _count * .55 + .45,
          curve: Curves.easeOutCubic,
        ),
      ),
  ];
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Tiles slide in one after another, once. Skipped when the system asks
    // for no animations.
    if (MediaQuery.disableAnimationsOf(context)) {
      _reveal.value = 1;
    } else {
      _reveal.forward();
    }
  }

  @override
  void dispose() {
    for (final s in _slots) {
      s.dispose();
    }
    _reveal.dispose();
    super.dispose();
  }

  /// Wraps tile [i] so it fades and rises in its own slice of the reveal.
  Widget _entrance(int i, Widget child) {
    final slot = _slots[i];
    return FadeTransition(
      opacity: slot,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, .14),
          end: Offset.zero,
        ).animate(slot),
        child: child,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The feature names stay in English in every language; only the
    // captions are translated.
    final cameras = _ToolItem(
      // A camera on a house: the home's cameras, not a video call.
      Icons.camera_outdoor_rounded,
      'Home Cameras',
      '/cameras',
      l10n.toolCamerasCaption,
    );
    final grid = <_ToolItem>[
      _ToolItem(
        Icons.handyman_rounded,
        'Contractors',
        '/contractors',
        l10n.toolContractorsCaption,
      ),
      _ToolItem(
        Icons.event_note_rounded,
        'Important Notes',
        '/notes',
        l10n.toolNotesCaption,
      ),
      _ToolItem(
        Icons.shopping_cart_checkout_rounded,
        'Purchases',
        '/purchases',
        l10n.toolPurchasesCaption,
      ),
      _ToolItem(
        Icons.receipt_long_rounded,
        'Bills',
        '/bills',
        l10n.toolBillsCaption,
      ),
    ];
    final medicine = _ToolItem(
      Icons.medical_services_rounded,
      'Medicine Stock',
      '/medicine',
      l10n.toolMedicineCaption,
    );

    Widget pair(int a) => IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _entrance(a, _ToolTile(item: grid[a - 1]))),
          const SizedBox(width: 12),
          Expanded(child: _entrance(a + 1, _ToolTile(item: grid[a]))),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 0, 4, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.homeToolsTitle,
                style: const TextStyle(
                  color: AppColors.deepNavy,
                  fontSize: 19,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.homeToolsSubtitle,
                style: const TextStyle(
                  color: AppColors.textMuted,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        _entrance(0, _CamerasTile(item: cameras)),
        const SizedBox(height: 12),
        pair(1),
        const SizedBox(height: 12),
        pair(3),
        const SizedBox(height: 12),
        _entrance(5, _ToolTile(item: medicine, wide: true)),
      ],
    );
  }
}

// One small corner for every tile: just enough to take the edge off. Nothing
// inside a tile has corners of its own (icons sit in circles), apart from the
// camera pictures, which use a smaller one still.
const _tileRadius = 10.0;

/// Touch feedback shared by every tile: it tilts toward the finger and sinks a
/// little, ticks, and ripples. [child] draws its own surface (on the nearest
/// Material).
class _Pressable extends StatefulWidget {
  const _Pressable({required this.onTap, required this.child});
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  /// Where the finger is, from (-1, -1) top-left to (1, 1) bottom-right;
  /// zero when nothing touches the tile.
  Offset _tilt = Offset.zero;
  bool _down = false;

  /// Where the finger came down; null once it has moved far enough to be a
  /// scroll rather than a press.
  Offset? _start;

  void _track(Offset local) {
    final size = context.size;
    if (size == null || size.isEmpty) return;
    setState(() {
      _tilt = Offset(
        (local.dx / size.width * 2 - 1).clamp(-1.0, 1.0),
        (local.dy / size.height * 2 - 1).clamp(-1.0, 1.0),
      );
    });
  }

  void _release() => setState(() {
    _down = false;
    _tilt = Offset.zero;
  });

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return Listener(
      onPointerDown: (e) {
        _start = e.localPosition;
        _down = true;
        _track(e.localPosition);
      },
      onPointerMove: (e) {
        final start = _start;
        if (start == null) return;
        // Past the touch slop the page is scrolling: let go of the tile
        // instead of dragging it along.
        if ((e.localPosition - start).distance > kTouchSlop) {
          _start = null;
          _release();
          return;
        }
        _track(e.localPosition);
      },
      onPointerUp: (_) {
        _start = null;
        _release();
      },
      onPointerCancel: (_) {
        _start = null;
        _release();
      },
      child: TweenAnimationBuilder<Offset>(
        tween: Tween(end: still ? Offset.zero : _tilt),
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOut,
        builder: (_, t, child) => Transform(
          alignment: Alignment.center,
          // A little perspective, then lean away from the pressed spot.
          transform: Matrix4.identity()
            ..setEntry(3, 2, .0012)
            ..rotateX(t.dy * .07)
            ..rotateY(-t.dx * .07),
          child: child,
        ),
        child: AnimatedScale(
          scale: _down && !still ? .975 : 1,
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          child: InkWell(
            borderRadius: BorderRadius.circular(_tileRadius),
            onTap: () {
              HapticFeedback.selectionClick();
              widget.onTap();
            },
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// Two shadows, as light does: a tight one where the card meets the page and a
/// wide soft one that lifts it.
List<BoxShadow> _lift(Color c, {double strength = 1}) => [
  BoxShadow(
    color: c.withValues(alpha: .06 * strength),
    blurRadius: 2,
    offset: const Offset(0, 1),
  ),
  BoxShadow(
    color: c.withValues(alpha: .10 * strength),
    blurRadius: 26,
    spreadRadius: -4,
    offset: const Offset(0, 12),
  ),
];

/// "Last used", on the tool opened most recently.
class _LastUsedChip extends StatelessWidget {
  const _LastUsedChip({this.onDark = false});
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onDark ? Colors.white.withValues(alpha: .2) : _brand,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        context.l10n.homeLastUsed,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

void _open(BuildContext context, WidgetRef ref, _ToolItem item) {
  ref.read(lastToolProvider.notifier).opened(item.route);
  context.push(item.route);
}

class _ToolTile extends ConsumerWidget {
  const _ToolTile({required this.item, this.wide = false});
  final _ToolItem item;
  final bool wide;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final last = ref.watch(lastToolProvider) == item.route;
    // A circle, not a rounded square: it never has to line up with the
    // card's corners.
    final icon = Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: _brand.withValues(alpha: .1),
      ),
      child: Icon(item.icon, size: 23, color: _brand),
    );
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          item.label,
          style: const TextStyle(
            color: AppColors.deepNavy,
            fontSize: 16,
            height: 1.25,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          item.caption,
          style: const TextStyle(
            color: AppColors.textMuted,
            fontSize: 12.5,
            height: 1.3,
          ),
        ),
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_tileRadius),
        boxShadow: _lift(AppColors.deepNavy),
      ),
      child: Material(
        color: Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(_tileRadius),
          side: BorderSide(
            color: last ? _brand.withValues(alpha: .4) : AppColors.cardBorder,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: _Pressable(
          onTap: () => _open(context, ref, item),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: wide
                ? Row(
                    children: [
                      icon,
                      const SizedBox(width: 14),
                      Expanded(child: texts),
                      const SizedBox(width: 8),
                      if (last) const _LastUsedChip(),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textMuted,
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          icon,
                          const SizedBox(width: 8),
                          if (last)
                            const Expanded(
                              child: Align(
                                alignment: Alignment.topRight,
                                child: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: _LastUsedChip(),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      texts,
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

/// The headline tool: Home Cameras on the brand gradient, with a small live
/// look at the cameras themselves (their latest pictures and who is online).
/// When the cameras can't be listed it is just the title and caption.
class _CamerasTile extends ConsumerWidget {
  const _CamerasTile({required this.item});
  final _ToolItem item;

  static const _pad = 14.0;
  static const _thumbRadius = 5.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final last = ref.watch(lastToolProvider) == item.route;
    final cameras = ref.watch(camerasProvider).value ?? const <HomeCamera>[];
    final online = cameras.where((c) => c.online).length;
    final muted = Colors.white.withValues(alpha: .82);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_tileRadius),
        boxShadow: _lift(AppColors.softBlue, strength: 2.6),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(_tileRadius),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF1B3F9E), AppColors.softBlue],
            ),
          ),
          child: _Pressable(
            onTap: () => _open(context, ref, item),
            child: Stack(
              children: [
                // A sheen along the top edge, like light on glass.
                Positioned.fill(
                  child: IgnorePointer(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.center,
                          colors: [
                            Colors.white.withValues(alpha: .14),
                            Colors.white.withValues(alpha: 0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(_pad + 4, 16, _pad, _pad),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(item.icon, size: 28, color: Colors.white),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.label,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                if (cameras.isEmpty)
                                  Text(
                                    item.caption,
                                    style: TextStyle(
                                      color: muted,
                                      fontSize: 13,
                                      height: 1.3,
                                    ),
                                  )
                                else
                                  Row(
                                    children: [
                                      _Dot(on: online > 0),
                                      const SizedBox(width: 6),
                                      Flexible(
                                        child: Text(
                                          l10n.camOnlineCount(
                                            online,
                                            cameras.length,
                                          ),
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: muted,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                          if (last) ...[
                            const _LastUsedChip(onDark: true),
                            const SizedBox(width: 6),
                          ],
                          const Icon(
                            Icons.arrow_forward_rounded,
                            color: Colors.white,
                          ),
                        ],
                      ),
                      if (cameras.isNotEmpty) ...[
                        const SizedBox(height: 14),
                        _Thumbs(cameras: cameras, radius: _thumbRadius),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Green when something is online, grey when nothing is.
class _Dot extends StatelessWidget {
  const _Dot({required this.on});
  final bool on;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: on ? const Color(0xFF4ADE80) : Colors.white54,
      ),
    );
  }
}

/// Up to three cameras side by side; "+N" on the last when there are more.
class _Thumbs extends StatelessWidget {
  const _Thumbs({required this.cameras, required this.radius});
  final List<HomeCamera> cameras;
  final double radius;

  static const _max = 3;

  @override
  Widget build(BuildContext context) {
    final shown = cameras.take(_max).toList();
    final more = cameras.length - shown.length;
    return Row(
      children: [
        for (var i = 0; i < _max; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: i < shown.length
                ? _Thumb(
                    camera: shown[i],
                    radius: radius,
                    more: i == shown.length - 1 && more > 0 ? more : 0,
                  )
                // Keeps one or two pictures the same size as three would be.
                : const SizedBox.shrink(),
          ),
        ],
      ],
    );
  }
}

class _Thumb extends ConsumerWidget {
  const _Thumb({required this.camera, required this.radius, this.more = 0});
  final HomeCamera camera;
  final double radius;
  final int more;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final snap = camera.online
        ? ref.watch(cameraSnapshotProvider(camera.id))
        : null;
    final Uint8List? bytes = snap?.value;

    final Widget picture;
    if (!camera.online) {
      picture = ColoredBox(
        color: Colors.black.withValues(alpha: .25),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.videocam_off_rounded,
                size: 18,
                color: Colors.white70,
              ),
              const SizedBox(height: 2),
              Text(
                l10n.camOffline,
                style: const TextStyle(color: Colors.white70, fontSize: 11),
              ),
            ],
          ),
        ),
      );
    } else if (bytes != null) {
      picture = Image.memory(
        bytes,
        fit: BoxFit.cover,
        gaplessPlayback: true,
        errorBuilder: (_, _, _) => const _ThumbEmpty(broken: true),
      );
    } else {
      // A camera with a cross when its picture could not be fetched; the
      // plain camera while it is still on its way.
      picture = _ThumbEmpty(broken: snap?.pictureFailed ?? false);
    }

    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: () {
              ref.read(lastToolProvider.notifier).opened('/cameras');
              if (more > 0) {
                context.push('/cameras');
              } else if (!camera.online) {
                AppToast.info(l10n.camOfflineToast);
              } else {
                context.push(
                  '/cameras/${Uri.encodeComponent(camera.id)}',
                  extra: camera,
                );
              }
            },
            child: Stack(
              fit: StackFit.expand,
              children: [
                picture,
                // Darkens the bottom so the name reads on any picture.
                const Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: 30,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black54],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 4,
                  child: Text(
                    camera.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                if (more > 0)
                  ColoredBox(
                    color: Colors.black.withValues(alpha: .45),
                    child: Center(
                      child: Text(
                        '+$more',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ThumbEmpty extends StatelessWidget {
  const _ThumbEmpty({this.broken = false});

  /// The picture could not be loaded (drawn with a cross through the camera).
  final bool broken;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Colors.white.withValues(alpha: .12),
      child: Center(
        child: Icon(
          broken ? Icons.videocam_off_rounded : Icons.videocam_rounded,
          size: 22,
          color: Colors.white70,
        ),
      ),
    );
  }
}

// =====================  Motion  =====================

/// Plays [child]'s entrance only when the system allows animations.
Duration _motion(BuildContext context, Duration d) =>
    MediaQuery.disableAnimationsOf(context) ? Duration.zero : d;

/// Fades and lifts [child] in once, [delay] (0–1) into a 0.9 s window.
class _Entrance extends StatelessWidget {
  const _Entrance({required this.child, this.delay = 0});
  final Widget child;
  final double delay;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: _motion(context, const Duration(milliseconds: 900)),
      curve: Interval(delay, 1, curve: Curves.easeOutCubic),
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, (1 - t) * 14),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// Counts up to [value] the first time it is shown, e.g. "0°C" → "31°C".
class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style});
  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: _motion(context, const Duration(milliseconds: 1100)),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('${v.round()}°C', style: style),
    );
  }
}

/// Pops [child] in with a small overshoot.
class _Pop extends StatelessWidget {
  const _Pop({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: .4, end: 1),
      duration: _motion(context, const Duration(milliseconds: 900)),
      curve: Curves.elasticOut,
      builder: (_, t, child) => Transform.scale(scale: t, child: child),
      child: child,
    );
  }
}
