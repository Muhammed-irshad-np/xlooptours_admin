import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

/// Web implementation: renders a PDF inside the browser's native PDF viewer
/// via an iframe. This completely bypasses CORS and binary data issues.
Widget buildPdfWebView(String url) {
  final viewId = 'pdf-viewer-${url.hashCode}';

  // Register the iframe platform view
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    // Use Google Docs Viewer to render the PDF inline.
    // Direct Firebase URLs trigger a download due to content-disposition headers.
    final encodedUrl = Uri.encodeComponent(url);
    final viewerUrl =
        'https://docs.google.com/viewer?url=$encodedUrl&embedded=true';

    final iframe = html.IFrameElement()
      ..src = viewerUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('allowfullscreen', 'true');
    return iframe;
  });

  return HtmlElementView(viewType: viewId);
}

/// Web implementation: renders office documents (doc, docx, xlsx, etc.)
/// using Google Docs Viewer inside an iframe.
Widget buildDocWebView(String url) {
  final viewId = 'doc-viewer-${url.hashCode}';

  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final encodedUrl = Uri.encodeComponent(url);
    final viewerUrl =
        'https://docs.google.com/gview?embedded=true&url=$encodedUrl';

    final iframe = html.IFrameElement()
      ..src = viewerUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..setAttribute('allowfullscreen', 'true');
    return iframe;
  });

  return HtmlElementView(viewType: viewId);
}
