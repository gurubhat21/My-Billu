import 'package:flutter/foundation.dart';
import 'package:local_auth/local_auth.dart';

Future<bool> isBiometricAvailable() async {
  try {
    // Only works on Android/iOS, not Windows
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    final auth = LocalAuthentication();
    final canCheck = await auth.canCheckBiometrics;
    final isSupported = await auth.isDeviceSupported();
    return canCheck && isSupported;
  } catch (_) {
    return false;
  }
}

Future<bool> authenticateWithBiometrics() async {
  try {
    if (defaultTargetPlatform != TargetPlatform.android &&
        defaultTargetPlatform != TargetPlatform.iOS) {
      return false;
    }
    final auth = LocalAuthentication();
    return await auth.authenticate(
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
