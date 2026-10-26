// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Amharic (`am`).
class AppLocalizationsAm extends AppLocalizations {
  AppLocalizationsAm([String locale = 'am']) : super(locale);

  @override
  String get appName => 'ኢዲር አፕ';

  @override
  String get idirName => 'ኢዲር';

  @override
  String get loginTitle => 'ግባ';

  @override
  String get loginEmailHint => 'ኢሜይል ወይም ስልክ';

  @override
  String get loginPasswordHint => 'የሚስጥር ቁጥር';

  @override
  String get loginButton => 'ግባ';

  @override
  String get forgotPassword => 'የሚስጥር ቁጥር ረሳዎ?';

  @override
  String get loginError => 'ኢሜይል ወይም የሚስጥር ቁጥር ትክክል አይደለም።';

  @override
  String get loginDemoHint => 'የተለያዩ የስራ ድርሻዎችን ለመሞከር ከታች ካሉት መለያዎች ይምረጡ';

  @override
  String get navHome => 'ቤት';

  @override
  String get navMembers => 'አባላት';

  @override
  String get navContributions => 'ክፍያዎች';

  @override
  String get navClaims => 'ጥያቄዎች';

  @override
  String get navMore => 'ተጨማሪ';

  @override
  String get dashboardTitle => 'ዳሽቦርድ';

  @override
  String get totalFund => 'ጠቅላላ ገንዘብ';

  @override
  String get thisMonthCollected => 'በዚህ ወር የተሰበሰበ';

  @override
  String get thisMonthExpected => 'በዚህ ወር የሚጠበቅ';

  @override
  String get memberCount => 'አባላት';

  @override
  String get pendingClaims => 'ጥያቄዎች';

  @override
  String get recentActivity => 'የቅርብ ጊዜ እንቅስቃሴ';

  @override
  String get membersTitle => 'አባላት';

  @override
  String get addMember => 'አባል ያክሉ';

  @override
  String get editMember => 'አባል አርትዕ';

  @override
  String get deleteMember => 'አባል ሰርዝ';

  @override
  String get searchMembers => 'አባላት ይፈልጉ…';

  @override
  String get memberDetail => 'የአባል ዝርዝር መረጃ';

  @override
  String get balance => 'ሂሳብ';

  @override
  String get arrears => 'ቀሪ ዕዳ';

  @override
  String arrearsMonths(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return '$countString ወራት';
  }

  @override
  String get contributionsTitle => 'ክፍያዎች';

  @override
  String get recordPayment => 'ክፍያ ይመዝግቡ';

  @override
  String get reversal => 'መልስ';

  @override
  String get claimsTitle => 'ጥያቄዎች';

  @override
  String get submitClaim => 'ጥያቄ ያቅርቡ';

  @override
  String get approveClaim => 'ያጽድቁ';

  @override
  String get rejectClaim => 'ይቃወሙ';

  @override
  String get recordPayout => 'ክፍያ ይመዝግቡ';

  @override
  String get claimStatus_submitted => 'ቀርቧል';

  @override
  String get claimStatus_approved => 'ጸድቋል';

  @override
  String get claimStatus_rejected => 'ተቃውሟል';

  @override
  String get claimStatus_paid => 'ተከፍሏል';

  @override
  String get moreTitle => 'ተጨማሪ';

  @override
  String get announcements => 'ማስታወቂያዎች';

  @override
  String get reports => 'ሪፖርቶች';

  @override
  String get expenses => 'ወጪዎች';

  @override
  String get auditLog => 'የኦዲት ምዝገባ';

  @override
  String get settings => 'ቅንብሮች';

  @override
  String get account => 'መለያ';

  @override
  String get logout => 'ውጣ';

  @override
  String get offlineLabel => 'ከኔት ውጪ';

  @override
  String get syncingLabel => 'በማስተባበር…';

  @override
  String get syncedLabel => 'ተስተካክሏል';

  @override
  String get errorGeneric => 'ችግር ተፈጠረ። እንደገና ይሞክሩ።';

  @override
  String get errorNoInternet => 'የበይነ መረብ ግንኙነት የለም።';

  @override
  String get emptyState => 'ምንም ነገር የለም።';

  @override
  String get currency => 'ብር';

  @override
  String get save => 'አስቀምጥ';

  @override
  String get cancel => 'ሰርዝ';

  @override
  String get confirm => 'አረጋግጥ';

  @override
  String get delete => 'ሰርዝ';

  @override
  String get edit => 'አርትዕ';

  @override
  String get pinTitle => 'ፒን ያስገቡ';

  @override
  String get pinSubtitle => 'መተግበሪያውን ለመክፈት ባለ 4 ዲጂት የደህንነት ፒንዎን ያስገቡ';

  @override
  String get pinSetupTitle => 'የደህንነት ፒን ያዘጋጁ';

