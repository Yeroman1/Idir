// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Oromo (`om`).
class AppLocalizationsOm extends AppLocalizations {
  AppLocalizationsOm([String locale = 'om']) : super(locale);

  @override
  String get appName => 'App Idir';

  @override
  String get idirName => 'Idir';

  @override
  String get loginTitle => 'Seenu';

  @override
  String get loginEmailHint => 'Imeelii ykn lakkoofsa bilbilaa';

  @override
  String get loginPasswordHint => 'Jecha darbii';

  @override
  String get loginButton => 'Seenu';

  @override
  String get forgotPassword => 'Jecha darbii dagatte?';

  @override
  String get loginError => 'Imeelii ykn jecha darbii dogoggora.';

  @override
  String get loginDemoHint =>
      'Gahee adda addaa yaaluuf herregota kana fayyadamaa';

  @override
  String get navHome => 'Mana';

  @override
  String get navMembers => 'Miseensota';

  @override
  String get navContributions => 'Kaffaltii';

  @override
  String get navClaims => 'Gaaffii';

  @override
  String get navMore => 'Dabalata';

  @override
  String get dashboardTitle => 'Dashboordii';

  @override
  String get totalFund => 'Maallaqa Waliigalaa';

  @override
  String get thisMonthCollected => 'Ji\'a kana walitti qabame';

  @override
  String get thisMonthExpected => 'Ji\'a kana eegame';

  @override
  String get memberCount => 'Miseensota';

  @override
  String get pendingClaims => 'Gaaffii eegaa';

  @override
  String get recentActivity => 'Hojii dhihootti';

  @override
  String get membersTitle => 'Miseensota';

  @override
  String get addMember => 'Miseensa dabaluu';

  @override
  String get editMember => 'Miseensa gulaali';

  @override
  String get deleteMember => 'Miseensa haqi';

  @override
  String get searchMembers => 'Miseensota barbaadi…';

  @override
  String get memberDetail => 'Ibsa bal\'aa miseensaa';

  @override
  String get balance => 'Hisaabii';

  @override
  String get arrears => 'Hafe';

  @override
  String arrearsMonths(num count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    return 'Ji\'a $countString';
  }

  @override
  String get contributionsTitle => 'Kaffaltii';

  @override
  String get recordPayment => 'Kaffaltii galmeessi';

  @override
  String get reversal => 'Deebisuu';

  @override
  String get claimsTitle => 'Gaaffii';

  @override
  String get submitClaim => 'Gaaffii dhiyeessi';

  @override
  String get approveClaim => 'Hayyami';

  @override
  String get rejectClaim => 'Diddi';

  @override
  String get recordPayout => 'Kaffaltii galmeessi';

  @override
  String get claimStatus_submitted => 'Dhiyaate';

  @override
  String get claimStatus_approved => 'Hayyamamee';

  @override
  String get claimStatus_rejected => 'Didamee';

  @override
  String get claimStatus_paid => 'Kaffalame';

  @override
  String get moreTitle => 'Dabalata';

  @override
  String get announcements => 'Beeksisa';

  @override
  String get reports => 'Gabaasa';

  @override
  String get expenses => 'Baasiiwwan';

  @override
  String get auditLog => 'Galmee Dhoksaa';

  @override
  String get settings => 'Qindaa\'ina';

  @override
  String get account => 'Herrega';

  @override
  String get logout => 'Ba\'i';

  @override
  String get offlineLabel => 'Toora Ala';

  @override
  String get syncingLabel => 'Walitti dhufaa…';

  @override
  String get syncedLabel => 'Walitti dhufe';

  @override
  String get errorGeneric => 'Dogoggorri uumame. Irra deebi\'ii yaali.';

  @override
  String get errorNoInternet => 'Interneetii hin jiru.';

  @override
  String get emptyState => 'Wanti hin jiru.';

  @override
  String get currency => 'ETB';

  @override
  String get save => 'Kuusi';

  @override
  String get cancel => 'Dhiisi';

  @override
  String get confirm => 'Mirkaneessi';

  @override
  String get delete => 'Haqi';

  @override
  String get edit => 'Gulaali';

  @override
  String get pinTitle => 'PIN Galchaa';

