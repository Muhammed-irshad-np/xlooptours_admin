import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

/// Dropdowns with at least this many items open a searchable picker instead
/// of the plain Material menu. See rules.md ("Dropdowns").
const int kSearchableDropdownThreshold = 4;

/// Drop-in replacement for [DropdownButtonFormField].
///
/// The closed field is the real [DropdownButtonFormField], so decoration,
/// hint, validation and error text look exactly as before. When the list has
/// [kSearchableDropdownThreshold] or more items, tapping it opens a search
/// dialog instead of the Material menu. Set [searchable] to force either way.
class AppDropdownFormField<T> extends StatefulWidget {
  const AppDropdownFormField({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.initialValue,
    this.selectedItemBuilder,
    this.hint,
    this.disabledHint,
    this.onTap,
    this.elevation = 8,
    this.style,
    this.icon,
    this.iconDisabledColor,
    this.iconEnabledColor,
    this.iconSize = 24.0,
    this.isDense = true,
    this.isExpanded = false,
    this.itemHeight,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.dropdownColor,
    this.decoration,
    this.onSaved,
    this.validator,
    this.autovalidateMode,
    this.menuMaxHeight,
    this.alignment = AlignmentDirectional.centerStart,
    this.borderRadius,
    this.padding,
    this.searchable,
    this.searchTitle,
    this.searchHint = 'Search…',
  });

  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;

  /// Same as [initialValue]; kept so existing `value:` call sites still work.
  final T? value;
  final T? initialValue;
  final DropdownButtonBuilder? selectedItemBuilder;
  final Widget? hint;
  final Widget? disabledHint;
  final VoidCallback? onTap;
  final int elevation;
  final TextStyle? style;
  final Widget? icon;
  final Color? iconDisabledColor;
  final Color? iconEnabledColor;
  final double iconSize;
  final bool isDense;
  final bool isExpanded;
  final double? itemHeight;
  final Color? focusColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? dropdownColor;
  final InputDecoration? decoration;
  final FormFieldSetter<T>? onSaved;
  final FormFieldValidator<T>? validator;
  final AutovalidateMode? autovalidateMode;
  final double? menuMaxHeight;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;

  /// Null = automatic (searchable when items >= [kSearchableDropdownThreshold]).
  final bool? searchable;

  /// Search dialog title. Defaults to the decoration's label or hint.
  final String? searchTitle;
  final String searchHint;

  @override
  State<AppDropdownFormField<T>> createState() => _AppDropdownFormFieldState<T>();
}

class _AppDropdownFormFieldState<T> extends State<AppDropdownFormField<T>> {
  final GlobalKey<FormFieldState<T>> _fieldKey = GlobalKey<FormFieldState<T>>();

  Future<void> _openSearch() async {
    widget.onTap?.call();
    final field = _fieldKey.currentState;
    final picked = await showSearchableDropdownDialog<T>(
      context: context,
      items: widget.items!,
      selectedValue: field?.value,
      title: widget.searchTitle ??
          widget.decoration?.labelText ??
          widget.decoration?.hintText ??
          _textOf(widget.hint),
      searchHint: widget.searchHint,
    );
    if (picked == null || !mounted) return;
    picked.item.onTap?.call();
    // didChange updates the form field and calls onChanged.
    _fieldKey.currentState?.didChange(picked.item.value);
  }

  @override
  Widget build(BuildContext context) {
    final field = DropdownButtonFormField<T>(
      key: _fieldKey,
      items: widget.items,
      onChanged: widget.onChanged,
      initialValue: widget.initialValue ?? widget.value,
      selectedItemBuilder: widget.selectedItemBuilder,
      hint: widget.hint,
      disabledHint: widget.disabledHint,
      onTap: widget.onTap,
      elevation: widget.elevation,
      style: widget.style,
      icon: widget.icon,
      iconDisabledColor: widget.iconDisabledColor,
      iconEnabledColor: widget.iconEnabledColor,
      iconSize: widget.iconSize,
      isDense: widget.isDense,
      isExpanded: widget.isExpanded,
      itemHeight: widget.itemHeight,
      focusColor: widget.focusColor,
      focusNode: widget.focusNode,
      autofocus: widget.autofocus,
      dropdownColor: widget.dropdownColor,
      decoration: widget.decoration,
      onSaved: widget.onSaved,
      validator: widget.validator,
      autovalidateMode: widget.autovalidateMode,
      menuMaxHeight: widget.menuMaxHeight,
      alignment: widget.alignment,
      borderRadius: widget.borderRadius,
      padding: widget.padding,
    );

    final enabled = widget.onChanged != null && (widget.items?.isNotEmpty ?? false);
    if (!enabled || !_useSearch(widget.searchable, widget.items)) return field;
    return _SearchTapOverlay(
      onTap: _openSearch,
      // Leave a decoration suffix (e.g. a "quick add" IconButton) clickable.
      endInset: widget.decoration?.suffixIcon != null ? 48 : 0,
      child: field,
    );
  }
}

