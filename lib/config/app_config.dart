/// Global configuration flags for Sentinel360.
/// Set [testMode] to true during development/testing to prevent
/// real emergency calls, SMS, and external service invocations.
class AppConfig {
  static final AppConfig _instance = AppConfig._internal();
  factory AppConfig() => _instance;
  AppConfig._internal();

  /// When true, emergency calls and messages are simulated instead of real.
  /// Set to false for production deployment.
  bool testMode = true;

  /// When true, prints detailed debug info to console.
  bool verboseLogging = true;

  /// Test-mode phone numbers (not real emergency services)
  static const String testPoliceNumber = '0000000000';
  static const String testAmbulanceNumber = '0000000000';
  static const String testFireNumber = '0000000000';

  /// Real Ghana emergency numbers (used when testMode = false)
  static const String policeNumber = '191';
  static const String ambulanceNumber = '193';
  static const String fireNumber = '192';

  /// Get the appropriate phone number based on test mode
  String get police => testMode ? testPoliceNumber : policeNumber;
  String get ambulance => testMode ? testAmbulanceNumber : ambulanceNumber;
  String get fire => testMode ? testFireNumber : fireNumber;
}