  @override
  String get pinSetupSubtitle => 'ለቀጣይ ደህንነቱ የተጠበቀ መዳረሻ ባለ 4 ዲጂት ፒን ይፍጠሩ';

  @override
  String get pinConfirmTitle => 'ፒን ያረጋግጡ';

  @override
  String get pinConfirmSubtitle => 'ባለ 4 ዲጂት ፒንዎን እንደገና ያስገቡ';

  @override
  String get pinIncorrect => 'የተሳሳተ ፒን ኮድ። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get pinMismatch => 'ፒን ኮዶቹ አይመሳሰሉም። እባክዎ እንደገና ይሞክሩ።';

  @override
  String get pinTooManyAttempts => 'ከመጠን በላይ ሙከራዎች ተደርገዋል። እባክዎ በይለፍ ቃልዎ ይግቡ።';

  @override
  String get forgotPin => 'ፒን ረሱ? እንደገና ይግቡ';

  @override
  String get skipForNow => 'ለአሁኑ ይለፉ';

  @override
  String get pinSetSuccess => 'የደህንነት ፒን በተሳካ ሁኔታ ተዘጋጅቷል';

  @override
  String get changePin => 'የደህንነት ፒን ቀይር';

  @override
  String get pinChangedSuccess => 'የደህንነት ፒን በተሳካ ሁኔታ ተቀይሯል';

  @override
  String get accountDeactivated => 'ይህ መለያ ተሰናክሏል። እባክዎ አስተዳዳሪን ያነጋግሩ።';

  @override
  String get roleChairperson => 'ሊቀመንበር';

  @override
  String get roleTreasurer => 'ገንዘብ ያዥ';

  @override
  String get roleAuditor => 'ኦዲተር';

  @override
  String get roleMember => 'አባል';

  @override
  String get accessDenied => 'መዳረሻ ተከልክሏል፡ ይህን ክፍል ለመመልከት ፈቃድ የለዎትም።';

  @override
  String get memberIdLabel => 'የአባል መለያ ቁጥር';

  @override
  String get phoneLabel => 'ስልክ ቁጥር';

  @override
  String get roleLabel => 'የስራ ድርሻ';

  @override
  String get statusLabel => 'ሁኔታ';

  @override
  String get statusActive => 'ንቁ';

  @override
  String get statusInactive => 'የተሰናከለ';

  @override
  String get statusSuspended => 'የታገደ';

  @override
  String get statusDeceased => 'ያረፈ';

  @override
  String get fullNameLabel => 'ሙሉ ስም';

  @override
  String get registeredDateLabel => 'የተመዘገበበት ቀን';

  @override
  String get monthlyDuesLabel => 'ወርሃዊ መዋጮ (ብር)';

  @override
  String get totalPaidLabel => 'ጠቅላላ የተከፈለ';

  @override
  String get emergencyContactTitle => 'የድንገተኛ አደጋ ተጠሪ';

  @override
  String get contactNameLabel => 'የተጠሪ ስም';

  @override
  String get relationshipLabel => 'ዝምድና';

  @override
  String get dependentsTitle => 'የሚተዳደሩ የቤተሰብ አባላት';

  @override
  String get addDependent => 'ተጠቃሚ ጨምር';

  @override
  String get dependentName => 'ስም';

  @override
  String get dependentRelationship => 'ዝምድና';

  @override
  String get noDependents => 'ምንም የተመዘገቡ ተጠቃሚዎች የሉም';

  @override
  String get filterAll => 'ሁሉም';

  @override
  String get suspendMember => 'አባል አግድ';

  @override
  String get activateMember => 'አባል አንቃ';

  @override
  String get memberCreatedSuccess => 'አባል በተሳካ ሁኔታ ተመዝግቧል';

  @override
  String get memberUpdatedSuccess => 'የአባል መረጃ በተሳካ ሁኔታ ተሻሽሏል';

  @override
  String get memberDeletedSuccess => 'አባል በተሳካ ሁኔታ ተሰርዟል';

  @override
  String get memberDeleteConfirm => 'ይህን የአባል መረጃ መሰረዝ ይፈልጋሉ?';

  @override
  String get invalidPhone => 'ትክክለኛ ስልክ ቁጥር ያስገቡ';

  @override
  String get invalidName => 'ሙሉ ስም ያስገቡ';

  @override
  String get searchNoResults => 'ምንም የተገኘ አባል የለም';

  @override
  String get notesLabel => 'ማስታወሻ / አስተያየት';

  @override
  String get receiptNumberLabel => 'የደረሰኝ ቁጥር';

  @override
  String get amountLabel => 'የገንዘብ መጠን (ብር)';

  @override
  String get paymentDateLabel => 'የክፍያ ቀን';

  @override
  String get recordedByLabel => 'የመዘገበው ሰው';

  @override
  String get paymentMethodLabel => 'የክፍያ መንገድ';

  @override
  String get periodLabel => 'የመዋጮ ጊዜ';

