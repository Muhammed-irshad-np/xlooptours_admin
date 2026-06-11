import 'dart:html' as html;
import 'dart:ui_web' as ui_web;
import 'package:flutter/material.dart';

Widget buildWebImage({
  required String imageUrl,
  required BoxFit fit,
  Widget? errorWidget,
}) {
  final viewId = 'web-image-${imageUrl.hashCode}';

  // Map BoxFit to CSS object-fit properties
  String objectFit = 'cover';
  if (fit == BoxFit.contain) {
    objectFit = 'contain';
  } else if (fit == BoxFit.fill) {
    objectFit = 'fill';
  } else if (fit == BoxFit.fitWidth) {
    objectFit = 'contain';
  } else if (fit == BoxFit.none) {
    objectFit = 'none';
  }

  // Register the element
  // ignore: undefined_prefixed_name
  ui_web.platformViewRegistry.registerViewFactory(viewId, (int id) {
    final img = html.ImageElement()
      ..src = imageUrl
      ..style.border = 'none'
      ..style.width = '100%'
      ..style.height = '100%'
      ..style.objectFit = objectFit;
    return img;
  });

  return HtmlElementView(viewType: viewId);
}

Widget buildNativeImage({
  required String imageUrl,
  required BoxFit fit,
  double? width,
  double? height,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  return const SizedBox.shrink();
}