  @override
  String get pinSubtitle => 'Banuuf koodii PIN dijitii 4 galchaa';

  @override
  String get pinSetupTitle => 'PIN Nageenyaa Qopheessaa';

  @override
  String get pinSetupSubtitle =>
      'Seensa saffisaa fi amansiisaaf PIN dijitii 4 uumaa';

  @override
  String get pinConfirmTitle => 'PIN Mirkaneessaa';

  @override
  String get pinConfirmSubtitle =>
      'Koodii PIN dijitii 4 irra deebi\'aa galchaa';

  @override
  String get pinIncorrect => 'PIN sirrii miti. Irra deebi\'aa yaalaa.';

  @override
  String get pinMismatch =>
      'Koodiiwwan PIN wal hin simne. Irra deebi\'aa yaalaa.';

  @override
  String get pinTooManyAttempts =>
      'Yaalii baay\'ee. Maaloo jecha icciitiitiin seenaa.';

  @override
  String get forgotPin => 'PIN irraanfattanii? Ammas seenaa';

  @override
  String get skipForNow => 'Ammaaf darbi';

  @override
  String get pinSetSuccess => 'PIN nageenyaa milkaa\'inaan qophaa\'e';

  @override
  String get changePin => 'PIN Nageenyaa Jijjiiri';

  @override
  String get pinChangedSuccess => 'PIN nageenyaa milkaa\'inaan haaromeera';

  @override
  String get accountDeactivated =>
      'Akkaawuntii kun cufameera. Bulchaa qunnamaa.';

  @override
  String get roleChairperson => 'Dura-taa\'aa';

  @override
  String get roleTreasurer => 'Qabaa Maallaqaa';

  @override
  String get roleAuditor => 'Hojii Oditaraa';

  @override
  String get roleMember => 'Miseensa';

  @override
  String get accessDenied =>
      'Eeyyama Hin Qabdan: Kutaa kana ilaaluuf mirga hin qabdan.';

  @override
  String get memberIdLabel => 'Lakk. Miseensaa';

  @override
  String get phoneLabel => 'Lakk. Bilbilaa';

  @override
  String get roleLabel => 'Gahee Hojii';

  @override
  String get statusLabel => 'Haala';

  @override
  String get statusActive => 'Hojjataa';

  @override
  String get statusInactive => 'Cufameera';

  @override
  String get statusSuspended => 'Dhaabbateera';

  @override
  String get statusDeceased => 'Boqoteera';

  @override
  String get fullNameLabel => 'Maqaa Guutuu';

  @override
  String get registeredDateLabel => 'Guyyaa Galmee';

  @override
  String get monthlyDuesLabel => 'Buusii Ji\'aa (ETB)';

  @override
  String get totalPaidLabel => 'Waliigala Kaffalame';

  @override
  String get emergencyContactTitle => 'Nama Yeroo Balaa Qunnamamu';

  @override
  String get contactNameLabel => 'Maqaa Qunnamtii';

  @override
  String get relationshipLabel => 'Firooma';

  @override
  String get dependentsTitle => 'Maatii Hirkattuu';

  @override
  String get addDependent => 'Hirkattuu Dabali';

  @override
  String get dependentName => 'Maqaa';

  @override
  String get dependentRelationship => 'Firooma';

  @override
  String get noDependents => 'Hirkattuun galmaa\'e hin jiru';

  @override
  String get filterAll => 'Hunda';

  @override
  String get suspendMember => 'Miseensa Dhaabi';

  @override
  String get activateMember => 'Miseensa Kakaasi';

  @override
  String get memberCreatedSuccess => 'Miseensi milkaa\'inaan galmaa\'eera';

  @override
  String get memberUpdatedSuccess => 'Odeeffannoon miseensaa haaromeera';

  @override
  String get memberDeletedSuccess => 'Miseensi haqameera';

  @override
  String get memberDeleteConfirm => 'Miseensa kana haquu barbaadduu?';

  @override
  String get invalidPhone => 'Lakkoofsa bilbilaa sirrii galchaa';

  @override
  String get invalidName => 'Maqaa guutuu galchaa';

  @override
  String get searchNoResults => 'Miseensi barbaadame hin argamne';

  @override
  String get notesLabel => 'Yaada / Hubachiisa';