/// Drop-in replacement for [DropdownButton] (the non-form variant used for
/// filters and toolbars). Same search behaviour as [AppDropdownFormField].
class AppDropdownButton<T> extends StatelessWidget {
  const AppDropdownButton({
    super.key,
    required this.items,
    required this.onChanged,
    this.value,
    this.selectedItemBuilder,
    this.hint,
    this.disabledHint,
    this.onTap,
    this.elevation = 8,
    this.style,
    this.underline,
    this.icon,
    this.iconDisabledColor,
    this.iconEnabledColor,
    this.iconSize = 24.0,
    this.isDense = false,
    this.isExpanded = false,
    this.itemHeight = kMinInteractiveDimension,
    this.focusColor,
    this.focusNode,
    this.autofocus = false,
    this.dropdownColor,
    this.menuMaxHeight,
    this.alignment = AlignmentDirectional.centerStart,
    this.borderRadius,
    this.padding,
    this.searchable,
    this.searchTitle,
    this.searchHint = 'Search…',
  });

  final List<DropdownMenuItem<T>>? items;
  final ValueChanged<T?>? onChanged;
  final T? value;
  final DropdownButtonBuilder? selectedItemBuilder;
  final Widget? hint;
  final Widget? disabledHint;
  final VoidCallback? onTap;
  final int elevation;
  final TextStyle? style;
  final Widget? underline;
  final Widget? icon;
  final Color? iconDisabledColor;
  final Color? iconEnabledColor;
  final double iconSize;
  final bool isDense;
  final bool isExpanded;
  final double? itemHeight;
  final Color? focusColor;
  final FocusNode? focusNode;
  final bool autofocus;
  final Color? dropdownColor;
  final double? menuMaxHeight;
  final AlignmentGeometry alignment;
  final BorderRadius? borderRadius;
  final EdgeInsetsGeometry? padding;
  final bool? searchable;
  final String? searchTitle;
  final String searchHint;

  @override
  Widget build(BuildContext context) {
    final button = DropdownButton<T>(
      items: items,
      onChanged: onChanged,
      value: value,
      selectedItemBuilder: selectedItemBuilder,
      hint: hint,
      disabledHint: disabledHint,
      onTap: onTap,
      elevation: elevation,
      style: style,
      underline: underline,
      icon: icon,
      iconDisabledColor: iconDisabledColor,
      iconEnabledColor: iconEnabledColor,
      iconSize: iconSize,
      isDense: isDense,
      isExpanded: isExpanded,
      itemHeight: itemHeight,
      focusColor: focusColor,
      focusNode: focusNode,
      autofocus: autofocus,
      dropdownColor: dropdownColor,
      menuMaxHeight: menuMaxHeight,
      alignment: alignment,
      borderRadius: borderRadius,
      padding: padding,
    );

    final enabled = onChanged != null && (items?.isNotEmpty ?? false);
    if (!enabled || !_useSearch(searchable, items)) return button;

    return _SearchTapOverlay(
      onTap: () async {
        onTap?.call();
        final picked = await showSearchableDropdownDialog<T>(
          context: context,
          items: items!,
          selectedValue: value,
          title: searchTitle ?? _textOf(hint),
          searchHint: searchHint,
        );
        if (picked == null) return;
        picked.item.onTap?.call();
        onChanged?.call(picked.item.value);
      },
      child: button,
    );
  }
}

/// The item the user picked. Wrapped so a `null`-valued item (e.g. "All")
/// can be told apart from closing the dialog.
class SearchableDropdownPick<T> {
  const SearchableDropdownPick(this.item);
  final DropdownMenuItem<T> item;
}

/// Opens the search dialog over [items]. Returns null when dismissed.
Future<SearchableDropdownPick<T>?> showSearchableDropdownDialog<T>({
  required BuildContext context,
  required List<DropdownMenuItem<T>> items,
  T? selectedValue,
  String? title,
  String searchHint = 'Search…',
}) {
  return showDialog<SearchableDropdownPick<T>>(
    context: context,
    builder: (_) => _SearchDialog<T>(
      title: (title == null || title.trim().isEmpty) ? 'Select' : title,
      searchHint: searchHint,
      items: items,
      selectedValue: selectedValue,
    ),
  );
}

bool _useSearch<T>(bool? searchable, List<DropdownMenuItem<T>>? items) =>
    searchable ?? (items?.length ?? 0) >= kSearchableDropdownThreshold;

/// Sits over the real dropdown so taps open the search dialog instead of the
/// Material menu, while the dropdown still draws itself.
class _SearchTapOverlay extends StatelessWidget {
  const _SearchTapOverlay({required this.onTap, required this.child, this.endInset = 0});

  final VoidCallback onTap;
  final Widget child;

  /// Width left uncovered at the trailing edge.
  final double endInset;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.passthrough,
      children: [
        child,
        PositionedDirectional(
          top: 0,
          bottom: 0,
          start: 0,
          end: endInset,
          child: MouseRegion(
            cursor: SystemMouseCursors.click,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
            ),
          ),
        ),
      ],
    );
  }
}

