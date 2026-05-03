// Conditional import: uses web implementation on web, stub on other platforms
export 'web_utils_stub.dart'
    if (dart.library.js) 'web_utils_web.dart';
