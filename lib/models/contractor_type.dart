import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';

/// How a contractor trade is presented: its label and icon.
///
/// Trades are told apart by icon and name, not by colour: the app keeps to one
/// blue tone (see AppColors), and four trade colours on one map would break it.
class ContractorType {
  const ContractorType(this.key, this.label, this.icon);

  /// The value the API stores and filters on.
  final String key;

  /// Thai name, kept for code with no language context. Screens show
  /// [name] instead, which follows the app language.
  final String label;
  final IconData icon;

  /// The trade's name in the app language.
  String name(AppLocalizations l10n) => switch (key) {
    'electrician' => l10n.contTypeElectrician,
    'plumber' => l10n.contTypePlumber,
    'carpenter' => l10n.contTypeCarpenter,
    'hvac' => l10n.contTypeHvac,
    _ => l10n.contTypeOther,
  };
}

const contractorTypes = <ContractorType>[
  ContractorType('electrician', 'ช่างไฟ', Icons.bolt_rounded),
  ContractorType('plumber', 'ช่างประปา', Icons.water_drop_rounded),
  ContractorType('carpenter', 'ช่างไม้', Icons.carpenter_rounded),
  ContractorType('hvac', 'ช่างแอร์', Icons.ac_unit_rounded),
];

/// Used when a contractor has no trade, or one this app doesn't know yet.
const otherContractorType = ContractorType(
  'other',
  'ช่างทั่วไป',
  Icons.handyman_rounded,
);

/// The type to draw for a contractor with these trade [keys] (first match).
ContractorType contractorTypeFor(Iterable<String> keys) {
  for (final k in keys) {
    for (final t in contractorTypes) {
      if (t.key == k) return t;
    }
  }
  return otherContractorType;
}
