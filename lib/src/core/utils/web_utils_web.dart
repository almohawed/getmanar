// Web implementation using dart:js
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void evalJavaScript(String code) {
  js.context.callMethod('eval', [code]);
}

void downloadWebTextFile(String fileName, String content, {String? mimeType}) {
  final mime = mimeType ?? 'text/plain;charset=utf-8';
  final bytes = html.Blob([content], mime);
  final url = html.Url.createObjectUrlFromBlob(bytes);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}

void downloadWebBytesFile(String fileName, List<int> bytes, {String? mimeType}) {
  final mime = mimeType ?? 'application/octet-stream';
  final blob = html.Blob([bytes], mime);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final anchor = html.AnchorElement(href: url)
    ..setAttribute('download', fileName)
    ..click();
  html.Url.revokeObjectUrl(url);
}
