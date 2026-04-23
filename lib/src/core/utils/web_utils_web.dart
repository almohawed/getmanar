// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html';
import 'dart:typed_data';

void removeLoadingIndicator() {
  document.getElementById('loading_indicator')?.remove();
}

void downloadTextFile(
  String filename,
  String content, {
  String mimeType = 'text/plain;charset=utf-8',
}) {
  final blob = Blob([content], mimeType);
  final url = Url.createObjectUrlFromBlob(blob);
  final anchor = AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  Url.revokeObjectUrl(url);
}

void downloadBytesFile(
  String filename,
  List<int> bytes, {
  String mimeType = 'application/octet-stream',
}) {
  final blob = Blob([Uint8List.fromList(bytes)], mimeType);
  final url = Url.createObjectUrlFromBlob(blob);
  final anchor = AnchorElement(href: url)
    ..download = filename
    ..style.display = 'none';
  document.body?.children.add(anchor);
  anchor.click();
  anchor.remove();
  Url.revokeObjectUrl(url);
}
