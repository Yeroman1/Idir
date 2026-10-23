/// App-wide constants — no magic strings scattered in the codebase.
abstract final class AppConstants {
  // SharedPreferences keys
  static const prefIsLoggedIn = 'is_logged_in';
  static const prefLocale = 'app_locale';
  static const prefThemeMode = 'theme_mode';
  static const prefPinEnabled = 'pin_enabled';
  static const prefLastActiveTimestamp = 'last_active_timestamp';
  static const prefActiveIdirId = 'active_idir_id';

  // Firestore collection names
  static const colUsers = 'users';
  static const colMembers = 'members';
  static const colContributions = 'contributions';
  static const colClaims = 'claims';
  static const colExpenses = 'expenses';
  static const colAnnouncements = 'announcements';
  static const colAuditLogs = 'auditLogs';
  static const colSettings = 'settings';
  static const docSettingsMain = 'main';

  // Secure storage keys
  static const secureKeyPin = 'user_pin_hash';
  static const secureKeyPinSalt = 'user_pin_salt';
  static const secureKeyPinAttempts = 'pin_failed_attempts';
  static const secureKeyAuthToken = 'auth_token';
  static const secureKeyRefreshToken = 'refresh_token';

  // REST API Configuration
  static const String defaultApiBaseUrl = 'http://localhost:5000/api/v1';
  static const String androidDeviceApiBaseUrl = 'http://127.0.0.1:5000/api/v1';
  static const String androidEmulatorApiBaseUrl = 'http://10.0.2.2:5000/api/v1';
  static const String defaultIdirId = 'bc39b889-4e08-4543-bb9e-db42c17ed901';

  // Business defaults & security rules
  static const defaultClaimApprovalsRequired = 2;
  static const defaultMonthlyDues = 50.0; // ETB
  static const inactivityTimeoutSeconds = 120;
  static const maxPinAttempts = 5;

  // Roles
  static const roleChairperson = 'chairperson';
  static const roleTreasurer = 'treasurer';
  static const roleAuditor = 'auditor';
  static const roleMember = 'member';
}
