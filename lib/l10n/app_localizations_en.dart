// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'Idir App';

  @override
  String get idirName => 'Idir';

  @override
  String get loginTitle => 'Sign In';

  @override
  String get loginEmailHint => 'Email or phone';

  @override
  String get loginPasswordHint => 'Password';

  @override
  String get loginButton => 'Sign In';

  @override
  String get forgotPassword => 'Forgot password?';

  @override
  String get loginError => 'Invalid email or password.';

  @override
  String get loginDemoHint =>
      'Demo accounts available below for quick role testing';

  @override
  String get navHome => 'Home';

  @override
  String get navMembers => 'Members';

  @override
  String get navContributions => 'Contributions';

  @override
  String get navClaims => 'Claims';

  @override
  String get navMore => 'More';

  @override
  String get dashboardTitle => 'Dashboard';

  @override
  String get totalFund => 'Total Fund';

  @override
  String get thisMonthCollected => 'Collected this month';

  @override
  String get thisMonthExpected => 'Expected this month';

  @override
  String get memberCount => 'Members';

  @override
  String get pendingClaims => 'Pending claims';

  @override
  String get recentActivity => 'Recent activity';

  @override
  String get membersTitle => 'Members';

  @override
  String get addMember => 'Add member';

  @override
  String get editMember => 'Edit Member';

  @override
  String get deleteMember => 'Delete Member';

  @override
  String get searchMembers => 'Search members…';

  @override
  String get memberDetail => 'Member detail';

  @override
  String get balance => 'Balance';

  @override
  String get arrears => 'Arrears';

  @override
  String arrearsMonths(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString months',
      one: '1 month',
    );
    return '$_temp0';
  }

  @override
  String get contributionsTitle => 'Contributions';

  @override
  String get recordPayment => 'Record payment';

  @override
  String get reversal => 'Reversal';

  @override
  String get claimsTitle => 'Claims';

  @override
  String get submitClaim => 'Submit claim';

  @override
  String get approveClaim => 'Approve';

  @override
  String get rejectClaim => 'Reject';

  @override
  String get recordPayout => 'Record payout';

  @override
  String get claimStatus_submitted => 'Submitted';

  @override
  String get claimStatus_approved => 'Approved';

  @override
  String get claimStatus_rejected => 'Rejected';

  @override
  String get claimStatus_paid => 'Paid';

  @override
  String get moreTitle => 'More';

  @override
  String get announcements => 'Announcements';

  @override
  String get reports => 'Reports';

  @override
  String get expenses => 'Expenses';

  @override
  String get auditLog => 'Audit Log';

  @override
  String get settings => 'Settings';

  @override
  String get account => 'Account';

  @override
  String get logout => 'Logout';

  @override
  String get offlineLabel => 'Offline';

  @override
  String get syncingLabel => 'Syncing…';

  @override
  String get syncedLabel => 'Synced';

  @override
  String get errorGeneric => 'Something went wrong. Please try again.';

  @override
  String get errorNoInternet => 'No internet connection.';

  @override
  String get emptyState => 'Nothing here yet.';

  @override
  String get currency => 'ETB';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get confirm => 'Confirm';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get pinTitle => 'Enter PIN';

  @override
  String get pinSubtitle => 'Enter your 4-digit security PIN to unlock';

  @override
  String get pinSetupTitle => 'Set Security PIN';

  @override
  String get pinSetupSubtitle =>
      'Create a 4-digit PIN for quick and secure access';

  @override
  String get pinConfirmTitle => 'Confirm PIN';

  @override
  String get pinConfirmSubtitle => 'Re-enter your 4-digit security PIN';

  @override
  String get pinIncorrect => 'Incorrect PIN. Please try again.';

  @override
  String get pinMismatch => 'PINs do not match. Please try again.';

  @override
  String get pinTooManyAttempts =>
      'Too many attempts. Please sign in with password.';

  @override
  String get forgotPin => 'Forgot PIN? Sign In Again';

  @override
  String get skipForNow => 'Skip for now';

  @override
  String get pinSetSuccess => 'Security PIN successfully set';

  @override
  String get changePin => 'Change Security PIN';

  @override
  String get pinChangedSuccess => 'Security PIN successfully updated';

  @override
  String get accountDeactivated =>
      'This account is deactivated. Contact an administrator.';

  @override
  String get roleChairperson => 'Chairperson';

  @override
  String get roleTreasurer => 'Treasurer';

  @override
  String get roleAuditor => 'Auditor';

  @override
  String get roleMember => 'Member';

  @override
  String get accessDenied =>
      'Access Denied: You do not have permission to view this section.';

  @override
  String get memberIdLabel => 'Member ID';

  @override
  String get phoneLabel => 'Phone Number';

  @override
  String get roleLabel => 'Assigned Role';

  @override
  String get statusLabel => 'Status';

  @override
  String get statusActive => 'Active';

  @override
  String get statusInactive => 'Deactivated';

  @override
  String get statusSuspended => 'Suspended';

  @override
  String get statusDeceased => 'Deceased';

  @override
  String get fullNameLabel => 'Full Name';

  @override
  String get registeredDateLabel => 'Registered Date';

  @override
  String get monthlyDuesLabel => 'Monthly Dues (ETB)';

  @override
  String get totalPaidLabel => 'Total Paid';

  @override
  String get emergencyContactTitle => 'Emergency Contact';

  @override
  String get contactNameLabel => 'Contact Name';

  @override
  String get relationshipLabel => 'Relationship';

  @override
  String get dependentsTitle => 'Covered Family / Dependents';

  @override
  String get addDependent => 'Add Dependent';

  @override
  String get dependentName => 'Name';

  @override
  String get dependentRelationship => 'Relationship';

  @override
  String get noDependents => 'No dependents registered';

  @override
  String get filterAll => 'All';

  @override
  String get suspendMember => 'Suspend Member';

  @override
  String get activateMember => 'Activate Member';

  @override
  String get memberCreatedSuccess => 'Member created successfully';

  @override
  String get memberUpdatedSuccess => 'Member updated successfully';

  @override
  String get memberDeletedSuccess => 'Member deleted successfully';

  @override
  String get memberDeleteConfirm =>
      'Are you sure you want to remove this member record?';

  @override
  String get invalidPhone => 'Please enter a valid phone number';

  @override
  String get invalidName => 'Please enter full name';

  @override
  String get searchNoResults => 'No members found matching your search';

  @override
  String get notesLabel => 'Notes / Remarks';

  @override
  String get receiptNumberLabel => 'Receipt Number';

  @override
  String get amountLabel => 'Amount (ETB)';

  @override
  String get paymentDateLabel => 'Payment Date';

  @override
  String get recordedByLabel => 'Recorded By';

  @override
  String get paymentMethodLabel => 'Payment Method';

  @override
  String get periodLabel => 'Contribution Period';

  @override
  String get periodMonthLabel => 'Month';

  @override
  String get periodYearLabel => 'Year';

  @override
  String get selectMember => 'Select Member';

  @override
  String get paymentMethodCash => 'Cash';

  @override
  String get paymentMethodTelebirr => 'Telebirr';

  @override
  String get paymentMethodCbeBirr => 'CBE Birr';

  @override
  String get paymentMethodBank => 'Bank Transfer';

  @override
  String get contributionRecordedSuccess =>
      'Contribution recorded successfully';

  @override
  String get reversalRecordedSuccess => 'Transaction reversed successfully';

  @override
  String get reverseTransaction => 'Reverse Transaction';

  @override
  String get reversalReasonPrompt =>
      'State the reason for this reversal (required for audit trail)';

  @override
  String get reversalReasonLabel => 'Reason for Reversal';

  @override
  String get reversalConfirm =>
      'Are you sure you want to reverse this receipt? This will create an offsetting audit ledger record.';

  @override
  String get filterAllMethods => 'All Methods';

  @override
  String get totalCollected => 'Total Collected';

  @override
  String get thisMonth => 'This Month';

  @override
  String get allTime => 'All Time';

  @override
  String get receiptDetail => 'Receipt Detail';

  @override
  String get isReversed => 'Reversed';

  @override
  String get reversalRecord => 'Offsetting Reversal';

  @override
  String get myContributions => 'My Contributions';

  @override
  String get allContributions => 'All Contributions';

  @override
  String get invalidAmount => 'Please enter a valid amount greater than 0';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get viewAll => 'View All';

  @override
  String get membersInArrears => 'In Arrears';

  @override
  String get goodStanding => 'Good Standing';

  @override
  String get pinnedNotice => 'Important Notice';

  @override
  String get associationName => 'Idir Mutual Aid Association';

  @override
  String get myFinancialStanding => 'My Financial Standing';

  @override
  String get collectionProgress => 'Collection Progress';

  @override
  String get target => 'Target';

  @override
  String get collected => 'Collected';

  @override
  String get activeMembers => 'Active';

  @override
  String get suspendedMembers => 'Suspended';

  @override
  String get noRecentActivity => 'No recent activity recorded';

  @override
  String get actionRecordPayment => 'Record Payment';

  @override
  String get actionAddMember => 'Add Member';

  @override
  String get actionSubmitClaim => 'Submit Claim';

  @override
  String get actionViewReports => 'View Reports';

  @override
  String get actionViewAuditLog => 'Audit Log';

  @override
  String get reviewClaims => 'Review Claims';

  @override
  String personalDuesRate(num rate) {
    return 'Monthly dues: $rate ETB';
  }

  @override
  String youAreInArrears(int months, num amount) {
    return 'You have $months month(s) overdue dues ($amount ETB). Please make payment to the treasurer.';
  }

  @override
  String get youAreUpToDate =>
      'Your dues are completely up to date. Thank you for supporting your community!';
}
