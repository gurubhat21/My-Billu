/// Biometric auth - always returns false (stub)
/// On Android, this is overridden by biometric_native.dart via conditional import
Future<bool> isBiometricAvailable() async => false;
Future<bool> authenticateWithBiometrics() async => false;
