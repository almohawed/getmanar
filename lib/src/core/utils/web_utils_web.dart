// Web implementation using dart:js_interop
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

void evalJavaScript(String code) {
  js.context.callMethod('eval', [code]);
}
