import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/l10n.dart';
import '../../models/appliance.dart';
import '../../models/appliance_catalog.dart';
import '../../repositories/appliances_repository.dart';

/// Back arrow of the appliance pages: up one page, or Home when there is none
/// (the app was restarted on this page, or it was opened by a link).
void applianceBack(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/home');
  }
}

/// The wording for an appliance failure, in the app's language.
String applianceErrorText(AppLocalizations l10n, Object? error) {
  if (error is ApplianceException) {
    return switch (error.failure) {
      ApplianceFailure.misconfigured => l10n.applErrMisconfigured,
      ApplianceFailure.limited => l10n.applErrLimit,
      ApplianceFailure.offline => l10n.applErrOffline,
      ApplianceFailure.unsupported => l10n.applErrNotSupported,
      ApplianceFailure.forbidden => l10n.applAdminOnly,
      ApplianceFailure.invalid => l10n.applErrInvalid,
      ApplianceFailure.disabled => l10n.applDisabledTitle,
      _ => l10n.applErrUnavailable,
    };
  }
  return l10n.applErrUnavailable;
}

/// What to tell someone whose command to [name] did not go through.
String applianceCommandError(AppLocalizations l10n, String name, Object? e) {
  if (e is ApplianceException) {
    switch (e.failure) {
      case ApplianceFailure.offline:
      case ApplianceFailure.forbidden:
      case ApplianceFailure.unsupported:
      case ApplianceFailure.limited:
        return applianceErrorText(l10n, e);
      default:
        break;
    }
  }
  return l10n.applSwitchFailed(name);
}

IconData applianceIcon(String kind) => switch (kind) {
  'light' => Icons.lightbulb_rounded,
  'plug' => Icons.power_rounded,
  'fan' => Icons.air_rounded,
  'cooler' => Icons.hvac_rounded,
  'aircon' => Icons.ac_unit_rounded,
  'heater' => Icons.local_fire_department_rounded,
  _ => Icons.devices_other_rounded,
};

/// A control's name. A key the app doesn't know is shown as a plain phrase
/// rather than hidden.
String capabilityLabel(AppLocalizations l10n, String key) => switch (key) {
  'power' => l10n.applCapPower,
  'brightness' => l10n.applCapBrightness,
  'temperature' => l10n.applCapTemperature,
  'mode' => l10n.applCapMode,
  'fan_speed' => l10n.applCapFanSpeed,
  'swing' => l10n.applCapSwing,
  'cooling' => l10n.applCapCooling,
  _ => _humanize(key),
};

/// What a kind of appliance is called.
String kindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'aircon' => l10n.applKindAircon,
  'cooler' => l10n.applKindCooler,
  'light' => l10n.applKindLight,
  'fan' => l10n.applKindFan,
  'plug' => l10n.applKindPlug,
  'heater' => l10n.applKindHeater,
  _ => l10n.applKindOther,
};

/// One line on what the app can do with a kind of appliance.
String kindHint(AppLocalizations l10n, String kind) => switch (kind) {
  'aircon' => l10n.applKindAirconHint,
  'cooler' => l10n.applKindCoolerHint,
  'light' => l10n.applKindLightHint,
  'fan' => l10n.applKindFanHint,
  'plug' => l10n.applKindPlugHint,
  'heater' => l10n.applKindHeaterHint,
  _ => l10n.applKindOtherHint,
};

IconData connectionIcon(ConnectionMethod m) => switch (m) {
  ConnectionMethod.demo => Icons.science_outlined,
  ConnectionMethod.wifi => Icons.wifi_rounded,
  ConnectionMethod.ir => Icons.settings_remote_rounded,
  ConnectionMethod.homeAssistant => Icons.hub_outlined,
};

String connectionTitle(AppLocalizations l10n, ConnectionMethod m) =>
    switch (m) {
      ConnectionMethod.demo => l10n.applConnDemo,
      ConnectionMethod.wifi => l10n.applConnWifi,
      ConnectionMethod.ir => l10n.applConnIr,
      ConnectionMethod.homeAssistant => l10n.applConnHa,
    };

