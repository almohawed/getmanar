// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html';

void removeLoadingIndicator() {
  document.getElementById('loading_indicator')?.remove();
}

void reloadPage() {
  window.location.reload();
}
