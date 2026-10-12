import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';

import '../l10n/l10n.dart';
import '../state/auth_state.dart';
import '../state/location_controller.dart';
import '../state/weather_provider.dart';
import '../models/weather.dart';
import '../widgets/error_state.dart';
import '../widgets/language_sheet.dart';
import '../shared/app_colors.dart';
import '../widgets/page_loading.dart';
import '../widgets/toast.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),

      // ===== AppBar: ไอคอนบ้าน + ระฆัง + ออกจากระบบ =====
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: AppColors.deepNavy,
        centerTitle: true,
        title: Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            color: AppColors.softBlue.withValues(alpha: .12),
            shape: BoxShape.circle,
            border: Border.all(color: AppColors.cardBorder),
          ),
          child: const Icon(
            Icons.home_rounded,
            color: AppColors.softBlue,
            size: 24,
          ),
        ),
        actions: [
          IconButton(
            tooltip: l10n.homeNotifications,
            onPressed: () => AppToast.info(l10n.homeNotificationsSoon),
            icon: const Icon(Icons.notifications_none_rounded, size: 22),
          ),
          IconButton(
            tooltip: l10n.languageTitle,
            onPressed: () => showLanguageSheet(context),
            icon: const Icon(Icons.translate_rounded, size: 22),
          ),
          IconButton(
            tooltip: l10n.homeLogout,
            onPressed: () async {
              await ref.read(authProvider.notifier).logout();
              if (!context.mounted) return;
              context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
        ],
      ),

      // ===== Body: คอนเทนต์เดิมกลับมา =====
      body: RefreshIndicator(
        onRefresh: () async {
          // Re-check GPS first; weather rebuilds itself when the fix changes.
          await ref.read(locationControllerProvider.notifier).refresh();
          ref.invalidate(currentWeatherProvider);
          await ref.read(currentWeatherProvider.future);
        },
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            _SectionCard(
              title: l10n.homeWeatherTitle,
              subtitle: l10n.homeWeatherSubtitle,
              child: const _WeatherBodyProxy(),
            ),
            const SizedBox(height: 16),
            _SectionCard(
              title: l10n.homeToolsTitle,
              subtitle: l10n.homeToolsSubtitle,
              child: const _QuickToolsSection(),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child, this.subtitle});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.cardBorder),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeader(title: title, subtitle: subtitle),
            const SizedBox(height: 8),
            const Divider(height: 24, color: AppColors.cardBorder),
            child,
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppColors.deepNavy,
            fontWeight: FontWeight.w700,
          ),
        ),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

// proxy เพื่อดึง AsyncValue<WeatherNow> จาก provider
class _WeatherBodyProxy extends ConsumerWidget {
  const _WeatherBodyProxy();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weather = ref.watch(currentWeatherProvider);
    return _WeatherBody(
      weather: weather,
      // The weather error is usually a location problem, so retry the GPS
      // check (weather rebuilds when the controller reports a fix).
      onRetry: () => ref.read(locationControllerProvider.notifier).refresh(),
    );
  }
}

class _WeatherBody extends StatelessWidget {
  const _WeatherBody({required this.weather, required this.onRetry});
  final AsyncValue<WeatherNow> weather;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return weather.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: PageLoading(),
      ),
      error: (e, _) => ErrorState(
        icon: Icons.cloud_off,
        title: l10n.homeWeatherFailed,
        error: e,
        retryLabel: l10n.commonTryAgain,
        onRetry: onRetry,
      ),
      data: (w) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.thermostat_outlined,
                      title: l10n.homeTemperature,
                      value: '${w.temperature.toStringAsFixed(1)} °C',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _MetricTile(
                      icon: Icons.wb_sunny_outlined,
                      title: l10n.homeCondition,
                      value: switch (w.condition) {
                        WeatherCondition.clear => l10n.weatherClear,
                        WeatherCondition.partlyCloudy =>
                          l10n.weatherPartlyCloudy,
                        WeatherCondition.fog => l10n.weatherFog,
                        WeatherCondition.drizzle => l10n.weatherDrizzle,
                        WeatherCondition.rain => l10n.weatherRain,
                        WeatherCondition.snow => l10n.weatherSnow,
                        WeatherCondition.thunderstorm =>
                          l10n.weatherThunderstorm,
                        WeatherCondition.unknown => l10n.weatherUnknown,
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _InfoRow(
                    icon: Icons.air,
                    label: l10n.homeWind,
                    value: '${w.windSpeed.toStringAsFixed(1)} m/s',
                  ),
                ),
                Expanded(
                  child: _InfoRow(
                    icon: Icons.schedule_outlined,
                    label: l10n.homeUpdated,
                    value: DateFormat('HH:mm').format(w.time),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.icon,
    required this.title,
    required this.value,
  });
  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: AppColors.softBlue),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: AppColors.deepNavy,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.textMuted),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: AppColors.textMuted,
            fontWeight: FontWeight.w600,
          ),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.deepNavy),
          ),
        ),
      ],
    );
  }
}

