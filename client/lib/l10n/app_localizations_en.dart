// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonTryAgain => 'Try again';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonSave => 'Save';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonApply => 'Apply';

  @override
  String get commonClose => 'Close';

  @override
  String get commonBack => 'Back';

  @override
  String get commonSearch => 'Search…';

  @override
  String get commonAll => 'All';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonLoadFailed => 'Couldn\'t load this';

  @override
  String get languageTitle => 'Language';

  @override
  String get languageSystem => 'Device language';

  @override
  String get languageThai => 'ไทย';

  @override
  String get languageEnglish => 'English';

  @override
  String get refreshTooltip => 'Refresh';

  @override
  String get refreshDone => 'Updated';

  @override
  String get refreshFailed => 'Couldn\'t refresh. Please try again.';

  @override
  String get homeNotifications => 'Notifications';

  @override
  String get homeNotificationsSoon => 'Notifications are coming soon';

  @override
  String get homeToolsTitle => 'Tools';

  @override
  String get homeToolsSubtitle => 'Manage your home quickly';

  @override
  String get homeWeatherFailed => 'Couldn\'t load the weather';

  @override
  String get homeWind => 'Wind';

  @override
  String get homeUpdated => 'Updated';

  @override
  String get homeSearchHint => 'Search electrician, plumber…';

  @override
  String get weatherClear => 'Clear sky';

  @override
  String get weatherPartlyCloudy => 'Partly cloudy';

  @override
  String get weatherFog => 'Fog';

  @override
  String get weatherDrizzle => 'Drizzle';

  @override
  String get weatherRain => 'Rain';

  @override
  String get weatherSnow => 'Snow';

  @override
  String get weatherThunderstorm => 'Thunderstorm';

  @override
  String get weatherUnknown => 'Unknown';

  @override
  String get toolContractorsCaption => 'Find tradespeople near you';

  @override
  String get toolNotesCaption => 'Notes you must not forget';

  @override
  String get toolCamerasCaption => 'Watch the home cameras';

  @override
  String get toolPurchasesCaption => 'Track what\'s bought for the home';

  @override
  String get toolBillsCaption => 'Recurring household bills';

  @override
  String get toolMedicineCaption => 'Check the household medicine stock';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonInvalidNumber => 'Invalid number';

  @override
  String get medAlertTitle => 'Set alerts';

  @override
  String get medAlertEnable => 'Turn on alerts';

  @override
  String get medAlertMinQty => 'Alert when stock is at or below (units)';

  @override
  String get medAlertExpiryDays =>
      'Alert when days to expiry are at or below (days)';

  @override
  String get medAlertUpdated => 'Alert updated';

  @override
  String get medAlertNone => 'No alert';

  @override
  String medAlertOn(String min, String days) {
    return 'ON · min $min · exp ${days}d';
  }

  @override
  String get medAlertOff => 'OFF';

  @override
  String get medTxnInTitle => 'Stock in';

  @override
  String get medTxnOutTitle => 'Take out';

  @override
  String get medTxnLot => 'Lot number (optional)';

  @override
  String get medTxnExpiry => 'Expiry date (YYYY-MM-DD)';

  @override
  String get medTxnQty => 'Quantity (units)';

  @override
  String get medTxnQtyInvalid => 'Enter a valid quantity';

  @override
  String get medTxnNote => 'Note (optional)';

  @override
  String get medTxnInDone => 'Stock received';

  @override
  String get medTxnOutDone => 'Medicine taken out';

  @override
  String medBatchLot(String lot) {
    return 'Lot $lot';
  }

  @override
  String get medBatchNoLot => 'No lot number';

  @override
  String medBatchExpires(String date) {
    return 'Expires: $date';
  }

  @override
  String medInStock(String qty) {
    return '$qty left';
  }

  @override
  String get billsNew => 'New bill';

  @override
  String get billsSummaryTooltip => 'Summary';

  @override
  String get billsSearchHint => 'Search bills (title, note, type)…';

  @override
  String get billsEmptyTitle => 'No bills yet';

  @override
  String get billsEmptyHint => 'Add your first bill to start tracking.';

  @override
  String get billsClearFilters => 'Clear filters';

  @override
  String get billStatusPaid => 'Paid';

  @override
  String get billStatusUnpaid => 'Unpaid';

  @override
  String billsPaidOn(String date) {
    return 'Paid on $date';
  }

  @override
  String get billsDueToday => 'Due today';

  @override
  String get billsDueTomorrow => 'Due tomorrow';

  @override
  String billsDueInDays(int days) {
    return 'Due in $days days';
  }

  @override
  String billsLateDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days late',
      one: '1 day late',
    );
    return '$_temp0';
  }

  @override
  String billsDueOn(String date) {
    return 'Due $date';
  }

  @override
  String get billTypeElectric => 'Electricity';

  @override
  String get billTypeWater => 'Water';

  @override
  String get billTypeInternet => 'Internet';

  @override
  String get billTypePhone => 'Phone';

  @override
  String get billTypeOther => 'Other';

  @override
  String get billDetailTitle => 'Bill details';

  @override
  String get billDetailAmount => 'Amount';

  @override
  String get billDetailStatus => 'Status';

  @override
  String get billDetailDueDate => 'Due date';

  @override
  String get billDetailCreatedAt => 'Created';

  @override
  String get billDetailUpdatedAt => 'Last updated';

  @override
  String get billDetailCreatedBy => 'Created by';

  @override
  String get billDetailNote => 'Note';

  @override
  String get billMarkPaid => 'Mark as paid';

  @override
  String get billProcessing => 'Processing…';

  @override
  String get billMarkedPaid => 'Marked as paid';

  @override
  String get billFormPickDue => 'Pick a due date';

  @override
  String get billFormType => 'Type';

  @override
  String get billFormTitle => 'Title';

  @override
  String get billFormTitleRequired => 'Enter a title';

  @override
  String get billFormAmount => 'Amount (THB)';

  @override
  String get billFormAmountInvalid => 'Invalid amount';

  @override
  String get billFormAmountPositive => 'The amount must be greater than 0';

  @override
  String get billFormNote => 'Note (optional)';

  @override
  String get billFormPickDueFirst => 'Please pick a due date';

  @override
  String get billFormDuePast => 'The due date can\'t be in the past';

  @override
  String get billFormCreated => 'Bill created';

  @override
  String get billsSummaryTitle => 'Bills summary';

  @override
  String get billsSummaryFailed => 'Couldn\'t load the summary';

  @override
  String get billsSummaryEmpty => 'No bill summary yet';

  @override
  String get medNew => 'Add medicine';

  @override
  String get medSearchHint => 'Search medicine name…';

  @override
  String get medEmptyTitle => 'No medicine yet';

  @override
  String get medEmptyHint => 'Tap “Add medicine” to create the first item.';

  @override
  String get medLoadFailed => 'Couldn\'t load the medicine list';

  @override
  String get medStatusExpired => 'Expired';

  @override
  String get medStatusExpiringSoon => 'Expiring soon';

  @override
  String get medStatusLow => 'Running low';

  @override
  String medUnit(String unit) {
    return 'Unit: $unit';
  }

  @override
  String medNextExpiry(String date) {
    return 'Next expiry $date';
  }

  @override
  String get medDetailTitle => 'Medicine details';

  @override
  String medDetailExpiringSoon(String date) {
    return 'Expiring soon: $date';
  }

  @override
  String get medDetailLots => 'Lots';

  @override
  String get medDetailNoLots => 'No lots yet';

  @override
  String get medDetailNoLotsHint => 'Tap “Stock in” to add the first lot.';

  @override
  String get medDetailAlerts => 'Alerts';

  @override
  String get medFormAdded => 'Medicine added';

  @override
  String get medFormName => 'Medicine name';

  @override
  String get medFormNameHint => 'e.g. Paracetamol 500mg';

  @override
  String get medFormNameRequired => 'Please enter the medicine name';

  @override
  String get medFormForm => 'Form (e.g. tablet, syrup)';

  @override
  String get medFormUnit => 'Unit (e.g. tab, ml)';

  @override
  String get medFormCategory => 'Category (e.g. painkiller)';

  @override
  String get medFormNoLocation => '— No location —';

  @override
  String get medFormLocation => 'Storage location';

  @override
  String get medFormLocationsFailed => 'Couldn\'t load storage locations';

  @override
  String get commonStatus => 'Status';

  @override
  String get commonNote => 'Note';

  @override
  String get commonFilters => 'Filters';

  @override
  String get commonClearFilters => 'Clear filters';

  @override
  String get commonClearAll => 'Clear all';

  @override
  String get authSignIn => 'Sign in';

  @override
  String get purchNew => 'New purchase';

  @override
  String get purchAddItem => 'Add item';

  @override
  String get purchSearchHint =>
      'Search (title, store, category, note, status)…';

  @override
  String get purchStatusPlanned => 'Planned';

  @override
  String get purchStatusOrdered => 'Ordered';

  @override
  String get purchStatusBought => 'Bought';

  @override
  String get purchStatusDelivered => 'Delivered';

  @override
  String get purchStatusCanceled => 'Canceled';

  @override
  String get purchNoResults => 'No purchases match';

  @override
  String get purchEmpty => 'No purchases yet';

  @override
  String get purchSignInPrompt => 'Please sign in to use this';

  @override
  String get purchLoadFailed => 'Couldn\'t load the data';

  @override
  String get purchDetailTitle => 'Purchase details';

  @override
  String purchDetailLoadFailed(String error) {
    return 'Couldn\'t load: $error';
  }

  @override
  String get purchAdvanceSoon => 'Changing the status isn\'t connected yet';

  @override
  String get purchUploading => 'Uploading file…';

  @override
  String get purchUploadDone => 'File uploaded';

  @override
  String purchUploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get purchItemsTitle => 'Items';

  @override
  String purchItemsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get purchNoItems => '— No items —';

  @override
  String get purchTotalByItems => 'Total of items';

  @override
  String get purchEstimated => 'Estimated';

  @override
  String get purchPaid => 'Actually paid';

  @override
  String get purchAttachments => 'Attachments';

  @override
  String purchEstimatedAmount(String amount) {
    return 'Estimated $amount';
  }

  @override
  String purchPaidAmount(String amount) {
    return 'Paid $amount';
  }

  @override
  String purchItemQty(String qty) {
    return 'Qty: $qty';
  }

  @override
  String purchItemPrice(String price) {
    return '• $price each';
  }

  @override
  String get purchNextStatus => 'Next status';

  @override
  String get purchAttach => 'Attach file / photo';

  @override
  String get purchNoAttachments => '— No attachments —';

  @override
  String get purchOpen => 'Open';

  @override
  String get purchCantOpenLink => 'Couldn\'t open the link';

  @override
  String get purchDeleteAttachment => 'Delete attachment';

  @override
  String get purchDeleteAttachmentAsk => 'Delete this attachment?';

  @override
  String purchDeleteAttachmentBody(String name) {
    return 'Delete the file “$name”?';
  }

  @override
  String get purchDeleting => 'Deleting attachment…';

  @override
  String get purchDeleted => 'Attachment deleted';

  @override
  String purchDeleteFailed(String error) {
    return 'Couldn\'t delete: $error';
  }

  @override
  String get purchFormCreate => 'Create purchase';

  @override
  String get purchFormEdit => 'Edit purchase';

  @override
  String get purchFormTitleRequired => 'Enter a title';

  @override
  String get purchFormTitleMin => 'At least 3 characters';

  @override
  String get purchFormPositive => 'Must be greater than 0';

  @override
  String get purchFormCreated => 'Purchase created';

  @override
  String get purchFormError => 'Something went wrong';

  @override
  String get purchFormSignIn => 'Please sign in';

  @override
  String get purchFormDetails => 'Purchase details';

  @override
  String get purchFormTitleLabel => 'Title *';

  @override
  String get purchFormTitleHint => 'e.g. “Cleaning supplies”';

  @override
  String get purchFormNoteHint => 'More details (optional)';

  @override
  String get purchFormBudget => 'Rough budget';

  @override
  String get purchFormEstimated => 'Estimated amount';

  @override
  String get purchFormEstimatedHint => 'e.g. 1,500 or 1500';

  @override
  String get purchFormCurrency => 'Currency';

  @override
  String get purchFormOptional => 'Optional — leave empty if you\'re not sure';

  @override
  String get purchFormSaving => 'Saving…';

  @override
  String get commonError => 'Something went wrong';

  @override
  String get notesNew => 'New note';

  @override
  String get notesEditTitle => 'Edit note';

  @override
  String get notesStatusActive => 'Active';

  @override
  String get notesStatusDone => 'Done';

  @override
  String get notesStatusOverdue => 'Overdue';

  @override
  String get notesPinned => 'Pinned';

  @override
  String get notesUnpinned => 'Unpinned';

  @override
  String get notesCategory => 'Category';

  @override
  String get notesCatBills => 'Bills';

  @override
  String get notesCatChores => 'Chores';

  @override
  String get notesCatAppointment => 'Appointment';

  @override
  String get notesCatGeneral => 'General';

  @override
  String get notesTag => 'Tag';

  @override
  String get notesNoMatch => 'No notes match';

  @override
  String get notesMarkedDone => 'Marked as done';

  @override
  String get notesMarkedUndone => 'Marked as not done';

  @override
  String get notesErrDone => 'Couldn\'t update the note';

  @override
  String get notesErrPin => 'Couldn\'t change the pin';

  @override
  String get notesErrDelete => 'Couldn\'t delete the note';

  @override
  String get notesErrSave => 'Couldn\'t save the note';

  @override
  String notesErr401(String what) {
    return '$what: 401 (please sign in again)';
  }

  @override
  String notesErr404(String what) {
    return '$what: 404 (not found)';
  }

  @override
  String get notesDeleteTitle => 'Delete note';

  @override
  String notesDeleteBody(String title) {
    return 'Delete “$title”?';
  }

  @override
  String get notesDeleted => 'Deleted';

  @override
  String get notesAdded => 'Note added';

  @override
  String get notesEdited => 'Note updated';

  @override
  String get notesSearchHint => 'Search notes (title, content, tag)';

  @override
  String get notesCopy => 'Copy';

  @override
  String get notesCopied => 'Copied';

  @override
  String get notesMarkDone => 'Mark as done';

  @override
  String get notesMarkUndone => 'Mark as not done';

  @override
  String get notesPin => 'Pin';

  @override
  String get notesUnpin => 'Unpin';

  @override
  String get notesFieldTitle => 'Title';

  @override
  String get notesFieldContent =>
      'Content (you can paste image links from Uploads)';

  @override
  String get notesTitleRequired => 'Please enter a title';

  @override
  String get notesCreate => 'Create';

  @override
  String get notesErrUnauthorized =>
      'Not authorized (401) — please sign in again';

  @override
  String get notesErrNotFound => 'Notes not found (404)';

  @override
  String notesErrLoad(String detail) {
    return 'Couldn\'t load notes: $detail';
  }

  @override
  String distMeters(String m) {
    return '$m m';
  }

  @override
  String distKm(String km) {
    return '$km km';
  }

  @override
  String get contStarred => 'Added to favorites';

  @override
  String get contUnstarred => 'Removed from favorites';

  @override
  String get contStarFailed => 'Couldn\'t save the star. Please try again.';

  @override
  String get contBackToMe => 'Back to me';

  @override
  String get contFavorites => 'Favorites';

  @override
  String get contStopFollow => 'Stop following';

  @override
  String get contMyLocation => 'My location';

  @override
  String get contFitAll => 'Show all';

  @override
  String get contMeasureOff => 'Stop measuring';

  @override
  String get contMeasure => 'Measure distance';

  @override
  String get contPinPlaced =>
      'Location pinned. Tap “My location” to go back to GPS.';

  @override
  String get contPinnedSpot => 'Pinned spot';

  @override
  String get contYouAreHere => 'You are here';

  @override
  String get contGoogleLimited =>
      'Today\'s Google quota is used up. Showing saved contractors only.';

  @override
  String get contGoogleBusy =>
      'Searching too often. Wait a moment and try again.';

  @override
  String get contGoogleDown =>
      'Couldn\'t reach Google right now. Showing saved contractors only.';

  @override
  String get contGoogleIncluded => 'Includes places from Google';

  @override
  String get contGoogleIncludedListOnly =>
      'Includes places from Google (list only)';

  @override
  String contGoogleLeft(int left) {
    String _temp0 = intl.Intl.pluralLogic(
      left,
      locale: localeName,
      other: '$left Google lookups left today',
      one: '1 Google lookup left today',
    );
    return '$_temp0';
  }

  @override
  String get contGoogleHowTo => 'Tap a trade or type to find places on Google';

  @override
  String get contNeedLocation =>
      'Your location is needed to find contractors near you';

  @override
  String get contLocateAgain => 'Locate me again';

  @override
  String get contLoadFailed => 'Couldn\'t load contractors';

  @override
  String get contNoFavorites => 'No favorites yet';

  @override
  String get contNoFavoritesHint =>
      'Tap the star on a contractor you trust to keep them here';

  @override
  String get contNoneInRadius => 'No contractors within the chosen radius';

  @override
  String contWidenRadius(int km) {
    return 'Widen the radius to $km km';
  }

  @override
  String contSeeMore(int hidden) {
    return 'See more ($hidden left)';
  }

  @override
  String get contNearYou => 'Contractors near you';

  @override
  String contFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count found',
      one: '1 found',
    );
    return '$_temp0';
  }

  @override
  String get contSearchHere => 'Search this area';

  @override
  String get contSearchHint => 'Search for a trade or shop, e.g. electrician';

  @override
  String get contOpenNow => 'Open';

  @override
  String get contClosedNow => 'Closed';

  @override
  String get contStarRemove => 'Remove from favorites';

  @override
  String get contStarAdd => 'Add to favorites';

  @override
  String get contCall => 'Call';

  @override
  String get contDirections => 'Directions';

  @override
  String get contWebsite => 'Website';

  @override
  String get contOpenInGoogle => 'Open in Google Maps';

  @override
  String get contMeasureHint0 =>
      'Tap the map or a contractor pin to start measuring';

  @override
  String get contMeasureHint1 => 'Tap the next point to measure';

  @override
  String get contMeasureHintMore =>
      'Tap to extend the route (straight lines between points)';

  @override
  String contPoints(int points) {
    return '($points points)';
  }

  @override
  String get contStartFromMe => 'Start from my location';

  @override
  String get contUndo => 'Undo';

  @override
  String get contDone => 'Done';

  @override
  String get contRadiusTitle => 'Search radius';

  @override
  String contRadiusFromYou(int km) {
    return '$km km from your location';
  }

  @override
  String get contTypeElectrician => 'Electrician';

  @override
  String get contTypePlumber => 'Plumber';

  @override
  String get contTypeCarpenter => 'Carpenter';

  @override
  String get contTypeHvac => 'AC technician';

  @override
  String get contTypeOther => 'General contractor';

  @override
  String get locServiceOff => 'Location Services are turned off on this device';

  @override
  String get locOpenSettings => 'Open settings';

  @override
  String get locDenied => 'The app isn\'t allowed to use your location yet';

  @override
  String get locAllow => 'Allow';

  @override
  String get locBlocked =>
      'Location access is blocked. You can enable it in the app\'s settings';

  @override
  String get locUnavailable =>
      'Couldn\'t find your current location (on a Simulator, set a location first)';

  @override
  String get locErrServiceOff => 'Location services are turned off.';

  @override
  String get locErrDenied => 'Location permission was denied.';

  @override
  String get locErrBlocked =>
      'Location permission is blocked. Enable it in Settings.';

  @override
  String get locErrUnknown => 'Could not determine your location.';

  @override
  String get authInvalidCredentials => 'Invalid email or password';

  @override
  String get authLoginSubtitle =>
      'Sign in to manage your home tasks and services.';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailRequired => 'Please enter your email';

  @override
  String get authEmailInvalid => 'Invalid email format';

  @override
  String get authPassword => 'Password';

  @override
  String get authShowPassword => 'Show password';

  @override
  String get authHidePassword => 'Hide password';

  @override
  String get authPasswordRequired => 'Please enter your password';

  @override
  String get authForgot => 'Forgot password?';

  @override
  String get authCreateAccountLink => 'Create an account';

  @override
  String get authPrivacyNote => 'We keep your information secure and private.';

  @override
  String get authRegisterTitle => 'Create your account';

  @override
  String get authRegisterSubtitle =>
      'Join Home Service 6/188 to manage tasks and services.';

  @override
  String get authFullName => 'Full name';

  @override
  String get authNameRequired => 'Please enter your name';

  @override
  String get authNameShort => 'Name is too short';

  @override
  String get authPasswordNew => 'Please enter a password';

  @override
  String get authPasswordMin => 'Password must be at least 6 characters';

  @override
  String get authConfirmPassword => 'Confirm password';

  @override
  String get authConfirmRequired => 'Please confirm your password';

  @override
  String get authPasswordMismatch => 'Passwords do not match';

  @override
  String get authTerms =>
      'By creating an account, you agree to our Terms and Privacy Policy.';

  @override
  String get authCreating => 'Creating…';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authSignInInstead => 'Sign in instead';

  @override
  String get authRegisterFailed =>
      'Unable to create the account. Please try again.';

  @override
  String get authResetSendFailed =>
      'Couldn\'t send the reset email. Please try again.';

  @override
  String get authGenericFailed => 'Something went wrong. Please try again.';

  @override
  String get authForgotTitle => 'Forgot password';

  @override
  String get authResetTitle => 'Reset your password';

  @override
  String get authResetHint =>
      'Enter your email address and we’ll send you a reset link.';

  @override
  String get authSending => 'Sending…';

  @override
  String get authSendLink => 'Send reset link';

  @override
  String get authBackToSignIn => 'Back to sign in';

  @override
  String get authCheckInbox => 'Check your inbox';

  @override
  String get authSentBody =>
      'We’ve sent a password reset link to your email.\nIf you don’t see it, check your spam folder.';

  @override
  String get authResend => 'Resend link';

  @override
  String get authUnexpected => 'Unexpected error';

  @override
  String get authUnknownError => 'Unknown error';

  @override
  String authNetworkError(String status) {
    return 'Network error ($status)';
  }

  @override
  String routeError(String error) {
    return 'Page error: $error';
  }

  @override
  String get camEmptyTitle => 'No cameras found';

  @override
  String get camEmptyHint =>
      'Add a camera in the Imou app and it will show up here.';

  @override
  String get camDisabledTitle => 'Cameras aren\'t set up yet';

  @override
  String get camDisabledHint =>
      'The server needs the camera account details before the cameras can show here.';

  @override
  String get camOffline => 'Offline';

  @override
  String get camLive => 'LIVE';

  @override
  String get camOfflineToast => 'This camera is offline right now';

  @override
  String get camLoadFailed => 'Couldn\'t load the cameras';

  @override
  String get camErrMisconfigured =>
      'The camera account details on the server were rejected';

  @override
  String get camErrLimit =>
      'The camera service has reached its call limit. Try again later.';

  @override
  String get camErrUnavailable => 'Couldn\'t reach the camera service';

  @override
  String get camErrOffline => 'The camera is offline';

  @override
  String get camPlayerFailed => 'Couldn\'t play the stream';

  @override
  String get camMute => 'Mute';

  @override
  String get camUnmute => 'Unmute';

  @override
  String get camQuality => 'Quality';

  @override
  String get camPausedIdle => 'Paused to save data';

  @override
  String get camResume => 'Resume';

  @override
  String get camHumanDetect => 'Detects people';

  @override
  String get camConnecting => 'Connecting…';

  @override
  String get camCameras => 'Cameras';

  @override
  String get camSwipeHint => 'Swipe left or right to switch cameras';

  @override
  String camPosition(int index, int total) {
    return '$index of $total';
  }

  @override
  String get camFullscreen => 'Full screen';

  @override
  String get camExitFullscreen => 'Exit full screen';

  @override
  String get camPtzTitle => 'Move the camera';

  @override
  String get camPtzHint => 'Hold a button to keep moving';

  @override
  String get camPtzUp => 'Tilt up';

  @override
  String get camPtzDown => 'Tilt down';

  @override
  String get camPtzLeft => 'Pan left';

  @override
  String get camPtzRight => 'Pan right';

  @override
  String get camPtzStop => 'Stop';

  @override
  String get camZoomIn => 'Zoom in';

  @override
  String get camZoomOut => 'Zoom out';

  @override
  String get camPtzFailed => 'Couldn\'t move the camera';

  @override
  String get camSettingsTitle => 'Camera settings';

  @override
  String get camSwitchPrivacy => 'Privacy mode';

  @override
  String get camSwitchPrivacyHint => 'Turns the camera view off';

  @override
  String get camSwitchMotion => 'Motion detection';

  @override
  String get camSwitchHuman => 'Person detection';

  @override
  String get camSwitchFailed => 'Couldn\'t change the setting';

  @override
  String get camSwitchesLoadFailed => 'Couldn\'t load the settings';

  @override
  String get camNotSupported => 'This camera doesn\'t support that';

  @override
  String get camSwitchLight => 'Camera light';

  @override
  String get camSwitchLightHint =>
      'Turns the camera\'s built-in light on or off';

  @override
  String get camSwitchLightAuto => 'Light on motion';

  @override
  String get authSignedIn => 'Signed in';

  @override
  String get authSignedOut => 'Signed out';

  @override
  String get homeGreetingMorning => 'Good morning';

  @override
  String get homeGreetingAfternoon => 'Good afternoon';

  @override
  String get homeGreetingEvening => 'Good evening';

  @override
  String get homeGreetingLate => 'Hello';

  @override
  String get homeLastUsed => 'Last used';

  @override
  String get accountTitle => 'Account';

  @override
  String get accountOpen => 'Open your account';

  @override
  String get accountProfileSection => 'Profile';

  @override
  String get accountName => 'Name';

  @override
  String get accountEmail => 'Email';

  @override
  String get roleAdmin => 'Admin';

  @override
  String get roleMember => 'Member';

  @override
  String get accountEditName => 'Edit name';

  @override
  String get accountNameRequired => 'Enter a name';

  @override
  String get accountNameSaved => 'Name updated';

  @override
  String get accountSaveFailed => 'Couldn\'t save. Try again.';

  @override
  String get accountSecuritySection => 'Security';

  @override
  String get accountChangePassword => 'Change password';

  @override
  String get accountCurrentPassword => 'Current password';

  @override
  String get accountNewPassword => 'New password';

  @override
  String get accountConfirmPassword => 'Confirm new password';

  @override
  String get accountPasswordTooShort => 'At least 6 characters';

  @override
  String get accountPasswordMismatch => 'Passwords don\'t match';

  @override
  String get accountPasswordWrong => 'Current password is incorrect';

  @override
  String get accountPasswordChanged => 'Password changed';

  @override
  String get accountPreferencesSection => 'Preferences';

  @override
  String get accountSignOut => 'Sign out';

  @override
  String get accountCurrentRequired => 'Enter your current password';

  @override
  String camOnlineCount(int online, int total) {
    return '$online of $total online';
  }

  @override
  String get errNetwork =>
      'Can\'t reach the server. Check your connection and try again.';

  @override
  String get errSession => 'Your session has expired. Please sign in again.';

  @override
  String get errForbidden => 'You don\'t have permission to do this.';

  @override
  String get errNotFound => 'We couldn\'t find that.';

  @override
  String get errServer =>
      'The server ran into a problem. Please try again in a moment.';

  @override
  String get billsNoMatchTitle => 'No bills match';

  @override
  String get billsNoMatchHint => 'Try another word, or clear the filters.';

  @override
  String get medNoMatchTitle => 'No medicine matches';

  @override
  String get medNoMatchHint => 'Try another name, or clear the search.';

  @override
  String get notesEmptyTitle => 'No notes yet';

  @override
  String get notesEmptyHint => 'Tap + to write the first one.';

  @override
  String get notesNoMatchHint => 'Try another word, or clear the filters.';

  @override
  String get commonMore => 'More';

  @override
  String get purchTake => 'I\'ll buy this';

  @override
  String get purchMarkBought => 'Mark as bought';

  @override
  String get purchMarkDelivered => 'Mark as delivered';

  @override
  String get purchPaidTitle => 'How much did you pay?';

  @override
  String get purchPaidLabel => 'Amount paid';

  @override
  String get purchPaidInvalid => 'Enter an amount';

  @override
  String get purchCancelPurchase => 'Cancel this purchase';

  @override
  String get purchCancelAsk => 'Cancel this purchase?';

  @override
  String get purchCancelKeep => 'Keep it';

  @override
  String get purchStatusUpdated => 'Status updated';

  @override
  String get purchCancelled => 'Purchase cancelled';
}
