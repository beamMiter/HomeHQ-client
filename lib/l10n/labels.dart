import 'app_localizations.dart';

/// Wording for the app's fixed vocabularies (bill types, statuses ...).
///
/// The server stores stable codes ('electric', 'unpaid'); these turn a code
/// into text in the user's language. An unknown code is shown as it came, so
/// a value added on the server is never blank.

String billTypeLabel(AppLocalizations l10n, String code) => switch (code) {
  'electric' => l10n.billTypeElectric,
  'water' => l10n.billTypeWater,
  'internet' => l10n.billTypeInternet,
  'phone' => l10n.billTypePhone,
  'other' => l10n.billTypeOther,
  _ => code,
};

String billStatusLabel(AppLocalizations l10n, String code) => switch (code) {
  'paid' => l10n.billStatusPaid,
  'unpaid' => l10n.billStatusUnpaid,
  _ => code,
};