// =====================  Quick Tools  =====================
class _QuickToolsSection extends StatelessWidget {
  const _QuickToolsSection();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    // The feature names stay in English in every language; only the
    // captions are translated.
    final items = <_ToolItem>[
      _ToolItem(
        Icons.handyman,
        'Contractors',
        '/contractors',
        l10n.toolContractorsCaption,
      ),
      _ToolItem(
        Icons.event_note,
        'Important Notes',
        '/notes',
        l10n.toolNotesCaption,
      ),
      _ToolItem(
        Icons.videocam_outlined,
        'Home Cameras',
        '/cameras',
        l10n.toolCamerasCaption,
      ),
      _ToolItem(
        Icons.shopping_cart_checkout,
        'Purchases',
        '/purchases',
        l10n.toolPurchasesCaption,
      ),
      _ToolItem(Icons.receipt_long, 'Bills', '/bills', l10n.toolBillsCaption),
      _ToolItem(
        Icons.medical_services_outlined,
        'Medicine Stock',
        '/medicine',
        l10n.toolMedicineCaption,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _LauncherSearch(
          hintText: l10n.homeSearchHint,
          onSubmit: (q) => _goTo(context, '/contractors', query: q),
        ),
        const SizedBox(height: 12),
        _ToolGrid(items: items, large: true),
      ],
    );
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
}

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
  Widget build(BuildContext context) {
    return TextField(
      controller: _controller,
      onSubmitted: widget.onSubmit,
      decoration: InputDecoration(
        hintText: widget.hintText,
        prefixIcon: const Icon(Icons.search, color: AppColors.textMuted),
        filled: true,
        fillColor: const Color(0xFFF7FAFF),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.softBlue),
        ),
      ),
    );
  }
}

class _ToolGrid extends StatelessWidget {
  const _ToolGrid({required this.items, this.large = false});

  final List<_ToolItem> items;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final iconSize = large ? 36.0 : 30.0;
    // A fixed height rather than an aspect ratio: the title and caption can
    // each wrap to two lines (English runs longer than Thai, and text scale
    // goes up to 1.2), and a ratio-sized card would overflow.
    final extent = large ? 184.0 : 150.0;

    return GridView.builder(
      shrinkWrap: true,
      itemCount: items.length,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        mainAxisExtent: extent,
      ),
      itemBuilder: (_, i) =>
          _ToolCard(item: items[i], iconSize: iconSize, large: large),
    );
  }
}

class _ToolItem {
  final IconData icon;
  final String label;
  final String route;
  final String caption;
  const _ToolItem(this.icon, this.label, this.route, this.caption);
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.item,
    required this.iconSize,
    required this.large,
  });
  final _ToolItem item;
  final double iconSize;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final titleStyle = large
        ? Theme.of(context).textTheme.titleMedium
        : Theme.of(context).textTheme.titleSmall;

    return InkWell(
      onTap: () => context.push(item.route),
      borderRadius: BorderRadius.circular(16),
      child: Ink(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(item.icon, size: iconSize, color: AppColors.softBlue),
              const SizedBox(height: 10),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: titleStyle?.copyWith(
                  color: AppColors.deepNavy,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                item.caption,
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
