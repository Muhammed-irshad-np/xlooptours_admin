import 'package:flutter/widgets.dart';

/// Validates [form] and, when any field fails, scrolls to the topmost failing
/// field and focuses it so the user lands on what still needs filling in.
///
/// Returns `true` when every field is valid.
bool validateAndRevealFirstError(FormState form) {
  final invalid = form.validateGranularly();
  if (invalid.isEmpty) return true;

  final first = _topmost(invalid);
  if (first != null) _reveal(first.context);
  return false;
}

/// Picks the field rendered highest on screen (then leftmost), since the
/// order fields register with the form doesn't always match the layout.
FormFieldState<Object?>? _topmost(Set<FormFieldState<Object?>> fields) {
  FormFieldState<Object?>? best;
  Offset? bestOffset;
  for (final field in fields) {
    if (!field.mounted) continue;
    final box = field.context.findRenderObject();
    if (box is! RenderBox || !box.attached) continue;
    final offset = box.localToGlobal(Offset.zero);
    if (bestOffset == null ||
        offset.dy < bestOffset.dy ||
        (offset.dy == bestOffset.dy && offset.dx < bestOffset.dx)) {
      best = field;
      bestOffset = offset;
    }
  }
  return best;
}

void _reveal(BuildContext fieldContext) {
  Scrollable.ensureVisible(
    fieldContext,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
    alignment: 0.2,
  );
  _firstFocusNode(fieldContext as Element)?.requestFocus();
}

/// Finds the first focusable node inside the field (the text input of a
/// TextFormField, the button of a DropdownButtonFormField, ...).
FocusNode? _firstFocusNode(Element root) {
  FocusNode? found;
  void visit(Element element) {
    if (found != null) return;
    if (element.widget is Focus) {
      element.visitChildElements((child) {
        found ??= Focus.maybeOf(child, scopeOk: true, createDependency: false);
      });
      if (found != null && !found!.canRequestFocus) found = null;
      if (found != null) return;
    }
    element.visitChildElements(visit);
  }

  root.visitChildElements(visit);
  return found;
}
