/// Platform-agnostic biometric helper
/// Web gets the stub (no biometric), native platforms get local_auth
export 'biometric_stub.dart'
    if (dart.library.html) 'biometric_stub.dart'
    if (dart.library.io) 'biometric_native.dart';