  @override
  String get receiptNumberLabel => 'Lakk. Nageeyyii';

  @override
  String get amountLabel => 'Hamma Maallaqaa (ETB)';

  @override
  String get paymentDateLabel => 'Guyyaa Kaffaltii';

  @override
  String get recordedByLabel => 'Nama Galmeesse';

  @override
  String get paymentMethodLabel => 'Mala Kaffaltii';

  @override
  String get periodLabel => 'Yeroo Buusii';

  @override
  String get periodMonthLabel => 'Ji\'a';

  @override
  String get periodYearLabel => 'Bara';

  @override
  String get selectMember => 'Miseensa Filadhu';

  @override
  String get paymentMethodCash => 'Maallaqa Callaa';

  @override
  String get paymentMethodTelebirr => 'Telebirr';

  @override
  String get paymentMethodCbeBirr => 'CBE Birr';

  @override
  String get paymentMethodBank => 'Dabarsa Baankii';

  @override
  String get contributionRecordedSuccess =>
      'Kaffaltiin milkaa\'inaan galmaa\'eera';

  @override
  String get reversalRecordedSuccess => 'Kaffaltiin milkaa\'inaan deebi\'eera';

  @override
  String get reverseTransaction => 'Kaffaltii Deebisi';

  @override
  String get reversalReasonPrompt =>
      'Sababa deebisaa ibsaa (oditiif barbaachisaadha)';

  @override
  String get reversalReasonLabel => 'Sababa Deebisaa';

  @override
  String get reversalConfirm =>
      'Nageeyyii kana deebisuu barbaadduu? Kun galmee oditii qopheessa.';

  @override
  String get filterAllMethods => 'Mala Hundaa';

  @override
  String get totalCollected => 'Waliigala Walitti Qabame';

  @override
  String get thisMonth => 'Ji\'a Kana';

  @override
  String get allTime => 'Yeroo Hunda';

  @override
  String get receiptDetail => 'Ibsa Nageeyyii';

  @override
  String get isReversed => 'Deebi\'eera';

  @override
  String get reversalRecord => 'Galmee Deebisaa';

  @override
  String get myContributions => 'Kaffaltii Koo';

  @override
  String get allContributions => 'Kaffaltii Hundaa';

  @override
  String get invalidAmount => 'Hamma 0 ol ta\'e sirrii galchaa';

  @override
  String get quickActions => 'Tarkanniiwwan Saffisaa';

  @override
  String get viewAll => 'Hunda Ilaali';

  @override
  String get membersInArrears => 'Liqii Keessa Jiran';

  @override
  String get goodStanding => 'Sadarkaa Gaarii';

  @override
  String get pinnedNotice => 'Beeksisa Barbaachisaa';

  @override
  String get associationName => 'Waldaa Gargaarsa Gamtaa Iddirii';

  @override
  String get myFinancialStanding => 'Sadarkaa Maallaqa Koo';

  @override
  String get collectionProgress => 'Adeemsa Walitti Qabuu';

  @override
  String get target => 'Kaayyoo';

  @override
  String get collected => 'Kan Walitti Qabame';

  @override
  String get activeMembers => 'Hojjataa';

  @override
  String get suspendedMembers => 'Kan Dhaabate';

  @override
  String get noRecentActivity => 'Sochiin dhihoo hin jiru';

  @override
  String get actionRecordPayment => 'Kaffaltii Galmeessi';

  @override
  String get actionAddMember => 'Miseensa Dabali';

  @override
  String get actionSubmitClaim => 'Gaaffii Dhiyeessi';

  @override
  String get actionViewReports => 'Gabaasa Ilaali';

  @override
  String get actionViewAuditLog => 'Galmee Dhoksaa Ilaali';

  @override
  String get reviewClaims => 'Gaaffiiwwan Sakatta\'i';

  @override
  String personalDuesRate(num rate) {
    return 'Buusii ji\'aa: $rate ETB';
  }

  @override
  String youAreInArrears(int months, num amount) {
    return 'Idaa ji\'a $months qabdu ($amount ETB). Maaloo kaffalaa.';
  }

  @override
  String get youAreUpToDate =>
      'Kaffaltiin keessan guutuu dha. Hawaasa deeggaruu keessaniif galatoomaa!';
}
