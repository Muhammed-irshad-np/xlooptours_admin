import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

Widget buildWebImage({
  required String imageUrl,
  required BoxFit fit,
  Widget? errorWidget,
}) {
  return const SizedBox.shrink();
}

Widget buildNativeImage({
  required String imageUrl,
  required BoxFit fit,
  double? width,
  double? height,
  Widget? placeholder,
  Widget? errorWidget,
}) {
  return CachedNetworkImage(
    imageUrl: imageUrl,
    fit: fit,
    width: width,
    height: height,
    placeholder: placeholder != null ? (_, __) => placeholder : null,
    errorWidget: errorWidget != null ? (_, __, ___) => errorWidget : null,
  );
}
