import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';

class ShareDialog extends StatelessWidget {
  final String url;
  final String title;
  final String? recipientPhone;
  final String? recipientEmail;
  final String? recipientName;
  final String? shareMessage;

  const ShareDialog({
    super.key,
    required this.url,
    required this.title,
    this.recipientPhone,
    this.recipientEmail,
    this.recipientName,
    this.shareMessage,
  });

  Future<void> _launchUrl(String urlString) async {
    final Uri uri = Uri.parse(urlString);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  String get _resolvedUrl {
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return url;
    }
    final baseUri = Uri.base;
    String origin;
    if (baseUri.scheme == 'http' || baseUri.scheme == 'https') {
      origin =
          '${baseUri.scheme}://${baseUri.host}${baseUri.hasPort ? ":${baseUri.port}" : ""}';
    } else {
      origin = 'https://app.xlooptours.com';
    }
    final cleanPath = url.startsWith('/') ? url : '/$url';
    return '$origin$cleanPath';
  }

  void _shareToWhatsApp() {
    final fullUrl = _resolvedUrl;
    String messageText;
    if (shareMessage != null) {
      messageText = shareMessage!.contains(url) && url != fullUrl
          ? shareMessage!.replaceAll(url, fullUrl)
          : shareMessage!;
    } else {
      messageText = 'Check out this link: $title\n$fullUrl';
    }

    String cleanPhone = '';
    if (recipientPhone != null && recipientPhone!.isNotEmpty) {
      String phone = recipientPhone!.replaceAll(RegExp(r'[^0-9]'), '');
      if (phone.startsWith('0')) {
        phone = phone.substring(1);
      }
      // If no country code, default to KSA '966'
      if (phone.length <= 9) {
        cleanPhone = '966$phone';
      } else {
        cleanPhone = phone;
      }
    }

    final whatsappUrl =
        'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(messageText)}';
    _launchUrl(whatsappUrl);
  }

  void _shareViaEmail() {
    final fullUrl = _resolvedUrl;
    final subject = Uri.encodeComponent(title);
    String rawBody;
    if (shareMessage != null) {
      rawBody = shareMessage!.contains(url) && url != fullUrl
          ? shareMessage!.replaceAll(url, fullUrl)
          : shareMessage!;
    } else {
      rawBody = 'Hi,\n\nPlease find the link below:\n\n$title\n$fullUrl';
    }
    final body = Uri.encodeComponent(rawBody);
    final email = recipientEmail ?? '';
    final emailUrl = 'mailto:$email?subject=$subject&body=$body';
    _launchUrl(emailUrl);
  }

  void _copyToClipboard(BuildContext context) {
    Clipboard.setData(ClipboardData(text: _resolvedUrl));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Link copied to clipboard!'),
        backgroundColor: Color(0xFF13b1f2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const brandColor = Color(0xFF13b1f2);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        padding: EdgeInsets.all(24.w),
        width: 400.w,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Share Link',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: brandColor,
                    fontSize: 20.sp,
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  tooltip: 'Close share dialog',
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              title,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: Colors.grey[600],
                fontSize: 14.sp,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            if (recipientName != null) ...[
              SizedBox(height: 6.h),
              Text(
                'Recipient: $recipientName',
                style: TextStyle(
                  fontSize: 13.sp,
                  color: Colors.grey[500],
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
            SizedBox(height: 12.h),
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(8.r),
                border: Border.all(color: Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      _resolvedUrl,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[800],
                        fontFamily: 'monospace',
                      ),
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: 8.w),
                  InkWell(
                    onTap: () => _copyToClipboard(context),
                    borderRadius: BorderRadius.circular(4.r),
                    child: Padding(
                      padding: EdgeInsets.all(4.w),
                      child: Icon(
                        Icons.copy_rounded,
                        size: 18.w,
                        color: brandColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 24.h),
            _buildShareOption(
              context,
              icon: Icons.chat_bubble_outline,
              label: 'Share to WhatsApp',
              onTap: _shareToWhatsApp,
              color: const Color(0xFF25D366),
            ),
            SizedBox(height: 12.h),
            _buildShareOption(
              context,
              icon: Icons.email_outlined,
              label: 'Share via Email',
              onTap: _shareViaEmail,
              color: Colors.redAccent,
            ),
            SizedBox(height: 12.h),
            _buildShareOption(
              context,
              icon: Icons.link,
              label: 'Copy Link',
              onTap: () {
                _copyToClipboard(context);
                Navigator.pop(context);
              },
              color: brandColor,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildShareOption(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 16.w),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[200]!),
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 22.w),
            ),
            SizedBox(width: 16.w),
            Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    fontSize: 14.sp,
                  ),
            ),
            const Spacer(),
            Icon(Icons.chevron_right, color: Colors.grey[400]),
          ],
        ),
      ),
    );
  }
}
