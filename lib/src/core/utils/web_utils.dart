import 'web_utils_stub.dart' if (dart.library.html) 'web_utils_web.dart';

void removeWebLoadingIndicator() => removeLoadingIndicator();

void downloadWebTextFile(
  String filename,
  String content, {
  String mimeType = 'text/plain;charset=utf-8',
}) => downloadTextFile(filename, content, mimeType: mimeType);

void downloadWebBytesFile(
  String filename,
  List<int> bytes, {
  String mimeType = 'application/octet-stream',
}) => downloadBytesFile(filename, bytes, mimeType: mimeType);
