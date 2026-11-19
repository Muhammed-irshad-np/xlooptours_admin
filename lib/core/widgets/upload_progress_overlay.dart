import 'package:flutter/material.dart';

import '../utils/upload_progress.dart';

/// Floats a progress card at the top of the whole app (dialogs included)
/// while any file is uploading. Meant for `MaterialApp.builder`; it sits at
/// the top so it never covers snackbars.
class UploadProgressOverlay extends StatelessWidget {
  final Widget child;
  final UploadProgressTracker? tracker;

  const UploadProgressOverlay({super.key, required this.child, this.tracker});

  @override
  Widget build(BuildContext context) {
    final tracker = this.tracker ?? UploadProgressTracker.instance;
    return Stack(
      children: [
        child,
        Positioned(
          left: 16,
          right: 16,
          top: 12,
          child: SafeArea(
            bottom: false,
            child: IgnorePointer(
              child: ListenableBuilder(
                listenable: tracker,
                builder: (context, _) => AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: tracker.isUploading
                      ? _UploadProgressCard(tracker: tracker)
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _UploadProgressCard extends StatelessWidget {
  final UploadProgressTracker tracker;

  const _UploadProgressCard({required this.tracker});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final uploads = tracker.uploads;
    final fraction = tracker.overallFraction;
    final title = uploads.length == 1
        ? 'Uploading ${uploads.first.label}…'
        : 'Uploading ${uploads.length} files…';
    final percent = fraction == null ? '' : '${(fraction * 100).round()}%';

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Material(
          elevation: 6,
          borderRadius: BorderRadius.circular(12),
          color: theme.colorScheme.surface,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.cloud_upload_outlined,
                      size: 20,
                      color: theme.colorScheme.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      percent,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction,
                    minHeight: 6,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
