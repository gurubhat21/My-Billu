import 'package:local_auth/local_auth.dart';

final _auth = LocalAuthentication();

Future<bool> isBiometricAvailable() async {
  try {
    final canCheck = await _auth.canCheckBiometrics;
    final isSupported = await _auth.isDeviceSupported();
    return canCheck && isSupported;
  } catch (_) {
    return false;
  }
}

Future<bool> authenticateWithBiometrics() async {
  try {
    return await _auth.authenticate(
      localizedReason: 'Scan your fingerprint to login to My Billu',
      options: const AuthenticationOptions(
        stickyAuth: true,
        biometricOnly: true,
      ),
    );
  } catch (_) {
    return false;
  }
}
