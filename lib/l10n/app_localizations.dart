import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_th.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('th'),
  ];

  /// No description provided for @commonTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Try again'**
  String get commonTryAgain;

  /// No description provided for @commonCancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// No description provided for @commonSave.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// No description provided for @commonDelete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// No description provided for @commonClear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// No description provided for @commonApply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get commonApply;

  /// No description provided for @commonClose.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// No description provided for @commonBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// No description provided for @commonSearch.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get commonSearch;

  /// No description provided for @commonAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get commonAll;

  /// No description provided for @commonYes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get commonNo;

  /// No description provided for @commonLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load this'**
  String get commonLoadFailed;

  /// No description provided for @languageTitle.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get languageTitle;

  /// No description provided for @languageSystem.
  ///
  /// In en, this message translates to:
  /// **'Device language'**
  String get languageSystem;

  /// No description provided for @languageThai.
  ///
  /// In en, this message translates to:
  /// **'ไทย'**
  String get languageThai;

  /// No description provided for @languageEnglish.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get languageEnglish;

  /// No description provided for @refreshTooltip.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshTooltip;

  /// No description provided for @refreshDone.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get refreshDone;

  /// No description provided for @refreshFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh. Please try again.'**
  String get refreshFailed;

  /// No description provided for @homeNotifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get homeNotifications;

  /// No description provided for @homeNotificationsSoon.
  ///
  /// In en, this message translates to:
  /// **'Notifications are coming soon'**
  String get homeNotificationsSoon;

  /// No description provided for @homeToolsTitle.
  ///
  /// In en, this message translates to:
  /// **'Tools'**
  String get homeToolsTitle;

  /// No description provided for @homeToolsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage your home quickly'**
  String get homeToolsSubtitle;

  /// No description provided for @homeWeatherFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the weather'**
  String get homeWeatherFailed;

  /// No description provided for @homeWind.
  ///
  /// In en, this message translates to:
  /// **'Wind'**
  String get homeWind;

  /// No description provided for @homeUpdated.
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get homeUpdated;

  /// No description provided for @homeSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search electrician, plumber…'**
  String get homeSearchHint;

  /// No description provided for @weatherClear.
  ///
  /// In en, this message translates to:
  /// **'Clear sky'**
  String get weatherClear;

  /// No description provided for @weatherPartlyCloudy.
  ///
  /// In en, this message translates to:
  /// **'Partly cloudy'**
  String get weatherPartlyCloudy;

  /// No description provided for @weatherFog.
  ///
  /// In en, this message translates to:
  /// **'Fog'**
  String get weatherFog;

  /// No description provided for @weatherDrizzle.
  ///
  /// In en, this message translates to:
  /// **'Drizzle'**
  String get weatherDrizzle;

  /// No description provided for @weatherRain.
  ///
  /// In en, this message translates to:
  /// **'Rain'**
  String get weatherRain;

  /// No description provided for @weatherSnow.
  ///
  /// In en, this message translates to:
  /// **'Snow'**
  String get weatherSnow;

  /// No description provided for @weatherThunderstorm.
  ///
  /// In en, this message translates to:
  /// **'Thunderstorm'**
  String get weatherThunderstorm;

  /// No description provided for @weatherUnknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get weatherUnknown;

  /// No description provided for @toolContractorsCaption.
  ///
  /// In en, this message translates to:
  /// **'Find tradespeople near you'**
  String get toolContractorsCaption;

  /// No description provided for @toolNotesCaption.
  ///
  /// In en, this message translates to:
  /// **'Notes you must not forget'**
  String get toolNotesCaption;

  /// No description provided for @toolCamerasCaption.
  ///
  /// In en, this message translates to:
  /// **'Watch the home cameras'**
  String get toolCamerasCaption;

  /// No description provided for @toolPurchasesCaption.
  ///
  /// In en, this message translates to:
  /// **'Track what\'s bought for the home'**
  String get toolPurchasesCaption;

  /// No description provided for @toolBillsCaption.
  ///
  /// In en, this message translates to:
  /// **'Recurring household bills'**
  String get toolBillsCaption;

  /// No description provided for @toolMedicineCaption.
  ///
  /// In en, this message translates to:
  /// **'Check the household medicine stock'**
  String get toolMedicineCaption;

  /// No description provided for @commonConfirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// No description provided for @commonInvalidNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid number'**
  String get commonInvalidNumber;

  /// No description provided for @medAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Set alerts'**
  String get medAlertTitle;

  /// No description provided for @medAlertEnable.
  ///
  /// In en, this message translates to:
  /// **'Turn on alerts'**
  String get medAlertEnable;

  /// No description provided for @medAlertMinQty.
  ///
  /// In en, this message translates to:
  /// **'Alert when stock is at or below (units)'**
  String get medAlertMinQty;

  /// No description provided for @medAlertExpiryDays.
  ///
  /// In en, this message translates to:
  /// **'Alert when days to expiry are at or below (days)'**
  String get medAlertExpiryDays;

  /// No description provided for @medAlertUpdated.
  ///
  /// In en, this message translates to:
  /// **'Alert updated'**
  String get medAlertUpdated;

  /// No description provided for @medAlertNone.
  ///
  /// In en, this message translates to:
  /// **'No alert'**
  String get medAlertNone;

  /// No description provided for @medAlertOn.
  ///
  /// In en, this message translates to:
  /// **'ON · min {min} · exp {days}d'**
  String medAlertOn(String min, String days);

  /// No description provided for @medAlertOff.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get medAlertOff;

  /// No description provided for @medTxnInTitle.
  ///
  /// In en, this message translates to:
  /// **'Stock in'**
  String get medTxnInTitle;

  /// No description provided for @medTxnOutTitle.
  ///
  /// In en, this message translates to:
  /// **'Take out'**
  String get medTxnOutTitle;

  /// No description provided for @medTxnLot.
  ///
  /// In en, this message translates to:
  /// **'Lot number (optional)'**
  String get medTxnLot;

  /// No description provided for @medTxnExpiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry date (YYYY-MM-DD)'**
  String get medTxnExpiry;

  /// No description provided for @medTxnQty.
  ///
  /// In en, this message translates to:
  /// **'Quantity (units)'**
  String get medTxnQty;

  /// No description provided for @medTxnQtyInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid quantity'**
  String get medTxnQtyInvalid;

  /// No description provided for @medTxnNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get medTxnNote;

  /// No description provided for @medTxnInDone.
  ///
  /// In en, this message translates to:
  /// **'Stock received'**
  String get medTxnInDone;

  /// No description provided for @medTxnOutDone.
  ///
  /// In en, this message translates to:
  /// **'Medicine taken out'**
  String get medTxnOutDone;

  /// No description provided for @medBatchLot.
  ///
  /// In en, this message translates to:
  /// **'Lot {lot}'**
  String medBatchLot(String lot);

  /// No description provided for @medBatchNoLot.
  ///
  /// In en, this message translates to:
  /// **'No lot number'**
  String get medBatchNoLot;

  /// No description provided for @medBatchExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires: {date}'**
  String medBatchExpires(String date);

  /// No description provided for @medInStock.
  ///
  /// In en, this message translates to:
  /// **'{qty} left'**
  String medInStock(String qty);

  /// No description provided for @billsNew.
  ///
  /// In en, this message translates to:
  /// **'New bill'**
  String get billsNew;

  /// No description provided for @billsSummaryTooltip.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get billsSummaryTooltip;

  /// No description provided for @billsSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search bills (title, note, type)…'**
  String get billsSearchHint;

  /// No description provided for @billsEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No bills yet'**
  String get billsEmptyTitle;

  /// No description provided for @billsEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add your first bill to start tracking.'**
  String get billsEmptyHint;

  /// No description provided for @billsClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get billsClearFilters;

  /// No description provided for @billStatusPaid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get billStatusPaid;

  /// No description provided for @billStatusUnpaid.
  ///
  /// In en, this message translates to:
  /// **'Unpaid'**
  String get billStatusUnpaid;

  /// No description provided for @billsPaidOn.
  ///
  /// In en, this message translates to:
  /// **'Paid on {date}'**
  String billsPaidOn(String date);

  /// No description provided for @billsDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get billsDueToday;

  /// No description provided for @billsDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get billsDueTomorrow;

  /// No description provided for @billsDueInDays.
  ///
  /// In en, this message translates to:
  /// **'Due in {days} days'**
  String billsDueInDays(int days);

  /// No description provided for @billsLateDays.
  ///
  /// In en, this message translates to:
  /// **'{days, plural, =1{1 day late} other{{days} days late}}'**
  String billsLateDays(int days);

  /// No description provided for @billsDueOn.
  ///
  /// In en, this message translates to:
  /// **'Due {date}'**
  String billsDueOn(String date);

  /// No description provided for @billTypeElectric.
  ///
  /// In en, this message translates to:
  /// **'Electricity'**
  String get billTypeElectric;

  /// No description provided for @billTypeWater.
  ///
  /// In en, this message translates to:
  /// **'Water'**
  String get billTypeWater;

  /// No description provided for @billTypeInternet.
  ///
  /// In en, this message translates to:
  /// **'Internet'**
  String get billTypeInternet;

  /// No description provided for @billTypePhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get billTypePhone;

  /// No description provided for @billTypeOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get billTypeOther;

  /// No description provided for @billDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Bill details'**
  String get billDetailTitle;

  /// No description provided for @billDetailAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get billDetailAmount;

  /// No description provided for @billDetailStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get billDetailStatus;

  /// No description provided for @billDetailDueDate.
  ///
  /// In en, this message translates to:
  /// **'Due date'**
  String get billDetailDueDate;

  /// No description provided for @billDetailCreatedAt.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get billDetailCreatedAt;

  /// No description provided for @billDetailUpdatedAt.
  ///
  /// In en, this message translates to:
  /// **'Last updated'**
  String get billDetailUpdatedAt;

  /// No description provided for @billDetailCreatedBy.
  ///
  /// In en, this message translates to:
  /// **'Created by'**
  String get billDetailCreatedBy;

  /// No description provided for @billDetailNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get billDetailNote;

  /// No description provided for @billMarkPaid.
  ///
  /// In en, this message translates to:
  /// **'Mark as paid'**
  String get billMarkPaid;

  /// No description provided for @billProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing…'**
  String get billProcessing;

  /// No description provided for @billMarkedPaid.
  ///
  /// In en, this message translates to:
  /// **'Marked as paid'**
  String get billMarkedPaid;

  /// No description provided for @billFormPickDue.
  ///
  /// In en, this message translates to:
  /// **'Pick a due date'**
  String get billFormPickDue;

  /// No description provided for @billFormType.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get billFormType;

  /// No description provided for @billFormTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get billFormTitle;

  /// No description provided for @billFormTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get billFormTitleRequired;

  /// No description provided for @billFormAmount.
  ///
  /// In en, this message translates to:
  /// **'Amount (THB)'**
  String get billFormAmount;

  /// No description provided for @billFormAmountInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid amount'**
  String get billFormAmountInvalid;

  /// No description provided for @billFormAmountPositive.
  ///
  /// In en, this message translates to:
  /// **'The amount must be greater than 0'**
  String get billFormAmountPositive;

  /// No description provided for @billFormNote.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get billFormNote;

  /// No description provided for @billFormPickDueFirst.
  ///
  /// In en, this message translates to:
  /// **'Please pick a due date'**
  String get billFormPickDueFirst;

  /// No description provided for @billFormDuePast.
  ///
  /// In en, this message translates to:
  /// **'The due date can\'t be in the past'**
  String get billFormDuePast;

  /// No description provided for @billFormCreated.
  ///
  /// In en, this message translates to:
  /// **'Bill created'**
  String get billFormCreated;

  /// No description provided for @billsSummaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Bills summary'**
  String get billsSummaryTitle;

  /// No description provided for @billsSummaryFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the summary'**
  String get billsSummaryFailed;

  /// No description provided for @billsSummaryEmpty.
  ///
  /// In en, this message translates to:
  /// **'No bill summary yet'**
  String get billsSummaryEmpty;

  /// No description provided for @medNew.
  ///
  /// In en, this message translates to:
  /// **'Add medicine'**
  String get medNew;

  /// No description provided for @medSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search medicine name…'**
  String get medSearchHint;

  /// No description provided for @medEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No medicine yet'**
  String get medEmptyTitle;

  /// No description provided for @medEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap “Add medicine” to create the first item.'**
  String get medEmptyHint;

  /// No description provided for @medLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the medicine list'**
  String get medLoadFailed;

  /// No description provided for @medStatusExpired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get medStatusExpired;

  /// No description provided for @medStatusExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon'**
  String get medStatusExpiringSoon;

  /// No description provided for @medStatusLow.
  ///
  /// In en, this message translates to:
  /// **'Running low'**
  String get medStatusLow;

  /// No description provided for @medUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit: {unit}'**
  String medUnit(String unit);

  /// No description provided for @medNextExpiry.
  ///
  /// In en, this message translates to:
  /// **'Next expiry {date}'**
  String medNextExpiry(String date);

  /// No description provided for @medDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Medicine details'**
  String get medDetailTitle;

  /// No description provided for @medDetailExpiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring soon: {date}'**
  String medDetailExpiringSoon(String date);

  /// No description provided for @medDetailLots.
  ///
  /// In en, this message translates to:
  /// **'Lots'**
  String get medDetailLots;

  /// No description provided for @medDetailNoLots.
  ///
  /// In en, this message translates to:
  /// **'No lots yet'**
  String get medDetailNoLots;

  /// No description provided for @medDetailNoLotsHint.
  ///
  /// In en, this message translates to:
  /// **'Tap “Stock in” to add the first lot.'**
  String get medDetailNoLotsHint;

  /// No description provided for @medDetailAlerts.
  ///
  /// In en, this message translates to:
  /// **'Alerts'**
  String get medDetailAlerts;

  /// No description provided for @medFormAdded.
  ///
  /// In en, this message translates to:
  /// **'Medicine added'**
  String get medFormAdded;

  /// No description provided for @medFormName.
  ///
  /// In en, this message translates to:
  /// **'Medicine name'**
  String get medFormName;

  /// No description provided for @medFormNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Paracetamol 500mg'**
  String get medFormNameHint;

  /// No description provided for @medFormNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter the medicine name'**
  String get medFormNameRequired;

  /// No description provided for @medFormForm.
  ///
  /// In en, this message translates to:
  /// **'Form (e.g. tablet, syrup)'**
  String get medFormForm;

  /// No description provided for @medFormUnit.
  ///
  /// In en, this message translates to:
  /// **'Unit (e.g. tab, ml)'**
  String get medFormUnit;

  /// No description provided for @medFormCategory.
  ///
  /// In en, this message translates to:
  /// **'Category (e.g. painkiller)'**
  String get medFormCategory;

  /// No description provided for @medFormNoLocation.
  ///
  /// In en, this message translates to:
  /// **'— No location —'**
  String get medFormNoLocation;

  /// No description provided for @medFormLocation.
  ///
  /// In en, this message translates to:
  /// **'Storage location'**
  String get medFormLocation;

  /// No description provided for @medFormLocationsFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load storage locations'**
  String get medFormLocationsFailed;

  /// No description provided for @commonStatus.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get commonStatus;

  /// No description provided for @commonNote.
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get commonNote;

  /// No description provided for @commonFilters.
  ///
  /// In en, this message translates to:
  /// **'Filters'**
  String get commonFilters;

  /// No description provided for @commonClearFilters.
  ///
  /// In en, this message translates to:
  /// **'Clear filters'**
  String get commonClearFilters;

  /// No description provided for @commonClearAll.
  ///
  /// In en, this message translates to:
  /// **'Clear all'**
  String get commonClearAll;

  /// No description provided for @authSignIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignIn;

  /// No description provided for @purchNew.
  ///
  /// In en, this message translates to:
  /// **'New purchase'**
  String get purchNew;

  /// No description provided for @purchAddItem.
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get purchAddItem;

  /// No description provided for @purchSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search (title, store, category, note, status)…'**
  String get purchSearchHint;

  /// No description provided for @purchStatusPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned'**
  String get purchStatusPlanned;

  /// No description provided for @purchStatusOrdered.
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get purchStatusOrdered;

  /// No description provided for @purchStatusBought.
  ///
  /// In en, this message translates to:
  /// **'Bought'**
  String get purchStatusBought;

  /// No description provided for @purchStatusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get purchStatusDelivered;

  /// No description provided for @purchStatusCanceled.
  ///
  /// In en, this message translates to:
  /// **'Canceled'**
  String get purchStatusCanceled;

  /// No description provided for @purchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No purchases match'**
  String get purchNoResults;

  /// No description provided for @purchEmpty.
  ///
  /// In en, this message translates to:
  /// **'No purchases yet'**
  String get purchEmpty;

  /// No description provided for @purchSignInPrompt.
  ///
  /// In en, this message translates to:
  /// **'Please sign in to use this'**
  String get purchSignInPrompt;

  /// No description provided for @purchLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the data'**
  String get purchLoadFailed;

  /// No description provided for @purchDetailTitle.
  ///
  /// In en, this message translates to:
  /// **'Purchase details'**
  String get purchDetailTitle;

  /// No description provided for @purchDetailLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load: {error}'**
  String purchDetailLoadFailed(String error);

  /// No description provided for @purchAdvanceSoon.
  ///
  /// In en, this message translates to:
  /// **'Changing the status isn\'t connected yet'**
  String get purchAdvanceSoon;

  /// No description provided for @purchUploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading file…'**
  String get purchUploading;

  /// No description provided for @purchUploadDone.
  ///
  /// In en, this message translates to:
  /// **'File uploaded'**
  String get purchUploadDone;

  /// No description provided for @purchUploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String purchUploadFailed(String error);

  /// No description provided for @purchItemsTitle.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get purchItemsTitle;

  /// No description provided for @purchItemsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String purchItemsCount(int count);

  /// No description provided for @purchNoItems.
  ///
  /// In en, this message translates to:
  /// **'— No items —'**
  String get purchNoItems;

  /// No description provided for @purchTotalByItems.
  ///
  /// In en, this message translates to:
  /// **'Total of items'**
  String get purchTotalByItems;

  /// No description provided for @purchEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated'**
  String get purchEstimated;

  /// No description provided for @purchPaid.
  ///
  /// In en, this message translates to:
  /// **'Actually paid'**
  String get purchPaid;

  /// No description provided for @purchAttachments.
  ///
  /// In en, this message translates to:
  /// **'Attachments'**
  String get purchAttachments;

  /// No description provided for @purchEstimatedAmount.
  ///
  /// In en, this message translates to:
  /// **'Estimated {amount}'**
  String purchEstimatedAmount(String amount);

  /// No description provided for @purchPaidAmount.
  ///
  /// In en, this message translates to:
  /// **'Paid {amount}'**
  String purchPaidAmount(String amount);

  /// No description provided for @purchItemQty.
  ///
  /// In en, this message translates to:
  /// **'Qty: {qty}'**
  String purchItemQty(String qty);

  /// No description provided for @purchItemPrice.
  ///
  /// In en, this message translates to:
  /// **'• {price} each'**
  String purchItemPrice(String price);

  /// No description provided for @purchNextStatus.
  ///
  /// In en, this message translates to:
  /// **'Next status'**
  String get purchNextStatus;

  /// No description provided for @purchAttach.
  ///
  /// In en, this message translates to:
  /// **'Attach file / photo'**
  String get purchAttach;

  /// No description provided for @purchNoAttachments.
  ///
  /// In en, this message translates to:
  /// **'— No attachments —'**
  String get purchNoAttachments;

  /// No description provided for @purchOpen.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get purchOpen;

  /// No description provided for @purchCantOpenLink.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the link'**
  String get purchCantOpenLink;

  /// No description provided for @purchDeleteAttachment.
  ///
  /// In en, this message translates to:
  /// **'Delete attachment'**
  String get purchDeleteAttachment;

  /// No description provided for @purchDeleteAttachmentAsk.
  ///
  /// In en, this message translates to:
  /// **'Delete this attachment?'**
  String get purchDeleteAttachmentAsk;

  /// No description provided for @purchDeleteAttachmentBody.
  ///
  /// In en, this message translates to:
  /// **'Delete the file “{name}”?'**
  String purchDeleteAttachmentBody(String name);

  /// No description provided for @purchDeleting.
  ///
  /// In en, this message translates to:
  /// **'Deleting attachment…'**
  String get purchDeleting;

  /// No description provided for @purchDeleted.
  ///
  /// In en, this message translates to:
  /// **'Attachment deleted'**
  String get purchDeleted;

  /// No description provided for @purchDeleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete: {error}'**
  String purchDeleteFailed(String error);

  /// No description provided for @purchFormCreate.
  ///
  /// In en, this message translates to:
  /// **'Create purchase'**
  String get purchFormCreate;

  /// No description provided for @purchFormEdit.
  ///
  /// In en, this message translates to:
  /// **'Edit purchase'**
  String get purchFormEdit;

  /// No description provided for @purchFormTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a title'**
  String get purchFormTitleRequired;

  /// No description provided for @purchFormTitleMin.
  ///
  /// In en, this message translates to:
  /// **'At least 3 characters'**
  String get purchFormTitleMin;

  /// No description provided for @purchFormPositive.
  ///
  /// In en, this message translates to:
  /// **'Must be greater than 0'**
  String get purchFormPositive;

  /// No description provided for @purchFormCreated.
  ///
  /// In en, this message translates to:
  /// **'Purchase created'**
  String get purchFormCreated;

  /// No description provided for @purchFormError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get purchFormError;

  /// No description provided for @purchFormSignIn.
  ///
  /// In en, this message translates to:
  /// **'Please sign in'**
  String get purchFormSignIn;

  /// No description provided for @purchFormDetails.
  ///
  /// In en, this message translates to:
  /// **'Purchase details'**
  String get purchFormDetails;

  /// No description provided for @purchFormTitleLabel.
  ///
  /// In en, this message translates to:
  /// **'Title *'**
  String get purchFormTitleLabel;

  /// No description provided for @purchFormTitleHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. “Cleaning supplies”'**
  String get purchFormTitleHint;

  /// No description provided for @purchFormNoteHint.
  ///
  /// In en, this message translates to:
  /// **'More details (optional)'**
  String get purchFormNoteHint;

  /// No description provided for @purchFormBudget.
  ///
  /// In en, this message translates to:
  /// **'Rough budget'**
  String get purchFormBudget;

  /// No description provided for @purchFormEstimated.
  ///
  /// In en, this message translates to:
  /// **'Estimated amount'**
  String get purchFormEstimated;

  /// No description provided for @purchFormEstimatedHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. 1,500 or 1500'**
  String get purchFormEstimatedHint;

  /// No description provided for @purchFormCurrency.
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get purchFormCurrency;

  /// No description provided for @purchFormOptional.
  ///
  /// In en, this message translates to:
  /// **'Optional — leave empty if you\'re not sure'**
  String get purchFormOptional;

  /// No description provided for @purchFormSaving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get purchFormSaving;

  /// No description provided for @commonError.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonError;

  /// No description provided for @notesNew.
  ///
  /// In en, this message translates to:
  /// **'New note'**
  String get notesNew;

  /// No description provided for @notesEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get notesEditTitle;

  /// No description provided for @notesStatusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get notesStatusActive;

  /// No description provided for @notesStatusDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get notesStatusDone;

  /// No description provided for @notesStatusOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get notesStatusOverdue;

  /// No description provided for @notesPinned.
  ///
  /// In en, this message translates to:
  /// **'Pinned'**
  String get notesPinned;

  /// No description provided for @notesUnpinned.
  ///
  /// In en, this message translates to:
  /// **'Unpinned'**
  String get notesUnpinned;

  /// No description provided for @notesCategory.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get notesCategory;

  /// No description provided for @notesCatBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get notesCatBills;

  /// No description provided for @notesCatChores.
  ///
  /// In en, this message translates to:
  /// **'Chores'**
  String get notesCatChores;

  /// No description provided for @notesCatAppointment.
  ///
  /// In en, this message translates to:
  /// **'Appointment'**
  String get notesCatAppointment;

  /// No description provided for @notesCatGeneral.
  ///
  /// In en, this message translates to:
  /// **'General'**
  String get notesCatGeneral;

  /// No description provided for @notesTag.
  ///
  /// In en, this message translates to:
  /// **'Tag'**
  String get notesTag;

  /// No description provided for @notesNoMatch.
  ///
  /// In en, this message translates to:
  /// **'No notes match'**
  String get notesNoMatch;

  /// No description provided for @notesMarkedDone.
  ///
  /// In en, this message translates to:
  /// **'Marked as done'**
  String get notesMarkedDone;

  /// No description provided for @notesMarkedUndone.
  ///
  /// In en, this message translates to:
  /// **'Marked as not done'**
  String get notesMarkedUndone;

  /// No description provided for @notesErrDone.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the note'**
  String get notesErrDone;

  /// No description provided for @notesErrPin.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the pin'**
  String get notesErrPin;

  /// No description provided for @notesErrDelete.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete the note'**
  String get notesErrDelete;

  /// No description provided for @notesErrSave.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the note'**
  String get notesErrSave;

  /// No description provided for @notesErr401.
  ///
  /// In en, this message translates to:
  /// **'{what}: 401 (please sign in again)'**
  String notesErr401(String what);

  /// No description provided for @notesErr404.
  ///
  /// In en, this message translates to:
  /// **'{what}: 404 (not found)'**
  String notesErr404(String what);

  /// No description provided for @notesDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete note'**
  String get notesDeleteTitle;

  /// No description provided for @notesDeleteBody.
  ///
  /// In en, this message translates to:
  /// **'Delete “{title}”?'**
  String notesDeleteBody(String title);

  /// No description provided for @notesDeleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted'**
  String get notesDeleted;

  /// No description provided for @notesAdded.
  ///
  /// In en, this message translates to:
  /// **'Note added'**
  String get notesAdded;

  /// No description provided for @notesEdited.
  ///
  /// In en, this message translates to:
  /// **'Note updated'**
  String get notesEdited;

  /// No description provided for @notesSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search notes (title, content, tag)'**
  String get notesSearchHint;

  /// No description provided for @notesCopy.
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get notesCopy;

  /// No description provided for @notesCopied.
  ///
  /// In en, this message translates to:
  /// **'Copied'**
  String get notesCopied;

  /// No description provided for @notesMarkDone.
  ///
  /// In en, this message translates to:
  /// **'Mark as done'**
  String get notesMarkDone;

  /// No description provided for @notesMarkUndone.
  ///
  /// In en, this message translates to:
  /// **'Mark as not done'**
  String get notesMarkUndone;

  /// No description provided for @notesPin.
  ///
  /// In en, this message translates to:
  /// **'Pin'**
  String get notesPin;

  /// No description provided for @notesUnpin.
  ///
  /// In en, this message translates to:
  /// **'Unpin'**
  String get notesUnpin;

  /// No description provided for @notesFieldTitle.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get notesFieldTitle;

  /// No description provided for @notesFieldContent.
  ///
  /// In en, this message translates to:
  /// **'Content (you can paste image links from Uploads)'**
  String get notesFieldContent;

  /// No description provided for @notesTitleRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter a title'**
  String get notesTitleRequired;

  /// No description provided for @notesCreate.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get notesCreate;

  /// No description provided for @notesErrUnauthorized.
  ///
  /// In en, this message translates to:
  /// **'Not authorized (401) — please sign in again'**
  String get notesErrUnauthorized;

  /// No description provided for @notesErrNotFound.
  ///
  /// In en, this message translates to:
  /// **'Notes not found (404)'**
  String get notesErrNotFound;

  /// No description provided for @notesErrLoad.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load notes: {detail}'**
  String notesErrLoad(String detail);

  /// No description provided for @distMeters.
  ///
  /// In en, this message translates to:
  /// **'{m} m'**
  String distMeters(String m);

  /// No description provided for @distKm.
  ///
  /// In en, this message translates to:
  /// **'{km} km'**
  String distKm(String km);

  /// No description provided for @contStarred.
  ///
  /// In en, this message translates to:
  /// **'Added to favorites'**
  String get contStarred;

  /// No description provided for @contUnstarred.
  ///
  /// In en, this message translates to:
  /// **'Removed from favorites'**
  String get contUnstarred;

  /// No description provided for @contStarFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save the star. Please try again.'**
  String get contStarFailed;

  /// No description provided for @contBackToMe.
  ///
  /// In en, this message translates to:
  /// **'Back to me'**
  String get contBackToMe;

  /// No description provided for @contFavorites.
  ///
  /// In en, this message translates to:
  /// **'Favorites'**
  String get contFavorites;

  /// No description provided for @contStopFollow.
  ///
  /// In en, this message translates to:
  /// **'Stop following'**
  String get contStopFollow;

  /// No description provided for @contMyLocation.
  ///
  /// In en, this message translates to:
  /// **'My location'**
  String get contMyLocation;

  /// No description provided for @contFitAll.
  ///
  /// In en, this message translates to:
  /// **'Show all'**
  String get contFitAll;

  /// No description provided for @contMeasureOff.
  ///
  /// In en, this message translates to:
  /// **'Stop measuring'**
  String get contMeasureOff;

  /// No description provided for @contMeasure.
  ///
  /// In en, this message translates to:
  /// **'Measure distance'**
  String get contMeasure;

  /// No description provided for @contPinPlaced.
  ///
  /// In en, this message translates to:
  /// **'Location pinned. Tap “My location” to go back to GPS.'**
  String get contPinPlaced;

  /// No description provided for @contPinnedSpot.
  ///
  /// In en, this message translates to:
  /// **'Pinned spot'**
  String get contPinnedSpot;

  /// No description provided for @contYouAreHere.
  ///
  /// In en, this message translates to:
  /// **'You are here'**
  String get contYouAreHere;

  /// No description provided for @contGoogleLimited.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Google quota is used up. Showing saved contractors only.'**
  String get contGoogleLimited;

  /// No description provided for @contGoogleBusy.
  ///
  /// In en, this message translates to:
  /// **'Searching too often. Wait a moment and try again.'**
  String get contGoogleBusy;

  /// No description provided for @contGoogleDown.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach Google right now. Showing saved contractors only.'**
  String get contGoogleDown;

  /// No description provided for @contGoogleIncluded.
  ///
  /// In en, this message translates to:
  /// **'Includes places from Google'**
  String get contGoogleIncluded;

  /// No description provided for @contGoogleIncludedListOnly.
  ///
  /// In en, this message translates to:
  /// **'Includes places from Google (list only)'**
  String get contGoogleIncludedListOnly;

  /// No description provided for @contGoogleLeft.
  ///
  /// In en, this message translates to:
  /// **'{left, plural, =1{1 Google lookup left today} other{{left} Google lookups left today}}'**
  String contGoogleLeft(int left);

  /// No description provided for @contGoogleHowTo.
  ///
  /// In en, this message translates to:
  /// **'Tap a trade or type to find places on Google'**
  String get contGoogleHowTo;

  /// No description provided for @contNeedLocation.
  ///
  /// In en, this message translates to:
  /// **'Your location is needed to find contractors near you'**
  String get contNeedLocation;

  /// No description provided for @contLocateAgain.
  ///
  /// In en, this message translates to:
  /// **'Locate me again'**
  String get contLocateAgain;

  /// No description provided for @contLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load contractors'**
  String get contLoadFailed;

  /// No description provided for @contNoFavorites.
  ///
  /// In en, this message translates to:
  /// **'No favorites yet'**
  String get contNoFavorites;

  /// No description provided for @contNoFavoritesHint.
  ///
  /// In en, this message translates to:
  /// **'Tap the star on a contractor you trust to keep them here'**
  String get contNoFavoritesHint;

  /// No description provided for @contNoneInRadius.
  ///
  /// In en, this message translates to:
  /// **'No contractors within the chosen radius'**
  String get contNoneInRadius;

  /// No description provided for @contWidenRadius.
  ///
  /// In en, this message translates to:
  /// **'Widen the radius to {km} km'**
  String contWidenRadius(int km);

  /// No description provided for @contSeeMore.
  ///
  /// In en, this message translates to:
  /// **'See more ({hidden} left)'**
  String contSeeMore(int hidden);

  /// No description provided for @contNearYou.
  ///
  /// In en, this message translates to:
  /// **'Contractors near you'**
  String get contNearYou;

  /// No description provided for @contFound.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 found} other{{count} found}}'**
  String contFound(int count);

  /// No description provided for @contSearchHere.
  ///
  /// In en, this message translates to:
  /// **'Search this area'**
  String get contSearchHere;

  /// No description provided for @contSearchHint.
  ///
  /// In en, this message translates to:
  /// **'Search for a trade or shop, e.g. electrician'**
  String get contSearchHint;

  /// No description provided for @contOpenNow.
  ///
  /// In en, this message translates to:
  /// **'Open'**
  String get contOpenNow;

  /// No description provided for @contClosedNow.
  ///
  /// In en, this message translates to:
  /// **'Closed'**
  String get contClosedNow;

  /// No description provided for @contStarRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove from favorites'**
  String get contStarRemove;

  /// No description provided for @contStarAdd.
  ///
  /// In en, this message translates to:
  /// **'Add to favorites'**
  String get contStarAdd;

  /// No description provided for @contCall.
  ///
  /// In en, this message translates to:
  /// **'Call'**
  String get contCall;

  /// No description provided for @contDirections.
  ///
  /// In en, this message translates to:
  /// **'Directions'**
  String get contDirections;

  /// No description provided for @contWebsite.
  ///
  /// In en, this message translates to:
  /// **'Website'**
  String get contWebsite;

  /// No description provided for @contOpenInGoogle.
  ///
  /// In en, this message translates to:
  /// **'Open in Google Maps'**
  String get contOpenInGoogle;

  /// No description provided for @contMeasureHint0.
  ///
  /// In en, this message translates to:
  /// **'Tap the map or a contractor pin to start measuring'**
  String get contMeasureHint0;

  /// No description provided for @contMeasureHint1.
  ///
  /// In en, this message translates to:
  /// **'Tap the next point to measure'**
  String get contMeasureHint1;

  /// No description provided for @contMeasureHintMore.
  ///
  /// In en, this message translates to:
  /// **'Tap to extend the route (straight lines between points)'**
  String get contMeasureHintMore;

  /// No description provided for @contPoints.
  ///
  /// In en, this message translates to:
  /// **'({points} points)'**
  String contPoints(int points);

  /// No description provided for @contStartFromMe.
  ///
  /// In en, this message translates to:
  /// **'Start from my location'**
  String get contStartFromMe;

  /// No description provided for @contUndo.
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get contUndo;

  /// No description provided for @contDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get contDone;

  /// No description provided for @contRadiusTitle.
  ///
  /// In en, this message translates to:
  /// **'Search radius'**
  String get contRadiusTitle;

  /// No description provided for @contRadiusFromYou.
  ///
  /// In en, this message translates to:
  /// **'{km} km from your location'**
  String contRadiusFromYou(int km);

  /// No description provided for @contTypeElectrician.
  ///
  /// In en, this message translates to:
  /// **'Electrician'**
  String get contTypeElectrician;

  /// No description provided for @contTypePlumber.
  ///
  /// In en, this message translates to:
  /// **'Plumber'**
  String get contTypePlumber;

  /// No description provided for @contTypeCarpenter.
  ///
  /// In en, this message translates to:
  /// **'Carpenter'**
  String get contTypeCarpenter;

  /// No description provided for @contTypeHvac.
  ///
  /// In en, this message translates to:
  /// **'AC technician'**
  String get contTypeHvac;

  /// No description provided for @contTypeOther.
  ///
  /// In en, this message translates to:
  /// **'General contractor'**
  String get contTypeOther;

  /// No description provided for @locServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location Services are turned off on this device'**
  String get locServiceOff;

  /// No description provided for @locOpenSettings.
  ///
  /// In en, this message translates to:
  /// **'Open settings'**
  String get locOpenSettings;

  /// No description provided for @locDenied.
  ///
  /// In en, this message translates to:
  /// **'The app isn\'t allowed to use your location yet'**
  String get locDenied;

  /// No description provided for @locAllow.
  ///
  /// In en, this message translates to:
  /// **'Allow'**
  String get locAllow;

  /// No description provided for @locBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location access is blocked. You can enable it in the app\'s settings'**
  String get locBlocked;

  /// No description provided for @locUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t find your current location (on a Simulator, set a location first)'**
  String get locUnavailable;

  /// No description provided for @locErrServiceOff.
  ///
  /// In en, this message translates to:
  /// **'Location services are turned off.'**
  String get locErrServiceOff;

  /// No description provided for @locErrDenied.
  ///
  /// In en, this message translates to:
  /// **'Location permission was denied.'**
  String get locErrDenied;

  /// No description provided for @locErrBlocked.
  ///
  /// In en, this message translates to:
  /// **'Location permission is blocked. Enable it in Settings.'**
  String get locErrBlocked;

  /// No description provided for @locErrUnknown.
  ///
  /// In en, this message translates to:
  /// **'Could not determine your location.'**
  String get locErrUnknown;

  /// No description provided for @authInvalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password'**
  String get authInvalidCredentials;

  /// No description provided for @authLoginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sign in to manage your home tasks and services.'**
  String get authLoginSubtitle;

  /// No description provided for @authEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authEmail;

  /// No description provided for @authEmailRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email'**
  String get authEmailRequired;

  /// No description provided for @authEmailInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format'**
  String get authEmailInvalid;

  /// No description provided for @authPassword.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authPassword;

  /// No description provided for @authShowPassword.
  ///
  /// In en, this message translates to:
  /// **'Show password'**
  String get authShowPassword;

  /// No description provided for @authHidePassword.
  ///
  /// In en, this message translates to:
  /// **'Hide password'**
  String get authHidePassword;

  /// No description provided for @authPasswordRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your password'**
  String get authPasswordRequired;

  /// No description provided for @authForgot.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authForgot;

  /// No description provided for @authCreateAccountLink.
  ///
  /// In en, this message translates to:
  /// **'Create an account'**
  String get authCreateAccountLink;

  /// No description provided for @authPrivacyNote.
  ///
  /// In en, this message translates to:
  /// **'We keep your information secure and private.'**
  String get authPrivacyNote;

  /// No description provided for @authRegisterTitle.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get authRegisterTitle;

  /// No description provided for @authRegisterSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join HomeHQ to run your household in one place.'**
  String get authRegisterSubtitle;

  /// No description provided for @authFullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get authFullName;

  /// No description provided for @authNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Please enter your name'**
  String get authNameRequired;

  /// No description provided for @authNameShort.
  ///
  /// In en, this message translates to:
  /// **'Name is too short'**
  String get authNameShort;

  /// No description provided for @authPasswordNew.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password'**
  String get authPasswordNew;

  /// No description provided for @authPasswordMin.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get authPasswordMin;

  /// No description provided for @authConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get authConfirmPassword;

  /// No description provided for @authConfirmRequired.
  ///
  /// In en, this message translates to:
  /// **'Please confirm your password'**
  String get authConfirmRequired;

  /// No description provided for @authPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get authPasswordMismatch;

  /// No description provided for @authTerms.
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our Terms and Privacy Policy.'**
  String get authTerms;

  /// No description provided for @authCreating.
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get authCreating;

  /// No description provided for @authCreateAccount.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authCreateAccount;

  /// No description provided for @authSignInInstead.
  ///
  /// In en, this message translates to:
  /// **'Sign in instead'**
  String get authSignInInstead;

  /// No description provided for @authRegisterFailed.
  ///
  /// In en, this message translates to:
  /// **'Unable to create the account. Please try again.'**
  String get authRegisterFailed;

  /// No description provided for @authResetSendFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send the reset email. Please try again.'**
  String get authResetSendFailed;

  /// No description provided for @authGenericFailed.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get authGenericFailed;

  /// No description provided for @authForgotTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get authForgotTitle;

  /// No description provided for @authResetTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get authResetTitle;

  /// No description provided for @authResetHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your email address and we’ll send you a reset link.'**
  String get authResetHint;

  /// No description provided for @authSending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get authSending;

  /// No description provided for @authSendLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get authSendLink;

  /// No description provided for @authBackToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get authBackToSignIn;

  /// No description provided for @authCheckInbox.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox'**
  String get authCheckInbox;

  /// No description provided for @authSentBody.
  ///
  /// In en, this message translates to:
  /// **'We’ve sent a password reset link to your email.\nIf you don’t see it, check your spam folder.'**
  String get authSentBody;

  /// No description provided for @authResend.
  ///
  /// In en, this message translates to:
  /// **'Resend link'**
  String get authResend;

  /// No description provided for @authUnexpected.
  ///
  /// In en, this message translates to:
  /// **'Unexpected error'**
  String get authUnexpected;

  /// No description provided for @authUnknownError.
  ///
  /// In en, this message translates to:
  /// **'Unknown error'**
  String get authUnknownError;

  /// No description provided for @authNetworkError.
  ///
  /// In en, this message translates to:
  /// **'Network error ({status})'**
  String authNetworkError(String status);

  /// No description provided for @routeError.
  ///
  /// In en, this message translates to:
  /// **'Page error: {error}'**
  String routeError(String error);

  /// No description provided for @camEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No cameras found'**
  String get camEmptyTitle;

  /// No description provided for @camEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Add a camera in the Imou app and it will show up here.'**
  String get camEmptyHint;

  /// No description provided for @camDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Cameras aren\'t set up yet'**
  String get camDisabledTitle;

  /// No description provided for @camDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'The server needs the camera account details before the cameras can show here.'**
  String get camDisabledHint;

  /// No description provided for @camOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get camOffline;

  /// No description provided for @camLive.
  ///
  /// In en, this message translates to:
  /// **'LIVE'**
  String get camLive;

  /// No description provided for @camOfflineToast.
  ///
  /// In en, this message translates to:
  /// **'This camera is offline right now'**
  String get camOfflineToast;

  /// No description provided for @camLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the cameras'**
  String get camLoadFailed;

  /// No description provided for @camErrMisconfigured.
  ///
  /// In en, this message translates to:
  /// **'The camera account details on the server were rejected'**
  String get camErrMisconfigured;

  /// No description provided for @camErrLimit.
  ///
  /// In en, this message translates to:
  /// **'The camera service has reached its call limit. Try again later.'**
  String get camErrLimit;

  /// No description provided for @camErrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the camera service'**
  String get camErrUnavailable;

  /// No description provided for @camErrOffline.
  ///
  /// In en, this message translates to:
  /// **'The camera is offline'**
  String get camErrOffline;

  /// No description provided for @camPlayerFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t play the stream'**
  String get camPlayerFailed;

  /// No description provided for @camMute.
  ///
  /// In en, this message translates to:
  /// **'Mute'**
  String get camMute;

  /// No description provided for @camUnmute.
  ///
  /// In en, this message translates to:
  /// **'Unmute'**
  String get camUnmute;

  /// No description provided for @camQuality.
  ///
  /// In en, this message translates to:
  /// **'Quality'**
  String get camQuality;

  /// No description provided for @camPausedIdle.
  ///
  /// In en, this message translates to:
  /// **'Paused to save data'**
  String get camPausedIdle;

  /// No description provided for @camResume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get camResume;

  /// No description provided for @camHumanDetect.
  ///
  /// In en, this message translates to:
  /// **'Detects people'**
  String get camHumanDetect;

  /// No description provided for @camConnecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting…'**
  String get camConnecting;

  /// No description provided for @camCameras.
  ///
  /// In en, this message translates to:
  /// **'Cameras'**
  String get camCameras;

  /// No description provided for @camSwipeHint.
  ///
  /// In en, this message translates to:
  /// **'Swipe left or right to switch cameras'**
  String get camSwipeHint;

  /// No description provided for @camPosition.
  ///
  /// In en, this message translates to:
  /// **'{index} of {total}'**
  String camPosition(int index, int total);

  /// No description provided for @camFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Full screen'**
  String get camFullscreen;

  /// No description provided for @camExitFullscreen.
  ///
  /// In en, this message translates to:
  /// **'Exit full screen'**
  String get camExitFullscreen;

  /// No description provided for @camPtzTitle.
  ///
  /// In en, this message translates to:
  /// **'Move the camera'**
  String get camPtzTitle;

  /// No description provided for @camPtzHint.
  ///
  /// In en, this message translates to:
  /// **'Hold a button to keep moving'**
  String get camPtzHint;

  /// No description provided for @camPtzUp.
  ///
  /// In en, this message translates to:
  /// **'Tilt up'**
  String get camPtzUp;

  /// No description provided for @camPtzDown.
  ///
  /// In en, this message translates to:
  /// **'Tilt down'**
  String get camPtzDown;

  /// No description provided for @camPtzLeft.
  ///
  /// In en, this message translates to:
  /// **'Pan left'**
  String get camPtzLeft;

  /// No description provided for @camPtzRight.
  ///
  /// In en, this message translates to:
  /// **'Pan right'**
  String get camPtzRight;

  /// No description provided for @camPtzStop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get camPtzStop;

  /// No description provided for @camZoomIn.
  ///
  /// In en, this message translates to:
  /// **'Zoom in'**
  String get camZoomIn;

  /// No description provided for @camZoomOut.
  ///
  /// In en, this message translates to:
  /// **'Zoom out'**
  String get camZoomOut;

  /// No description provided for @camPtzFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t move the camera'**
  String get camPtzFailed;

  /// No description provided for @camSettingsTitle.
  ///
  /// In en, this message translates to:
  /// **'Camera settings'**
  String get camSettingsTitle;

  /// No description provided for @camSwitchPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Privacy mode'**
  String get camSwitchPrivacy;

  /// No description provided for @camSwitchPrivacyHint.
  ///
  /// In en, this message translates to:
  /// **'Turns the camera view off'**
  String get camSwitchPrivacyHint;

  /// No description provided for @camSwitchMotion.
  ///
  /// In en, this message translates to:
  /// **'Motion detection'**
  String get camSwitchMotion;

  /// No description provided for @camSwitchHuman.
  ///
  /// In en, this message translates to:
  /// **'Person detection'**
  String get camSwitchHuman;

  /// No description provided for @camSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change the setting'**
  String get camSwitchFailed;

  /// No description provided for @camSwitchesLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the settings'**
  String get camSwitchesLoadFailed;

  /// No description provided for @camNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This camera doesn\'t support that'**
  String get camNotSupported;

  /// No description provided for @camSwitchLight.
  ///
  /// In en, this message translates to:
  /// **'Camera light'**
  String get camSwitchLight;

  /// No description provided for @camSwitchLightHint.
  ///
  /// In en, this message translates to:
  /// **'Turns the camera\'s built-in light on or off'**
  String get camSwitchLightHint;

  /// No description provided for @camSwitchLightAuto.
  ///
  /// In en, this message translates to:
  /// **'Light on motion'**
  String get camSwitchLightAuto;

  /// Toast shown right after a successful sign-in.
  ///
  /// In en, this message translates to:
  /// **'Signed in'**
  String get authSignedIn;

  /// Toast shown right after the user signs out.
  ///
  /// In en, this message translates to:
  /// **'Signed out'**
  String get authSignedOut;

  /// Home header greeting, 05:00-11:59.
  ///
  /// In en, this message translates to:
  /// **'Good morning'**
  String get homeGreetingMorning;

  /// Home header greeting, 12:00-16:59.
  ///
  /// In en, this message translates to:
  /// **'Good afternoon'**
  String get homeGreetingAfternoon;

  /// Home header greeting, 17:00-20:59.
  ///
  /// In en, this message translates to:
  /// **'Good evening'**
  String get homeGreetingEvening;

  /// Home header greeting, 21:00-04:59.
  ///
  /// In en, this message translates to:
  /// **'Hello'**
  String get homeGreetingLate;

  /// Small label on the Home tool the user opened last.
  ///
  /// In en, this message translates to:
  /// **'Last used'**
  String get homeLastUsed;

  /// No description provided for @accountTitle.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get accountTitle;

  /// No description provided for @accountOpen.
  ///
  /// In en, this message translates to:
  /// **'Open your account'**
  String get accountOpen;

  /// No description provided for @accountProfileSection.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get accountProfileSection;

  /// No description provided for @accountName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get accountName;

  /// No description provided for @accountEmail.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmail;

  /// No description provided for @roleAdmin.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get roleAdmin;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @accountEditName.
  ///
  /// In en, this message translates to:
  /// **'Edit name'**
  String get accountEditName;

  /// No description provided for @accountNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a name'**
  String get accountNameRequired;

  /// No description provided for @accountNameSaved.
  ///
  /// In en, this message translates to:
  /// **'Name updated'**
  String get accountNameSaved;

  /// No description provided for @accountSaveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save. Try again.'**
  String get accountSaveFailed;

  /// No description provided for @accountSecuritySection.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get accountSecuritySection;

  /// No description provided for @accountChangePassword.
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountChangePassword;

  /// No description provided for @accountCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get accountCurrentPassword;

  /// No description provided for @accountNewPassword.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get accountNewPassword;

  /// No description provided for @accountConfirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get accountConfirmPassword;

  /// No description provided for @accountPasswordTooShort.
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get accountPasswordTooShort;

  /// No description provided for @accountPasswordMismatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get accountPasswordMismatch;

  /// No description provided for @accountPasswordWrong.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect'**
  String get accountPasswordWrong;

  /// No description provided for @accountPasswordChanged.
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get accountPasswordChanged;

  /// No description provided for @accountPreferencesSection.
  ///
  /// In en, this message translates to:
  /// **'Preferences'**
  String get accountPreferencesSection;

  /// No description provided for @accountSignOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get accountSignOut;

  /// No description provided for @accountCurrentRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter your current password'**
  String get accountCurrentRequired;

  /// Home Cameras card: how many cameras are online.
  ///
  /// In en, this message translates to:
  /// **'{online} of {total} online'**
  String camOnlineCount(int online, int total);

  /// No description provided for @errNetwork.
  ///
  /// In en, this message translates to:
  /// **'Can\'t reach the server. Check your connection and try again.'**
  String get errNetwork;

  /// No description provided for @errSession.
  ///
  /// In en, this message translates to:
  /// **'Your session has expired. Please sign in again.'**
  String get errSession;

  /// No description provided for @errForbidden.
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission to do this.'**
  String get errForbidden;

  /// No description provided for @errNotFound.
  ///
  /// In en, this message translates to:
  /// **'We couldn\'t find that.'**
  String get errNotFound;

  /// No description provided for @errServer.
  ///
  /// In en, this message translates to:
  /// **'The server ran into a problem. Please try again in a moment.'**
  String get errServer;

  /// No description provided for @billsNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No bills match'**
  String get billsNoMatchTitle;

  /// No description provided for @billsNoMatchHint.
  ///
  /// In en, this message translates to:
  /// **'Try another word, or clear the filters.'**
  String get billsNoMatchHint;

  /// No description provided for @medNoMatchTitle.
  ///
  /// In en, this message translates to:
  /// **'No medicine matches'**
  String get medNoMatchTitle;

  /// No description provided for @medNoMatchHint.
  ///
  /// In en, this message translates to:
  /// **'Try another name, or clear the search.'**
  String get medNoMatchHint;

  /// No description provided for @notesEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No notes yet'**
  String get notesEmptyTitle;

  /// No description provided for @notesEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Tap + to write the first one.'**
  String get notesEmptyHint;

  /// No description provided for @notesNoMatchHint.
  ///
  /// In en, this message translates to:
  /// **'Try another word, or clear the filters.'**
  String get notesNoMatchHint;

  /// No description provided for @commonMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get commonMore;

  /// No description provided for @purchTake.
  ///
  /// In en, this message translates to:
  /// **'I\'ll buy this'**
  String get purchTake;

  /// No description provided for @purchMarkBought.
  ///
  /// In en, this message translates to:
  /// **'Mark as bought'**
  String get purchMarkBought;

  /// No description provided for @purchMarkDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark as delivered'**
  String get purchMarkDelivered;

  /// No description provided for @purchPaidTitle.
  ///
  /// In en, this message translates to:
  /// **'How much did you pay?'**
  String get purchPaidTitle;

  /// No description provided for @purchPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount paid'**
  String get purchPaidLabel;

  /// No description provided for @purchPaidInvalid.
  ///
  /// In en, this message translates to:
  /// **'Enter an amount'**
  String get purchPaidInvalid;

  /// No description provided for @purchCancelPurchase.
  ///
  /// In en, this message translates to:
  /// **'Cancel this purchase'**
  String get purchCancelPurchase;

  /// No description provided for @purchCancelAsk.
  ///
  /// In en, this message translates to:
  /// **'Cancel this purchase?'**
  String get purchCancelAsk;

  /// No description provided for @purchCancelKeep.
  ///
  /// In en, this message translates to:
  /// **'Keep it'**
  String get purchCancelKeep;

  /// No description provided for @purchStatusUpdated.
  ///
  /// In en, this message translates to:
  /// **'Status updated'**
  String get purchStatusUpdated;

  /// No description provided for @purchCancelled.
  ///
  /// In en, this message translates to:
  /// **'Purchase cancelled'**
  String get purchCancelled;

  /// No description provided for @toolAppliancesCaption.
  ///
  /// In en, this message translates to:
  /// **'Switch lights, plugs and aircon'**
  String get toolAppliancesCaption;

  /// No description provided for @applDisabledTitle.
  ///
  /// In en, this message translates to:
  /// **'Appliances aren\'t set up yet'**
  String get applDisabledTitle;

  /// No description provided for @applDisabledHint.
  ///
  /// In en, this message translates to:
  /// **'The server needs an appliance source before they can show here.'**
  String get applDisabledHint;

  /// No description provided for @applEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'No appliances found'**
  String get applEmptyTitle;

  /// No description provided for @applEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Appliances connected to the server will show up here.'**
  String get applEmptyHint;

  /// No description provided for @applLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the appliances'**
  String get applLoadFailed;

  /// No description provided for @applErrUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reach the appliance service'**
  String get applErrUnavailable;

  /// No description provided for @applErrMisconfigured.
  ///
  /// In en, this message translates to:
  /// **'The appliance account details on the server were rejected'**
  String get applErrMisconfigured;

  /// No description provided for @applErrLimit.
  ///
  /// In en, this message translates to:
  /// **'The appliance service has reached its call limit. Try again later.'**
  String get applErrLimit;

  /// No description provided for @applErrOffline.
  ///
  /// In en, this message translates to:
  /// **'This appliance is offline'**
  String get applErrOffline;

  /// No description provided for @applErrNotSupported.
  ///
  /// In en, this message translates to:
  /// **'This appliance doesn\'t support that'**
  String get applErrNotSupported;

  /// No description provided for @applErrInvalid.
  ///
  /// In en, this message translates to:
  /// **'That value isn\'t accepted'**
  String get applErrInvalid;

  /// No description provided for @applOfflineToast.
  ///
  /// In en, this message translates to:
  /// **'This appliance is offline right now'**
  String get applOfflineToast;

  /// No description provided for @applSwitchFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t change {name}'**
  String applSwitchFailed(String name);

  /// No description provided for @applOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get applOn;

  /// No description provided for @applOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get applOff;

  /// No description provided for @applOffline.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get applOffline;

  /// No description provided for @applNoRoom.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get applNoRoom;

  /// No description provided for @applCapPower.
  ///
  /// In en, this message translates to:
  /// **'Power'**
  String get applCapPower;

  /// No description provided for @applCapBrightness.
  ///
  /// In en, this message translates to:
  /// **'Brightness'**
  String get applCapBrightness;

  /// No description provided for @applCapTemperature.
  ///
  /// In en, this message translates to:
  /// **'Temperature'**
  String get applCapTemperature;

  /// No description provided for @applCapMode.
  ///
  /// In en, this message translates to:
  /// **'Mode'**
  String get applCapMode;

  /// No description provided for @applCapFanSpeed.
  ///
  /// In en, this message translates to:
  /// **'Fan speed'**
  String get applCapFanSpeed;

  /// No description provided for @applModeAuto.
  ///
  /// In en, this message translates to:
  /// **'Auto'**
  String get applModeAuto;

  /// No description provided for @applModeCool.
  ///
  /// In en, this message translates to:
  /// **'Cool'**
  String get applModeCool;

  /// No description provided for @applModeDry.
  ///
  /// In en, this message translates to:
  /// **'Dry'**
  String get applModeDry;

  /// No description provided for @applModeFan.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get applModeFan;

  /// No description provided for @applModeHeat.
  ///
  /// In en, this message translates to:
  /// **'Heat'**
  String get applModeHeat;

  /// No description provided for @applAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only an admin can change this'**
  String get applAdminOnly;

  /// No description provided for @applHeaterNote.
  ///
  /// In en, this message translates to:
  /// **'For safety, this switches itself off after a while.'**
  String get applHeaterNote;

  /// No description provided for @applActivityTitle.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get applActivityTitle;

  /// No description provided for @applActivityEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet'**
  String get applActivityEmpty;

  /// No description provided for @applActivityFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the activity'**
  String get applActivityFailed;

  /// No description provided for @applAutoOffEvent.
  ///
  /// In en, this message translates to:
  /// **'Switched off automatically'**
  String get applAutoOffEvent;

  /// No description provided for @applSomeone.
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get applSomeone;

  /// No description provided for @applEventOn.
  ///
  /// In en, this message translates to:
  /// **'{who} switched it on'**
  String applEventOn(String who);

  /// No description provided for @applEventOff.
  ///
  /// In en, this message translates to:
  /// **'{who} switched it off'**
  String applEventOff(String who);

  /// No description provided for @applEventSet.
  ///
  /// In en, this message translates to:
  /// **'{who} set {what} to {value}'**
  String applEventSet(String who, String what, String value);

  /// No description provided for @applAddTitle.
  ///
  /// In en, this message translates to:
  /// **'Add an appliance'**
  String get applAddTitle;

  /// No description provided for @applAddButton.
  ///
  /// In en, this message translates to:
  /// **'Add appliance'**
  String get applAddButton;

  /// No description provided for @applAddFirst.
  ///
  /// In en, this message translates to:
  /// **'Add your first appliance'**
  String get applAddFirst;

  /// No description provided for @applAddAdminOnly.
  ///
  /// In en, this message translates to:
  /// **'Only an admin can add appliances'**
  String get applAddAdminOnly;

  /// No description provided for @applStepKind.
  ///
  /// In en, this message translates to:
  /// **'What is it?'**
  String get applStepKind;

  /// No description provided for @applStepDetails.
  ///
  /// In en, this message translates to:
  /// **'About it'**
  String get applStepDetails;

  /// No description provided for @applStepConnect.
  ///
  /// In en, this message translates to:
  /// **'How it connects'**
  String get applStepConnect;

  /// No description provided for @applStepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String applStepOf(String step, String total);

  /// No description provided for @applNext.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get applNext;

  /// No description provided for @applBack.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get applBack;

  /// No description provided for @applKindAircon.
  ///
  /// In en, this message translates to:
  /// **'Air conditioner'**
  String get applKindAircon;

  /// No description provided for @applKindLight.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get applKindLight;

  /// No description provided for @applKindFan.
  ///
  /// In en, this message translates to:
  /// **'Fan'**
  String get applKindFan;

  /// No description provided for @applKindPlug.
  ///
  /// In en, this message translates to:
  /// **'Smart plug'**
  String get applKindPlug;

  /// No description provided for @applKindHeater.
  ///
  /// In en, this message translates to:
  /// **'Heater'**
  String get applKindHeater;

  /// No description provided for @applKindOther.
  ///
  /// In en, this message translates to:
  /// **'Something else'**
  String get applKindOther;

  /// No description provided for @applKindAirconHint.
  ///
  /// In en, this message translates to:
  /// **'Wind animation, temperature, mode, fan speed and swing'**
  String get applKindAirconHint;

  /// No description provided for @applKindLightHint.
  ///
  /// In en, this message translates to:
  /// **'On, off and brightness'**
  String get applKindLightHint;

  /// No description provided for @applKindFanHint.
  ///
  /// In en, this message translates to:
  /// **'On, off and speed'**
  String get applKindFanHint;

  /// No description provided for @applKindPlugHint.
  ///
  /// In en, this message translates to:
  /// **'On and off'**
  String get applKindPlugHint;

  /// No description provided for @applKindHeaterHint.
  ///
  /// In en, this message translates to:
  /// **'On and off, with a safety switch-off'**
  String get applKindHeaterHint;

  /// No description provided for @applKindOtherHint.
  ///
  /// In en, this message translates to:
  /// **'On and off'**
  String get applKindOtherHint;

  /// No description provided for @applFieldName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get applFieldName;

  /// No description provided for @applFieldNameHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. Bedroom aircon'**
  String get applFieldNameHint;

  /// No description provided for @applFieldRoom.
  ///
  /// In en, this message translates to:
  /// **'Room'**
  String get applFieldRoom;

  /// No description provided for @applFieldBrand.
  ///
  /// In en, this message translates to:
  /// **'Brand'**
  String get applFieldBrand;

  /// No description provided for @applFieldModel.
  ///
  /// In en, this message translates to:
  /// **'Model'**
  String get applFieldModel;

  /// No description provided for @applFieldModelHint.
  ///
  /// In en, this message translates to:
  /// **'e.g. FTKM25: printed on the indoor unit or the remote'**
  String get applFieldModelHint;

  /// No description provided for @applFieldOptional.
  ///
  /// In en, this message translates to:
  /// **'optional'**
  String get applFieldOptional;

  /// No description provided for @applFieldRequired.
  ///
  /// In en, this message translates to:
  /// **'Give it a name'**
  String get applFieldRequired;

  /// No description provided for @applRoomLiving.
  ///
  /// In en, this message translates to:
  /// **'Living room'**
  String get applRoomLiving;

  /// No description provided for @applRoomBedroom.
  ///
  /// In en, this message translates to:
  /// **'Bedroom'**
  String get applRoomBedroom;

  /// No description provided for @applRoomKitchen.
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get applRoomKitchen;

  /// No description provided for @applRoomBathroom.
  ///
  /// In en, this message translates to:
  /// **'Bathroom'**
  String get applRoomBathroom;

  /// No description provided for @applRoomStudy.
  ///
  /// In en, this message translates to:
  /// **'Study'**
  String get applRoomStudy;

  /// No description provided for @applRoomGarage.
  ///
  /// In en, this message translates to:
  /// **'Garage'**
  String get applRoomGarage;

  /// No description provided for @applRoomOther.
  ///
  /// In en, this message translates to:
  /// **'Other room…'**
  String get applRoomOther;

  /// No description provided for @applRoomCustomHint.
  ///
  /// In en, this message translates to:
  /// **'Room name'**
  String get applRoomCustomHint;

  /// No description provided for @applConnTitle.
  ///
  /// In en, this message translates to:
  /// **'How will it be controlled?'**
  String get applConnTitle;

  /// No description provided for @applConnDemo.
  ///
  /// In en, this message translates to:
  /// **'Simulated'**
  String get applConnDemo;

  /// No description provided for @applConnDemoSummary.
  ///
  /// In en, this message translates to:
  /// **'Try the controls and the animation. Nothing real is switched.'**
  String get applConnDemoSummary;

  /// No description provided for @applConnWifi.
  ///
  /// In en, this message translates to:
  /// **'Wi-Fi built in'**
  String get applConnWifi;

  /// No description provided for @applConnWifiSummary.
  ///
  /// In en, this message translates to:
  /// **'The air conditioner, or its Wi-Fi adapter, talks to its maker\'s cloud.'**
  String get applConnWifiSummary;

  /// No description provided for @applConnIr.
  ///
  /// In en, this message translates to:
  /// **'Smart IR remote'**
  String get applConnIr;

  /// No description provided for @applConnIrSummary.
  ///
  /// In en, this message translates to:
  /// **'A Wi-Fi IR blaster sends the signals your remote would.'**
  String get applConnIrSummary;

  /// No description provided for @applConnHa.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant'**
  String get applConnHa;

  /// No description provided for @applConnHaSummary.
  ///
  /// In en, this message translates to:
  /// **'Use an air conditioner you already added to Home Assistant.'**
  String get applConnHaSummary;

  /// No description provided for @applConnSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming soon'**
  String get applConnSoon;

  /// No description provided for @applConnNeed.
  ///
  /// In en, this message translates to:
  /// **'What you need'**
  String get applConnNeed;

  /// No description provided for @applConnUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This connection isn\'t available yet. Add it as simulated to try it out.'**
  String get applConnUnavailable;

  /// No description provided for @applReqDemo1.
  ///
  /// In en, this message translates to:
  /// **'Nothing. The server simulates it.'**
  String get applReqDemo1;

  /// No description provided for @applReqWifi1.
  ///
  /// In en, this message translates to:
  /// **'An air conditioner with Wi-Fi built in, or its maker\'s Wi-Fi adapter fitted'**
  String get applReqWifi1;

  /// No description provided for @applReqWifi2.
  ///
  /// In en, this message translates to:
  /// **'A 2.4 GHz Wi-Fi network (most air conditioners cannot use 5 GHz)'**
  String get applReqWifi2;

  /// No description provided for @applReqWifi3.
  ///
  /// In en, this message translates to:
  /// **'The maker\'s app set up with this air conditioner (Daikin Mobile, MELCloud, Comfort Cloud, ThinQ, SmartThings…)'**
  String get applReqWifi3;

  /// No description provided for @applReqWifi4.
  ///
  /// In en, this message translates to:
  /// **'A HomeHQ driver for that maker on the server'**
  String get applReqWifi4;

  /// No description provided for @applReqIr1.
  ///
  /// In en, this message translates to:
  /// **'A Wi-Fi smart IR remote (Tuya / Smart Life, Broadlink, Sonoff, Xiaomi…)'**
  String get applReqIr1;

  /// No description provided for @applReqIr2.
  ///
  /// In en, this message translates to:
  /// **'Placed in view of the air conditioner\'s receiver, within a few metres'**
  String get applReqIr2;

  /// No description provided for @applReqIr3.
  ///
  /// In en, this message translates to:
  /// **'Your air conditioner\'s model in the remote\'s code library, or its codes learned from your own remote'**
  String get applReqIr3;

  /// No description provided for @applReqIr4.
  ///
  /// In en, this message translates to:
  /// **'A 2.4 GHz Wi-Fi network and an account for the remote\'s app'**
  String get applReqIr4;

  /// No description provided for @applReqIrNote.
  ///
  /// In en, this message translates to:
  /// **'IR is one-way: the app cannot read what the air conditioner is really doing, only what it last sent.'**
  String get applReqIrNote;

  /// No description provided for @applReqHa1.
  ///
  /// In en, this message translates to:
  /// **'Home Assistant running on your network, with the air conditioner added as a climate device'**
  String get applReqHa1;

  /// No description provided for @applReqHa2.
  ///
  /// In en, this message translates to:
  /// **'A long-lived access token from your Home Assistant profile'**
  String get applReqHa2;

  /// No description provided for @applReqHa3.
  ///
  /// In en, this message translates to:
  /// **'The HomeHQ server able to reach Home Assistant'**
  String get applReqHa3;

  /// No description provided for @applAddedToast.
  ///
  /// In en, this message translates to:
  /// **'{name} added'**
  String applAddedToast(String name);

  /// No description provided for @applAddFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add the appliance'**
  String get applAddFailed;

  /// No description provided for @applRemove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get applRemove;

  /// No description provided for @applRemoveAsk.
  ///
  /// In en, this message translates to:
  /// **'Remove {name}?'**
  String applRemoveAsk(String name);

  /// No description provided for @applRemoveBody.
  ///
  /// In en, this message translates to:
  /// **'It is forgotten here. Nothing is switched off or changed on a real device.'**
  String get applRemoveBody;

  /// No description provided for @applRemovedToast.
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String applRemovedToast(String name);

  /// No description provided for @applRemoveFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove it'**
  String get applRemoveFailed;

  /// No description provided for @applCapSwing.
  ///
  /// In en, this message translates to:
  /// **'Swing'**
  String get applCapSwing;

  /// No description provided for @applSimulated.
  ///
  /// In en, this message translates to:
  /// **'Simulated'**
  String get applSimulated;

  /// No description provided for @applAirconOn.
  ///
  /// In en, this message translates to:
  /// **'Air conditioner on, {mode}, {temp}'**
  String applAirconOn(String mode, String temp);

  /// No description provided for @applAirconOff.
  ///
  /// In en, this message translates to:
  /// **'Air conditioner off'**
  String get applAirconOff;

  /// No description provided for @toolDashboardCaption.
  ///
  /// In en, this message translates to:
  /// **'Where the money went: bills and purchases'**
  String get toolDashboardCaption;

  /// No description provided for @dashTitle.
  ///
  /// In en, this message translates to:
  /// **'Spending'**
  String get dashTitle;

  /// No description provided for @dashSpentIn.
  ///
  /// In en, this message translates to:
  /// **'Spent in {month}'**
  String dashSpentIn(String month);

  /// No description provided for @dashUp.
  ///
  /// In en, this message translates to:
  /// **'Up {pct}% on {month}'**
  String dashUp(String pct, String month);

  /// No description provided for @dashDown.
  ///
  /// In en, this message translates to:
  /// **'Down {pct}% on {month}'**
  String dashDown(String pct, String month);

  /// No description provided for @dashSame.
  ///
  /// In en, this message translates to:
  /// **'The same as {month}'**
  String dashSame(String month);

  /// No description provided for @dashNoPrev.
  ///
  /// In en, this message translates to:
  /// **'Nothing was spent in {month}'**
  String dashNoPrev(String month);

  /// No description provided for @dashBills.
  ///
  /// In en, this message translates to:
  /// **'Bills'**
  String get dashBills;

  /// No description provided for @dashPurchases.
  ///
  /// In en, this message translates to:
  /// **'Purchases'**
  String get dashPurchases;

  /// No description provided for @dashBillsPaid.
  ///
  /// In en, this message translates to:
  /// **'Bills paid'**
  String get dashBillsPaid;

  /// No description provided for @dashBought.
  ///
  /// In en, this message translates to:
  /// **'Bought'**
  String get dashBought;

  /// No description provided for @dashStillToPay.
  ///
  /// In en, this message translates to:
  /// **'Still to pay'**
  String get dashStillToPay;

  /// No description provided for @dashBillCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 bill} other{{count} bills}}'**
  String dashBillCount(int count);

  /// No description provided for @dashOverdue.
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get dashOverdue;

  /// No description provided for @dashNoneOverdue.
  ///
  /// In en, this message translates to:
  /// **'Nothing overdue'**
  String get dashNoneOverdue;

  /// No description provided for @dashPlanned.
  ///
  /// In en, this message translates to:
  /// **'Planned purchases'**
  String get dashPlanned;

  /// No description provided for @dashItemCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String dashItemCount(int count);

  /// No description provided for @dashTrendTitle.
  ///
  /// In en, this message translates to:
  /// **'Last 6 months'**
  String get dashTrendTitle;

  /// No description provided for @dashChartView.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get dashChartView;

  /// No description provided for @dashTableView.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get dashTableView;

  /// No description provided for @dashColMonth.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get dashColMonth;

  /// No description provided for @dashColTotal.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get dashColTotal;

  /// No description provided for @dashByType.
  ///
  /// In en, this message translates to:
  /// **'Bills paid, by type'**
  String get dashByType;

  /// No description provided for @dashByCategory.
  ///
  /// In en, this message translates to:
  /// **'Bought, by category'**
  String get dashByCategory;

  /// No description provided for @dashNoBillsPaid.
  ///
  /// In en, this message translates to:
  /// **'No bills paid this month'**
  String get dashNoBillsPaid;

  /// No description provided for @dashNoPurchases.
  ///
  /// In en, this message translates to:
  /// **'Nothing bought this month'**
  String get dashNoPurchases;

  /// No description provided for @dashCategoryOther.
  ///
  /// In en, this message translates to:
  /// **'No category'**
  String get dashCategoryOther;

  /// No description provided for @dashUpcomingTitle.
  ///
  /// In en, this message translates to:
  /// **'Next bills to pay'**
  String get dashUpcomingTitle;

  /// No description provided for @dashNoUpcoming.
  ///
  /// In en, this message translates to:
  /// **'No bills waiting'**
  String get dashNoUpcoming;

  /// No description provided for @dashDueToday.
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get dashDueToday;

  /// No description provided for @dashDueTomorrow.
  ///
  /// In en, this message translates to:
  /// **'Due tomorrow'**
  String get dashDueTomorrow;

  /// No description provided for @dashDueIn.
  ///
  /// In en, this message translates to:
  /// **'Due in {days} days'**
  String dashDueIn(int days);

  /// No description provided for @dashOverdueBy.
  ///
  /// In en, this message translates to:
  /// **'Overdue by {days} days'**
  String dashOverdueBy(int days);

  /// No description provided for @dashViewAll.
  ///
  /// In en, this message translates to:
  /// **'View all'**
  String get dashViewAll;

  /// No description provided for @dashExcluded.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 purchase in another currency is not included} other{{count} purchases in another currency are not included}}'**
  String dashExcluded(int count);

  /// No description provided for @dashLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the spending figures'**
  String get dashLoadFailed;

  /// No description provided for @dashEmptyTitle.
  ///
  /// In en, this message translates to:
  /// **'Nothing spent in {month} yet'**
  String dashEmptyTitle(String month);

  /// No description provided for @dashEmptyHint.
  ///
  /// In en, this message translates to:
  /// **'Pay a bill or mark a purchase as bought and it shows up here.'**
  String get dashEmptyHint;

  /// No description provided for @dashThisMonth.
  ///
  /// In en, this message translates to:
  /// **'This month'**
  String get dashThisMonth;

  /// No description provided for @dashPrevMonth.
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get dashPrevMonth;

  /// No description provided for @dashNextMonth.
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get dashNextMonth;

  /// No description provided for @dashChartLabel.
  ///
  /// In en, this message translates to:
  /// **'{month}: bills {bills}, purchases {purchases}'**
  String dashChartLabel(String month, String bills, String purchases);

  /// No description provided for @dashPaceTitle.
  ///
  /// In en, this message translates to:
  /// **'Spending pace'**
  String get dashPaceTitle;

  /// No description provided for @dashPaceSub.
  ///
  /// In en, this message translates to:
  /// **'Running total, day by day, against last month'**
  String get dashPaceSub;

  /// No description provided for @dashPaceNow.
  ///
  /// In en, this message translates to:
  /// **'By day {day}: {amount}'**
  String dashPaceNow(int day, String amount);

  /// No description provided for @dashPaceMore.
  ///
  /// In en, this message translates to:
  /// **'{amount} more than at this point last month'**
  String dashPaceMore(String amount);

  /// No description provided for @dashPaceLess.
  ///
  /// In en, this message translates to:
  /// **'{amount} less than at this point last month'**
  String dashPaceLess(String amount);

  /// No description provided for @dashPaceSame.
  ///
  /// In en, this message translates to:
  /// **'The same as at this point last month'**
  String get dashPaceSame;

  /// No description provided for @dashPaceLabel.
  ///
  /// In en, this message translates to:
  /// **'Running total: {now} this month, {prev} at the same point last month'**
  String dashPaceLabel(String now, String prev);

  /// No description provided for @dashDonutCenter.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get dashDonutCenter;

  /// No description provided for @dashTrendEmpty.
  ///
  /// In en, this message translates to:
  /// **'Nothing yet. Pay a bill or mark a purchase as bought and it appears here.'**
  String get dashTrendEmpty;

  /// No description provided for @dashPaceAt.
  ///
  /// In en, this message translates to:
  /// **'Day {day}: {now} · last month {prev}'**
  String dashPaceAt(int day, String now, String prev);

  /// No description provided for @dashPaceAtPrev.
  ///
  /// In en, this message translates to:
  /// **'Day {day}: last month {prev}'**
  String dashPaceAtPrev(int day, String prev);

  /// No description provided for @applStatusOn.
  ///
  /// In en, this message translates to:
  /// **'On'**
  String get applStatusOn;

  /// No description provided for @applStatusOff.
  ///
  /// In en, this message translates to:
  /// **'Off'**
  String get applStatusOff;

  /// No description provided for @applStatusTurningOn.
  ///
  /// In en, this message translates to:
  /// **'Turning on…'**
  String get applStatusTurningOn;

  /// No description provided for @applStatusTurningOff.
  ///
  /// In en, this message translates to:
  /// **'Turning off…'**
  String get applStatusTurningOff;

  /// No description provided for @applStatusUnconfirmed.
  ///
  /// In en, this message translates to:
  /// **'Not confirmed'**
  String get applStatusUnconfirmed;

  /// No description provided for @applStatusOnSince.
  ///
  /// In en, this message translates to:
  /// **'On since {time} · {duration}'**
  String applStatusOnSince(String time, String duration);

  /// No description provided for @applStatusOffSince.
  ///
  /// In en, this message translates to:
  /// **'Off since {time} · {duration}'**
  String applStatusOffSince(String time, String duration);

  /// No description provided for @applStatusOfflineBody.
  ///
  /// In en, this message translates to:
  /// **'Can\'t be reached right now. Last known: {state}.'**
  String applStatusOfflineBody(String state);

  /// No description provided for @applStatusAutoOff.
  ///
  /// In en, this message translates to:
  /// **'Switches itself off at {time} (in {left})'**
  String applStatusAutoOff(String time, String left);

  /// No description provided for @applStatusUnconfirmedBody.
  ///
  /// In en, this message translates to:
  /// **'The command was sent, but the appliance didn\'t confirm it. Check again to be sure.'**
  String get applStatusUnconfirmedBody;

  /// No description provided for @applCheckedJustNow.
  ///
  /// In en, this message translates to:
  /// **'Checked just now'**
  String get applCheckedJustNow;

  /// No description provided for @applCheckedAgo.
  ///
  /// In en, this message translates to:
  /// **'Checked {ago} ago'**
  String applCheckedAgo(String ago);

  /// No description provided for @applCheckFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t check just now. Showing what was known at {time}.'**
  String applCheckFailed(String time);

  /// No description provided for @applCheckNow.
  ///
  /// In en, this message translates to:
  /// **'Check now'**
  String get applCheckNow;

  /// No description provided for @applStatusFilterNone.
  ///
  /// In en, this message translates to:
  /// **'Nothing is {status} right now'**
  String applStatusFilterNone(String status);

  /// No description provided for @applStatusSummaryLabel.
  ///
  /// In en, this message translates to:
  /// **'{onCount} on, {offCount} off, {offlineCount} offline'**
  String applStatusSummaryLabel(int onCount, int offCount, int offlineCount);

  /// No description provided for @applHomeOn.
  ///
  /// In en, this message translates to:
  /// **'{count} of {total} on'**
  String applHomeOn(int count, int total);

  /// No description provided for @applHomeOffline.
  ///
  /// In en, this message translates to:
  /// **'{count} offline'**
  String applHomeOffline(int count);

  /// No description provided for @applDurUnderMinute.
  ///
  /// In en, this message translates to:
  /// **'under a minute'**
  String get applDurUnderMinute;

  /// No description provided for @applDurSeconds.
  ///
  /// In en, this message translates to:
  /// **'{n} s'**
  String applDurSeconds(int n);

  /// No description provided for @applDurMinutes.
  ///
  /// In en, this message translates to:
  /// **'{n} min'**
  String applDurMinutes(int n);

  /// No description provided for @applDurHours.
  ///
  /// In en, this message translates to:
  /// **'{h} h {m} min'**
  String applDurHours(int h, int m);

  /// No description provided for @applDurHoursOnly.
  ///
  /// In en, this message translates to:
  /// **'{h} h'**
  String applDurHoursOnly(int h);

  /// No description provided for @applDurDays.
  ///
  /// In en, this message translates to:
  /// **'{d} d {h} h'**
  String applDurDays(int d, int h);

  /// No description provided for @applKindCooler.
  ///
  /// In en, this message translates to:
  /// **'Air cooler'**
  String get applKindCooler;

  /// No description provided for @applKindCoolerHint.
  ///
  /// In en, this message translates to:
  /// **'Speed, left-right swing, water cooling and modes'**
  String get applKindCoolerHint;

  /// No description provided for @applCapCooling.
  ///
  /// In en, this message translates to:
  /// **'Cooling'**
  String get applCapCooling;

  /// No description provided for @applModeNormal.
  ///
  /// In en, this message translates to:
  /// **'Normal'**
  String get applModeNormal;

  /// No description provided for @applModeNatural.
  ///
  /// In en, this message translates to:
  /// **'Natural wind'**
  String get applModeNatural;

  /// No description provided for @applModeSleep.
  ///
  /// In en, this message translates to:
  /// **'Sleep'**
  String get applModeSleep;

  /// No description provided for @applLightOn.
  ///
  /// In en, this message translates to:
  /// **'Light on, {brightness}'**
  String applLightOn(String brightness);

  /// No description provided for @applLightOff.
  ///
  /// In en, this message translates to:
  /// **'Light off'**
  String get applLightOff;

  /// No description provided for @applCoolerOn.
  ///
  /// In en, this message translates to:
  /// **'Air cooler on, speed {speed}'**
  String applCoolerOn(int speed);

  /// No description provided for @applCoolerOnCooling.
  ///
  /// In en, this message translates to:
  /// **'Air cooler on, speed {speed}, cooling'**
  String applCoolerOnCooling(int speed);

  /// No description provided for @applCoolerOff.
  ///
  /// In en, this message translates to:
  /// **'Air cooler off'**
  String get applCoolerOff;

  /// No description provided for @applStatusAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get applStatusAll;

  /// No description provided for @applSinceShort.
  ///
  /// In en, this message translates to:
  /// **'since {time}'**
  String applSinceShort(String time);

  /// No description provided for @applAutoOffShort.
  ///
  /// In en, this message translates to:
  /// **'switches off in {left}'**
  String applAutoOffShort(String left);

  /// No description provided for @applLastKnown.
  ///
  /// In en, this message translates to:
  /// **'last known: {state}'**
  String applLastKnown(String state);

  /// No description provided for @applOfflineAlert.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 appliance can\'t be reached} other{{count} appliances can\'t be reached}}'**
  String applOfflineAlert(int count);

  /// No description provided for @applStatusTitle.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get applStatusTitle;

  /// No description provided for @applHeaterOn.
  ///
  /// In en, this message translates to:
  /// **'Heater on'**
  String get applHeaterOn;

  /// No description provided for @applHeaterOnAutoOff.
  ///
  /// In en, this message translates to:
  /// **'Heater on, switches itself off in {left}'**
  String applHeaterOnAutoOff(String left);

  /// No description provided for @applHeaterOff.
  ///
  /// In en, this message translates to:
  /// **'Heater off'**
  String get applHeaterOff;

  /// No description provided for @applHeaterOffIn.
  ///
  /// In en, this message translates to:
  /// **'Off in'**
  String get applHeaterOffIn;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'th'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'th':
      return AppLocalizationsTh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
