import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import 'share_dialog.dart';

class ShareHelper {
  static void shareDocument(
    BuildContext context, {
    required String url,
    required String title,
  }) {
    if (kIsWeb) {
      showDialog(
        context: context,
        builder: (context) => ShareDialog(
          url: url,
          title: title,
        ),
      );
    } else {
      Share.share(
        'Check out this document: $title\n$url',
        subject: title,
      );
    }
  }
}
