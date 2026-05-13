/// Platform-agnostic web helper
/// Uses conditional import to load the correct implementation
export 'web_helper_stub.dart'
    if (dart.library.html) 'web_helper_web.dart';


