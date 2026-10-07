import 'package:flutter/material.dart';

/// Makes all text in the app selectable with the mouse.
///
/// Meant for `MaterialApp.builder`. That spot sits above the Navigator's
/// Overlay, and [SelectionArea] needs an Overlay ancestor for its toolbar and
/// handles, so this provides one.
class AppSelectionArea extends StatefulWidget {
  final Widget child;

  const AppSelectionArea({super.key, required this.child});

  @override
  State<AppSelectionArea> createState() => _AppSelectionAreaState();
}

class _AppSelectionAreaState extends State<AppSelectionArea> {
  // Created once: Overlay only reads initialEntries on first build.
  late final OverlayEntry _entry = OverlayEntry(
    builder: (_) => SelectionArea(child: widget.child),
  );

  @override
  void didUpdateWidget(AppSelectionArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    _entry.markNeedsBuild();
  }

  @override
  Widget build(BuildContext context) => Overlay(initialEntries: [_entry]);
}
