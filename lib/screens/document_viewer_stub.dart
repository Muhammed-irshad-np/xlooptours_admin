import 'package:flutter/material.dart';

/// Stub implementation for non-web platforms.
/// This should never be called on native — SfPdfViewer.network is used instead.
Widget buildPdfWebView(String url) {
  return const Center(
    child: Text('PDF viewer not available on this platform.'),
  );
}

/// Stub implementation for non-web platforms.
/// On native, WebViewWidget with Google Docs Viewer is used instead.
Widget buildOfficeDocWebView(String url) {
  return const Center(
    child: Text('Office document viewer not available on this platform.'),
  );
}
