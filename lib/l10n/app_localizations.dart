import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_am.dart';
import 'app_localizations_en.dart';
import 'app_localizations_om.dart';

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

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
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
    Locale('am'),
    Locale('om')
  ];

  /// Application name
  ///
  /// In en, this message translates to:
  /// **'Idir App'**
  String get appName;

  /// Generic idir label
  ///
  /// In en, this message translates to:
  /// **'Idir'**
  String get idirName;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginTitle;

  /// No description provided for @loginEmailHint.
  ///
  /// In en, this message translates to:
  /// **'Email or phone'**
  String get loginEmailHint;

  /// No description provided for @loginPasswordHint.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get loginPasswordHint;

  /// No description provided for @loginButton.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get loginButton;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPassword;

  /// No description provided for @loginError.
  ///
  /// In en, this message translates to:
  /// **'Invalid email or password.'**
  String get loginError;

  /// No description provided for @loginDemoHint.
  ///
  /// In en, this message translates to:
  /// **'Demo accounts available below for quick role testing'**
  String get loginDemoHint;

  /// No description provided for @navHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// No description provided for @navMembers.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get navMembers;

  /// No description provided for @navContributions.
  ///
  /// In en, this message translates to:
  /// **'Contributions'**
  String get navContributions;

  /// No description provided for @navClaims.
  ///
  /// In en, this message translates to:
  /// **'Claims'**
  String get navClaims;

  /// No description provided for @navMore.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get navMore;

  /// No description provided for @dashboardTitle.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboardTitle;

  /// No description provided for @totalFund.
  ///
  /// In en, this message translates to:
  /// **'Total Fund'**
  String get totalFund;

  /// No description provided for @thisMonthCollected.
  ///
  /// In en, this message translates to:
  /// **'Collected this month'**
  String get thisMonthCollected;

  /// No description provided for @thisMonthExpected.
  ///
  /// In en, this message translates to:
  /// **'Expected this month'**
  String get thisMonthExpected;

  /// No description provided for @memberCount.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get memberCount;

  /// No description provided for @pendingClaims.
  ///
  /// In en, this message translates to:
  /// **'Pending claims'**
  String get pendingClaims;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent activity'**
  String get recentActivity;

  /// No description provided for @membersTitle.
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get membersTitle;

  /// No description provided for @addMember.
  ///
  /// In en, this message translates to:
  /// **'Add member'**
  String get addMember;

  /// No description provided for @editMember.
  ///
  /// In en, this message translates to:
  /// **'Edit Member'**
  String get editMember;

  /// No description provided for @deleteMember.
  ///
  /// In en, this message translates to:
  /// **'Delete Member'**
  String get deleteMember;

  /// No description provided for @searchMembers.
  ///
  /// In en, this message translates to:
  /// **'Search members…'**
  String get searchMembers;

  /// No description provided for @memberDetail.
  ///
  /// In en, this message translates to:
  /// **'Member detail'**
  String get memberDetail;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @arrears.
  ///
  /// In en, this message translates to:
  /// **'Arrears'**
  String get arrears;

  /// No description provided for @arrearsMonths.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 month} other{{count} months}}'**
  String arrearsMonths(num count);

  /// No description provided for @contributionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Contributions'**
  String get contributionsTitle;

  /// No description provided for @recordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record payment'**
  String get recordPayment;

  /// No description provided for @reversal.
  ///
  /// In en, this message translates to:
  /// **'Reversal'**
  String get reversal;

  /// No description provided for @claimsTitle.
  ///
  /// In en, this message translates to:
  /// **'Claims'**
  String get claimsTitle;

  /// No description provided for @submitClaim.
  ///
  /// In en, this message translates to:
  /// **'Submit claim'**
  String get submitClaim;

  /// No description provided for @approveClaim.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveClaim;

  /// No description provided for @rejectClaim.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectClaim;

  /// No description provided for @recordPayout.
  ///
  /// In en, this message translates to:
  /// **'Record payout'**
  String get recordPayout;

  /// No description provided for @claimStatus_submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get claimStatus_submitted;

  /// No description provided for @claimStatus_approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get claimStatus_approved;

  /// No description provided for @claimStatus_rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get claimStatus_rejected;

  /// No description provided for @claimStatus_paid.
  ///
  /// In en, this message translates to:
  /// **'Paid'**
  String get claimStatus_paid;

  /// No description provided for @moreTitle.
  ///
  /// In en, this message translates to:
  /// **'More'**
  String get moreTitle;

  /// No description provided for @announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcements;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @expenses.
  ///
  /// In en, this message translates to:
  /// **'Expenses'**
  String get expenses;

  /// No description provided for @auditLog.
  ///
  /// In en, this message translates to:
  /// **'Audit Log'**
  String get auditLog;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @offlineLabel.
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineLabel;

  /// No description provided for @syncingLabel.
  ///
  /// In en, this message translates to:
  /// **'Syncing…'**
  String get syncingLabel;

  /// No description provided for @syncedLabel.
  ///
  /// In en, this message translates to:
  /// **'Synced'**
  String get syncedLabel;

  /// No description provided for @errorGeneric.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGeneric;

  /// No description provided for @errorNoInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection.'**
  String get errorNoInternet;

  /// No description provided for @emptyState.
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet.'**
  String get emptyState;

  /// No description provided for @currency.
  ///
  /// In en, this message translates to:
  /// **'ETB'**
  String get currency;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @pinTitle.
  ///
  /// In en, this message translates to:
  /// **'Enter PIN'**
  String get pinTitle;

  /// No description provided for @pinSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your 4-digit security PIN to unlock'**
  String get pinSubtitle;

  /// No description provided for @pinSetupTitle.
  ///
  /// In en, this message translates to:
  /// **'Set Security PIN'**
  String get pinSetupTitle;

  /// No description provided for @pinSetupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create a 4-digit PIN for quick and secure access'**
  String get pinSetupSubtitle;

  /// No description provided for @pinConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Confirm PIN'**
  String get pinConfirmTitle;

  /// No description provided for @pinConfirmSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Re-enter your 4-digit security PIN'**
  String get pinConfirmSubtitle;

  /// No description provided for @pinIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Incorrect PIN. Please try again.'**
  String get pinIncorrect;

  /// No description provided for @pinMismatch.
  ///
  /// In en, this message translates to:
  /// **'PINs do not match. Please try again.'**
  String get pinMismatch;

  /// No description provided for @pinTooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Please sign in with password.'**
  String get pinTooManyAttempts;

  /// No description provided for @forgotPin.
  ///
  /// In en, this message translates to:
  /// **'Forgot PIN? Sign In Again'**
  String get forgotPin;

  /// No description provided for @skipForNow.
  ///
  /// In en, this message translates to:
  /// **'Skip for now'**
  String get skipForNow;

  /// No description provided for @pinSetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Security PIN successfully set'**
  String get pinSetSuccess;

  /// No description provided for @changePin.
  ///
  /// In en, this message translates to:
  /// **'Change Security PIN'**
  String get changePin;

  /// No description provided for @pinChangedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Security PIN successfully updated'**
  String get pinChangedSuccess;

  /// No description provided for @accountDeactivated.
  ///
  /// In en, this message translates to:
  /// **'This account is deactivated. Contact an administrator.'**
  String get accountDeactivated;

  /// No description provided for @roleChairperson.
  ///
  /// In en, this message translates to:
  /// **'Chairperson'**
  String get roleChairperson;

  /// No description provided for @roleTreasurer.
  ///
  /// In en, this message translates to:
  /// **'Treasurer'**
  String get roleTreasurer;

  /// No description provided for @roleAuditor.
  ///
  /// In en, this message translates to:
  /// **'Auditor'**
  String get roleAuditor;

  /// No description provided for @roleMember.
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get roleMember;

  /// No description provided for @accessDenied.
  ///
  /// In en, this message translates to:
  /// **'Access Denied: You do not have permission to view this section.'**
  String get accessDenied;

  /// No description provided for @memberIdLabel.
  ///
  /// In en, this message translates to:
  /// **'Member ID'**
  String get memberIdLabel;

  /// No description provided for @phoneLabel.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneLabel;

  /// No description provided for @roleLabel.
  ///
  /// In en, this message translates to:
  /// **'Assigned Role'**
  String get roleLabel;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @statusActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get statusActive;

  /// No description provided for @statusInactive.
  ///
  /// In en, this message translates to:
  /// **'Deactivated'**
  String get statusInactive;

  /// No description provided for @statusSuspended.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get statusSuspended;

  /// No description provided for @statusDeceased.
  ///
  /// In en, this message translates to:
  /// **'Deceased'**
  String get statusDeceased;

  /// No description provided for @fullNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullNameLabel;

  /// No description provided for @registeredDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Registered Date'**
  String get registeredDateLabel;

  /// No description provided for @monthlyDuesLabel.
  ///
  /// In en, this message translates to:
  /// **'Monthly Dues (ETB)'**
  String get monthlyDuesLabel;

  /// No description provided for @totalPaidLabel.
  ///
  /// In en, this message translates to:
  /// **'Total Paid'**
  String get totalPaidLabel;

  /// No description provided for @emergencyContactTitle.
  ///
  /// In en, this message translates to:
  /// **'Emergency Contact'**
  String get emergencyContactTitle;

  /// No description provided for @contactNameLabel.
  ///
  /// In en, this message translates to:
  /// **'Contact Name'**
  String get contactNameLabel;

  /// No description provided for @relationshipLabel.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get relationshipLabel;

  /// No description provided for @dependentsTitle.
  ///
  /// In en, this message translates to:
  /// **'Covered Family / Dependents'**
  String get dependentsTitle;

  /// No description provided for @addDependent.
  ///
  /// In en, this message translates to:
  /// **'Add Dependent'**
  String get addDependent;

  /// No description provided for @dependentName.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get dependentName;

  /// No description provided for @dependentRelationship.
  ///
  /// In en, this message translates to:
  /// **'Relationship'**
  String get dependentRelationship;

  /// No description provided for @noDependents.
  ///
  /// In en, this message translates to:
  /// **'No dependents registered'**
  String get noDependents;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @suspendMember.
  ///
  /// In en, this message translates to:
  /// **'Suspend Member'**
  String get suspendMember;

  /// No description provided for @activateMember.
  ///
  /// In en, this message translates to:
  /// **'Activate Member'**
  String get activateMember;

  /// No description provided for @memberCreatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Member created successfully'**
  String get memberCreatedSuccess;

  /// No description provided for @memberUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Member updated successfully'**
  String get memberUpdatedSuccess;

  /// No description provided for @memberDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Member deleted successfully'**
  String get memberDeletedSuccess;

  /// No description provided for @memberDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this member record?'**
  String get memberDeleteConfirm;

  /// No description provided for @invalidPhone.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid phone number'**
  String get invalidPhone;

  /// No description provided for @invalidName.
  ///
  /// In en, this message translates to:
  /// **'Please enter full name'**
  String get invalidName;

  /// No description provided for @searchNoResults.
  ///
  /// In en, this message translates to:
  /// **'No members found matching your search'**
  String get searchNoResults;

  /// No description provided for @notesLabel.
  ///
  /// In en, this message translates to:
  /// **'Notes / Remarks'**
  String get notesLabel;

  /// No description provided for @receiptNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Receipt Number'**
  String get receiptNumberLabel;

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount (ETB)'**
  String get amountLabel;

  /// No description provided for @paymentDateLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Date'**
  String get paymentDateLabel;

  /// No description provided for @recordedByLabel.
  ///
  /// In en, this message translates to:
  /// **'Recorded By'**
  String get recordedByLabel;

  /// No description provided for @paymentMethodLabel.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethodLabel;

  /// No description provided for @periodLabel.
  ///
  /// In en, this message translates to:
  /// **'Contribution Period'**
  String get periodLabel;

  /// No description provided for @periodMonthLabel.
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get periodMonthLabel;

  /// No description provided for @periodYearLabel.
  ///
  /// In en, this message translates to:
  /// **'Year'**
  String get periodYearLabel;

  /// No description provided for @selectMember.
  ///
  /// In en, this message translates to:
  /// **'Select Member'**
  String get selectMember;

  /// No description provided for @paymentMethodCash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get paymentMethodCash;

  /// No description provided for @paymentMethodTelebirr.
  ///
  /// In en, this message translates to:
  /// **'Telebirr'**
  String get paymentMethodTelebirr;

  /// No description provided for @paymentMethodCbeBirr.
  ///
  /// In en, this message translates to:
  /// **'CBE Birr'**
  String get paymentMethodCbeBirr;

  /// No description provided for @paymentMethodBank.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get paymentMethodBank;

  /// No description provided for @contributionRecordedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Contribution recorded successfully'**
  String get contributionRecordedSuccess;

  /// No description provided for @reversalRecordedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Transaction reversed successfully'**
  String get reversalRecordedSuccess;

  /// No description provided for @reverseTransaction.
  ///
  /// In en, this message translates to:
  /// **'Reverse Transaction'**
  String get reverseTransaction;

  /// No description provided for @reversalReasonPrompt.
  ///
  /// In en, this message translates to:
  /// **'State the reason for this reversal (required for audit trail)'**
  String get reversalReasonPrompt;

  /// No description provided for @reversalReasonLabel.
  ///
  /// In en, this message translates to:
  /// **'Reason for Reversal'**
  String get reversalReasonLabel;

  /// No description provided for @reversalConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reverse this receipt? This will create an offsetting audit ledger record.'**
  String get reversalConfirm;

  /// No description provided for @filterAllMethods.
  ///
  /// In en, this message translates to:
  /// **'All Methods'**
  String get filterAllMethods;

  /// No description provided for @totalCollected.
  ///
  /// In en, this message translates to:
  /// **'Total Collected'**
  String get totalCollected;

  /// No description provided for @thisMonth.
  ///
  /// In en, this message translates to:
  /// **'This Month'**
  String get thisMonth;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @receiptDetail.
  ///
  /// In en, this message translates to:
  /// **'Receipt Detail'**
  String get receiptDetail;

  /// No description provided for @isReversed.
  ///
  /// In en, this message translates to:
  /// **'Reversed'**
  String get isReversed;

  /// No description provided for @reversalRecord.
  ///
  /// In en, this message translates to:
  /// **'Offsetting Reversal'**
  String get reversalRecord;

  /// No description provided for @myContributions.
  ///
  /// In en, this message translates to:
  /// **'My Contributions'**
  String get myContributions;

  /// No description provided for @allContributions.
  ///
  /// In en, this message translates to:
  /// **'All Contributions'**
  String get allContributions;

  /// No description provided for @invalidAmount.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid amount greater than 0'**
  String get invalidAmount;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @membersInArrears.
  ///
  /// In en, this message translates to:
  /// **'In Arrears'**
  String get membersInArrears;

  /// No description provided for @goodStanding.
  ///
  /// In en, this message translates to:
  /// **'Good Standing'**
  String get goodStanding;

  /// No description provided for @pinnedNotice.
  ///
  /// In en, this message translates to:
  /// **'Important Notice'**
  String get pinnedNotice;

  /// No description provided for @associationName.
  ///
  /// In en, this message translates to:
  /// **'Idir Mutual Aid Association'**
  String get associationName;

  /// No description provided for @myFinancialStanding.
  ///
  /// In en, this message translates to:
  /// **'My Financial Standing'**
  String get myFinancialStanding;

  /// No description provided for @collectionProgress.
  ///
  /// In en, this message translates to:
  /// **'Collection Progress'**
  String get collectionProgress;

  /// No description provided for @target.
  ///
  /// In en, this message translates to:
  /// **'Target'**
  String get target;

  /// No description provided for @collected.
  ///
  /// In en, this message translates to:
  /// **'Collected'**
  String get collected;

  /// No description provided for @activeMembers.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get activeMembers;

  /// No description provided for @suspendedMembers.
  ///
  /// In en, this message translates to:
  /// **'Suspended'**
  String get suspendedMembers;

  /// No description provided for @noRecentActivity.
  ///
  /// In en, this message translates to:
  /// **'No recent activity recorded'**
  String get noRecentActivity;

  /// No description provided for @actionRecordPayment.
  ///
  /// In en, this message translates to:
  /// **'Record Payment'**
  String get actionRecordPayment;

  /// No description provided for @actionAddMember.
  ///
  /// In en, this message translates to:
  /// **'Add Member'**
  String get actionAddMember;

  /// No description provided for @actionSubmitClaim.
  ///
  /// In en, this message translates to:
  /// **'Submit Claim'**
  String get actionSubmitClaim;

  /// No description provided for @actionViewReports.
  ///
  /// In en, this message translates to:
  /// **'View Reports'**
  String get actionViewReports;

  /// No description provided for @actionViewAuditLog.
  ///
  /// In en, this message translates to:
  /// **'Audit Log'**
  String get actionViewAuditLog;

  /// No description provided for @reviewClaims.
  ///
  /// In en, this message translates to:
  /// **'Review Claims'**
  String get reviewClaims;

  /// No description provided for @personalDuesRate.
  ///
  /// In en, this message translates to:
  /// **'Monthly dues: {rate} ETB'**
  String personalDuesRate(num rate);

  /// No description provided for @youAreInArrears.
  ///
  /// In en, this message translates to:
  /// **'You have {months} month(s) overdue dues ({amount} ETB). Please make payment to the treasurer.'**
  String youAreInArrears(int months, num amount);

  /// No description provided for @youAreUpToDate.
  ///
  /// In en, this message translates to:
  /// **'Your dues are completely up to date. Thank you for supporting your community!'**
  String get youAreUpToDate;
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
      <String>['am', 'en', 'om'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'am':
      return AppLocalizationsAm();
    case 'en':
      return AppLocalizationsEn();
    case 'om':
      return AppLocalizationsOm();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
