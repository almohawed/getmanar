import 'reloader_stub.dart'
    if (dart.library.html) 'reloader_web.dart';

void reloadApp() => reloadPage();

void removeWebLoadingIndicator() => removeLoadingIndicator();
