/// Platform-agnostic biometric helper
/// Web gets stub (no biometric hardware)
/// Native (Android/Windows) gets local_auth implementation
/// On Windows, local_auth compiles but returns false (no biometric hardware)
/// On Android, local_auth uses fingerprint/face
export 'biometric_stub.dart'
    if (dart.library.html) 'biometric_stub.dart'
    if (dart.library.io) 'biometric_native.dart';