String connectionSummary(AppLocalizations l10n, ConnectionMethod m) =>
    switch (m) {
      ConnectionMethod.demo => l10n.applConnDemoSummary,
      ConnectionMethod.wifi => l10n.applConnWifiSummary,
      ConnectionMethod.ir => l10n.applConnIrSummary,
      ConnectionMethod.homeAssistant => l10n.applConnHaSummary,
    };

/// What must be in place before this connection can work.
List<String> connectionRequirements(
  AppLocalizations l10n,
  ConnectionMethod m,
) => switch (m) {
  ConnectionMethod.demo => [l10n.applReqDemo1],
  ConnectionMethod.wifi => [
    l10n.applReqWifi1,
    l10n.applReqWifi2,
    l10n.applReqWifi3,
    l10n.applReqWifi4,
  ],
  ConnectionMethod.ir => [
    l10n.applReqIr1,
    l10n.applReqIr2,
    l10n.applReqIr3,
    l10n.applReqIr4,
  ],
  ConnectionMethod.homeAssistant => [
    l10n.applReqHa1,
    l10n.applReqHa2,
    l10n.applReqHa3,
  ],
};

/// A caveat worth saying aloud about this connection, or null.
String? connectionCaveat(AppLocalizations l10n, ConnectionMethod m) =>
    m == ConnectionMethod.ir ? l10n.applReqIrNote : null;

/// An enum value's name; unknown ones are shown as they come.
String optionLabel(AppLocalizations l10n, String option) => switch (option) {
  'auto' => l10n.applModeAuto,
  'cool' => l10n.applModeCool,
  'dry' => l10n.applModeDry,
  'fan' => l10n.applModeFan,
  'heat' => l10n.applModeHeat,
  'normal' => l10n.applModeNormal,
  'natural' => l10n.applModeNatural,
  'sleep' => l10n.applModeSleep,
  _ => _humanize(option),
};

/// The sign for an enum value that is a mode, or null for one this app has no
/// sign for (it is then written out).
IconData? modeIcon(String mode) => switch (mode) {
  'cool' => Icons.ac_unit_rounded,
  'heat' => Icons.wb_sunny_rounded,
  'dry' => Icons.water_drop_rounded,
  'fan' || 'normal' => Icons.air_rounded,
  'auto' => Icons.autorenew_rounded,
  'natural' => Icons.eco_rounded,
  'sleep' => Icons.bedtime_rounded,
  _ => null,
};

String _humanize(String s) {
  final t = s.replaceAll('_', ' ').trim();
  return t.isEmpty ? s : t[0].toUpperCase() + t.substring(1);
}

/// A value of [cap] as the person reads it: "On", "25°C", "60%", "Cool".
String valueText(
  AppLocalizations l10n,
  ApplianceCapability? cap,
  Object? value,
) {
  if (value is bool) return value ? l10n.applOn : l10n.applOff;
  if (value is num) {
    final unit = cap?.unit;
    final n = value.toInt().toString();
    if (unit == null || unit.isEmpty) return n;
    return unit == '%' || unit.startsWith('°') ? '$n$unit' : '$n $unit';
  }
  if (value is String) return optionLabel(l10n, value);
  return '';
}

/// One line about how an appliance is right now: "On · 25°C · Cool".
String applianceSummary(AppLocalizations l10n, Appliance a) {
  if (!a.online) return l10n.applOffline;
  return [
    if (a.hasPower) a.isOn ? l10n.applOn : l10n.applOff,
    ...applianceSettings(l10n, a),
  ].join(' · ');
}

/// What it is set to while it runs, beside its status: "25°C", "Cool",
/// "60%", "Cooling". Nothing while it is off. [temperature] false leaves the
/// degrees out, where they are shown somewhere else on the screen.
List<String> applianceSettings(
  AppLocalizations l10n,
  Appliance a, {
  bool temperature = true,
}) {
  if (a.hasPower && !a.isOn) return const [];
  return [
    for (final key in [if (temperature) 'temperature', 'mode', 'brightness'])
      if (a.capability(key) != null && a.state[key] != null)
        valueText(l10n, a.capability(key), a.state[key]),
    if (a.capability('cooling') != null && a.state['cooling'] == true)
      l10n.applCapCooling,
  ];
}
