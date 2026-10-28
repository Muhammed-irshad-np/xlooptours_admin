// ignore_for_file: avoid_web_libraries_in_flutter, deprecated_member_use
import 'dart:html' as html;

/// Reloads the browser tab so the latest deployed build is loaded.
void reloadPage() => html.window.location.reload();
