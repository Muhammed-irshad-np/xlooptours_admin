import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'web_safe_image_stub.dart'
    if (dart.library.html) 'web_safe_image_web.dart'
    as platform_impl;

class WebSafeImage extends StatelessWidget {
  final String imageUrl;
  final BoxFit fit;
  final double? width;
  final double? height;
  final Widget? placeholder;
  final Widget? errorWidget;

  const WebSafeImage({
    super.key,
    required this.imageUrl,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.placeholder,
    this.errorWidget,
  });

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return SizedBox(
        width: width,
        height: height,
        child: platform_impl.buildWebImage(
          imageUrl: imageUrl,
          fit: fit,
          errorWidget: errorWidget,
        ),
      );
    }

    return platform_impl.buildNativeImage(
      imageUrl: imageUrl,
      fit: fit,
      width: width,
      height: height,
      placeholder: placeholder,
      errorWidget: errorWidget,
    );
  }
}