/// Plain text shown by a dropdown item, used for searching. Walks the common
/// layout wrappers (Row, Padding, Expanded, Container, ...) collecting Text.
String _textOf(Widget? widget) {
  if (widget == null) return '';
  final parts = <String>[];
  void visit(Widget? w) {
    if (w == null) return;
    if (w is Text) {
      final s = w.data ?? w.textSpan?.toPlainText() ?? '';
      if (s.isNotEmpty) parts.add(s);
    } else if (w is RichText) {
      parts.add(w.text.toPlainText());
    } else if (w is MultiChildRenderObjectWidget) {
      w.children.forEach(visit);
    } else if (w is SingleChildRenderObjectWidget) {
      visit(w.child);
    } else if (w is ProxyWidget) {
      visit(w.child);
    } else if (w is Container) {
      visit(w.child);
    } else if (w is Tooltip) {
      visit(w.child);
    }
  }

  visit(widget);
  return parts.join(' ').trim();
}

String _searchTextOf<T>(DropdownMenuItem<T> item) {
  final text = _textOf(item.child);
  return text.isNotEmpty ? text : (item.value?.toString() ?? '');
}

class _SearchDialog<T> extends StatefulWidget {
  const _SearchDialog({
    required this.title,
    required this.searchHint,
    required this.items,
    this.selectedValue,
  });

  final String title;
  final String searchHint;
  final List<DropdownMenuItem<T>> items;
  final T? selectedValue;

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  late final List<String> _searchTexts =
      widget.items.map((i) => _searchTextOf(i).toLowerCase()).toList();
  late List<int> _visible = List.generate(widget.items.length, (i) => i);
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onQueryChanged(String raw) {
    final query = raw.trim().toLowerCase();
    setState(() {
      _query = query;
      _visible = [
        for (var i = 0; i < widget.items.length; i++)
          if (query.isEmpty || _searchTexts[i].contains(query)) i,
      ];
    });
  }

  void _pick(DropdownMenuItem<T> item) {
    if (!item.enabled) return;
    Navigator.pop(context, SearchableDropdownPick<T>(item));
  }

  /// Enter picks the first enabled match.
  void _onSubmitted(String _) {
    for (final i in _visible) {
      if (widget.items[i].enabled) {
        _pick(widget.items[i]);
        return;
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      elevation: 8,
      child: Container(
        width: 450.w,
        constraints: BoxConstraints(maxHeight: 550.h),
        padding: EdgeInsets.all(24.r),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.title,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                      color: const Color(0xFF0F172A),
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, size: 20.sp, color: const Color(0xFF64748B)),
                  tooltip: 'Close search',
                  onPressed: () => Navigator.pop(context),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            SizedBox(height: 16.h),
            TextField(
              controller: _searchController,
              autofocus: true,
              onChanged: _onQueryChanged,
              onSubmitted: _onSubmitted,
              style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.search, size: 20.sp, color: const Color(0xFF64748B)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18.sp, color: const Color(0xFF64748B)),
                        tooltip: 'Clear search',
                        onPressed: () {
                          _searchController.clear();
                          _onQueryChanged('');
                        },
                      )
                    : null,
                contentPadding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: Color(0xFFCBD5E1)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: Color(0xFFE2E8F0)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  borderSide: const BorderSide(color: Color(0xFF13B1F2), width: 1.5),
                ),
              ),
            ),
            SizedBox(height: 16.h),
            Flexible(
              child: _visible.isEmpty
                  ? Padding(
                      padding: EdgeInsets.symmetric(vertical: 32.h),
                      child: Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.search_off_outlined, size: 48.r, color: const Color(0xFF94A3B8)),
                            SizedBox(height: 12.h),
                            Text(
                              'No items match your search',
                              style: GoogleFonts.inter(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _visible.length,
                      itemBuilder: (context, index) {
                        final item = widget.items[_visible[index]];
                        final isSelected = item.enabled && item.value == widget.selectedValue;
                        return Container(
                          margin: EdgeInsets.only(bottom: 4.h),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFECFDF5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: InkWell(
                            onTap: item.enabled ? () => _pick(item) : null,
                            borderRadius: BorderRadius.circular(8.r),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Opacity(
                                      opacity: item.enabled ? 1 : 0.45,
                                      child: DefaultTextStyle.merge(
                                        style: GoogleFonts.inter(
                                          fontSize: 14.sp,
                                          color: isSelected
                                              ? const Color(0xFF059669)
                                              : const Color(0xFF334155),
                                          fontWeight:
                                              isSelected ? FontWeight.w600 : FontWeight.w400,
                                        ),
                                        child: item.child,
                                      ),
                                    ),
                                  ),
                                  if (isSelected)
                                    Icon(Icons.check_circle, color: const Color(0xFF059669), size: 18.sp),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
