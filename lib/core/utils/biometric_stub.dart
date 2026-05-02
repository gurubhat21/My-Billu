/// Biometric auth stub for web - always returns false/unavailable
Future<bool> isBiometricAvailable() async => false;

Future<bool> authenticateWithBiometrics() async => false;