  @override
  String get periodMonthLabel => 'ወር';

  @override
  String get periodYearLabel => 'ዓመት';

  @override
  String get selectMember => 'አባል ይምረጡ';

  @override
  String get paymentMethodCash => 'ጥሬ ገንዘብ';

  @override
  String get paymentMethodTelebirr => 'ቴሌብር';

  @override
  String get paymentMethodCbeBirr => 'ሲቢኢ ብር';

  @override
  String get paymentMethodBank => 'የባንክ ዝውውር';

  @override
  String get contributionRecordedSuccess => 'ክፍያ በተሳካ ሁኔታ ተመዝግቧል';

  @override
  String get reversalRecordedSuccess => 'ክፍያ በተሳካ ሁኔታ ተመልሷል';

  @override
  String get reverseTransaction => 'ክፍያ መልስ';

  @override
  String get reversalReasonPrompt => 'የመልስ ምክንያቱን ይጥቀሱ (ለኦዲት ምዝገባ አስፈላጊ ነው)';

  @override
  String get reversalReasonLabel => 'የመልስ ምክንያት';

  @override
  String get reversalConfirm =>
      'ይህን የክፍያ ደረሰኝ መመለስ ይፈልጋሉ? ይህ ተመጣጣኝ የኦዲት መዝገብ ይፈጥራል።';

  @override
  String get filterAllMethods => 'ሁሉም መንገዶች';

  @override
  String get totalCollected => 'ጠቅላላ የተሰበሰበ';

  @override
  String get thisMonth => 'በዚህ ወር';

  @override
  String get allTime => 'በሙሉ ጊዜ';

  @override
  String get receiptDetail => 'የደረሰኝ ዝርዝር';

  @override
  String get isReversed => 'የተመለሰ';

  @override
  String get reversalRecord => 'ተመላሽ ምዝገባ';

  @override
  String get myContributions => 'የእኔ ክፍያዎች';

  @override
  String get allContributions => 'ሁሉም ክፍያዎች';

  @override
  String get invalidAmount => 'ከ0 በላይ የሆነ ትክክለኛ የገንዘብ መጠን ያስገቡ';

  @override
  String get quickActions => 'ፈጣን እርምጃዎች';

  @override
  String get viewAll => 'ሁሉንም ይመልከቱ';

  @override
  String get membersInArrears => 'በዕዳ ላይ ያሉ';

  @override
  String get goodStanding => 'ጥሩ አቋም';

  @override
  String get pinnedNotice => 'አስፈላጊ ማስታወቂያ';

  @override
  String get associationName => 'የእድር መረዳጃ ማህበር';

  @override
  String get myFinancialStanding => 'የእኔ የገንዘብ አቋም';

  @override
  String get collectionProgress => 'የክፍያ አሰባሰብ ሂደት';

  @override
  String get target => 'ግብ';

  @override
  String get collected => 'የተሰበሰበ';

  @override
  String get activeMembers => 'ንቁ';

  @override
  String get suspendedMembers => 'የታገዱ';

  @override
  String get noRecentActivity => 'ምንም የቅርብ ጊዜ እንቅስቃሴ የለም';

  @override
  String get actionRecordPayment => 'ክፍያ መዝግብ';

  @override
  String get actionAddMember => 'አባል አክል';

  @override
  String get actionSubmitClaim => 'ጥያቄ አቅርብ';

  @override
  String get actionViewReports => 'ሪፖርቶች ተመልከት';

  @override
  String get actionViewAuditLog => 'ኦዲት ተመልከት';

  @override
  String get reviewClaims => 'ጥያቄዎችን ይገምግሙ';

  @override
  String personalDuesRate(num rate) {
    return 'ወርሃዊ መዋጮ: $rate ብር';
  }

  @override
  String youAreInArrears(int months, num amount) {
    return 'የ$months ወራት ቀሪ ዕዳ አለብዎት ($amount ብር)። እባክዎ ለገንዘብ ያዥ ይክፈሉ።';
  }

  @override
  String get youAreUpToDate => 'ክፍያዎችዎ የተሟሉ ናቸው። ማህበሩን ስለደገፉ እናመሰግናለን!';

  @override
  String get groupChatTitle => 'የእድር የቡድን ውይይት';

  @override
  String get typeMessageHint => 'መልእክት ይጻፉ…';

  @override
  String get chatEmptyTitle => 'እስካሁን ምንም መልእክት የለም';

  @override
  String get chatEmptyDesc => 'ከእድር ማህበረሰብ አባላት ጋር ውይይት ይጀምሩ!';

  @override
  String get retrySend => 'እንደገና ሞክር';

  @override
  String get sendFailed => 'መልእክቱ አልተላከም። እንደገና ለመሞከር ይንኩ።';

  @override
  String get chatMembersOnlyNotice => 'ለተረጋገጡ የእድር አባላት ብቻ የተፈቀደ';
}
