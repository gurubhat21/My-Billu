/// Platform-agnostic biometric helper
/// Uses conditional import to load native or stub
export 'biometric_stub.dart'
    if (dart.library.io) 'biometric_native.dart';
