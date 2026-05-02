import 'package:flutter/material.dart';

/// Stub implementation for non-web platforms.
/// This should never be called on native — SfPdfViewer.network is used instead.
Widget buildPdfWebView(String url) {
  return const Center(
    child: Text('PDF viewer not available on this platform.'),
  );
}
