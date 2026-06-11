import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

class SearchableDropdown<T> extends FormField<T> {
  final List<T> items;
  final T? value;
  final String labelText;
  final String searchHint;
  final String Function(T) itemToString;
  final ValueChanged<T?> onChanged;
  final Widget Function(BuildContext, T)? itemWidgetBuilder;

  SearchableDropdown({
    super.key,
    required this.items,
    this.value,
    required this.labelText,
    this.searchHint = 'Search…',
    required this.itemToString,
    required this.onChanged,
    this.itemWidgetBuilder,
    super.validator,
  }) : super(
          initialValue: value,
          builder: (FormFieldState<T> state) {
            final context = state.context;
            final hasError = state.hasError;
            final displayValue = state.value != null ? itemToString(state.value as T) : '';

            return GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (context) {
                    return _SearchDialog<T>(
                      title: labelText,
                      searchHint: searchHint,
                      items: items,
                      itemToString: itemToString,
                      itemWidgetBuilder: itemWidgetBuilder,
                      selectedValue: state.value,
                    );
                  },
                ).then((selected) {
                  if (selected != null) {
                    state.didChange(selected);
                    onChanged(selected);
                  }
                });
              },
              child: InputDecorator(
                decoration: InputDecoration(
                  labelText: labelText,
                  errorText: hasError ? state.errorText : null,
                  border: const OutlineInputBorder(),
                  suffixIcon: Icon(
                    Icons.arrow_drop_down,
                    color: const Color(0xFF64748B),
                    size: 24.sp,
                  ),
                  contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                ),
                isEmpty: state.value == null,
                child: Text(
                  displayValue,
                  style: GoogleFonts.inter(
                    fontSize: 14.sp,
                    color: state.value == null ? const Color(0xFF94A3B8) : const Color(0xFF0F172A),
                    fontWeight: state.value == null ? FontWeight.w400 : FontWeight.w500,
                  ),
                ),
              ),
            );
          },
        );
}

class _SearchDialog<T> extends StatefulWidget {
  final String title;
  final String searchHint;
  final List<T> items;
  final String Function(T) itemToString;
  final Widget Function(BuildContext, T)? itemWidgetBuilder;
  final T? selectedValue;

  const _SearchDialog({
    required this.title,
    required this.searchHint,
    required this.items,
    required this.itemToString,
    this.itemWidgetBuilder,
    this.selectedValue,
  });

  @override
  State<_SearchDialog<T>> createState() => _SearchDialogState<T>();
}

class _SearchDialogState<T> extends State<_SearchDialog<T>> {
  final TextEditingController _searchController = TextEditingController();
  List<T> _filteredItems = [];
  String _query = '';

  @override
  void initState() {
    super.initState();
    _filteredItems = List.from(widget.items);
    _searchController.addListener(_filterList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _filterList() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      _query = query;
      if (query.isEmpty) {
        _filteredItems = List.from(widget.items);
      } else {
        _filteredItems = widget.items.where((item) {
          final str = widget.itemToString(item).toLowerCase();
          return str.contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16.r),
      ),
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  widget.title,
                  style: GoogleFonts.inter(
                    fontSize: 18.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0F172A),
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
              style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF0F172A)),
              decoration: InputDecoration(
                hintText: widget.searchHint,
                hintStyle: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF94A3B8)),
                prefixIcon: Icon(Icons.search, size: 20.sp, color: const Color(0xFF64748B)),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear, size: 18.sp, color: const Color(0xFF64748B)),
                        tooltip: 'Clear search',
                        onPressed: () => _searchController.clear(),
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
            Expanded(
              child: _filteredItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
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
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredItems.length,
                      itemBuilder: (context, index) {
                        final item = _filteredItems[index];
                        final isSelected = widget.selectedValue == item;
                        final displayString = widget.itemToString(item);

                        return Container(
                          margin: EdgeInsets.only(bottom: 4.h),
                          decoration: BoxDecoration(
                            color: isSelected ? const Color(0xFFECFDF5) : Colors.transparent,
                            borderRadius: BorderRadius.circular(8.r),
                          ),
                          child: InkWell(
                            onTap: () => Navigator.pop(context, item),
                            borderRadius: BorderRadius.circular(8.r),
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: widget.itemWidgetBuilder != null
                                        ? widget.itemWidgetBuilder!(context, item)
                                        : Text(
                                            displayString,
                                            style: GoogleFonts.inter(
                                              fontSize: 14.sp,
                                              color: isSelected
                                                  ? const Color(0xFF059669)
                                                  : const Color(0xFF334155),
                                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                            ),
                                          ),
                                  ),
                                  if (isSelected)
                                    Icon(
                                      Icons.check_circle,
                                      color: const Color(0xFF059669),
                                      size: 18.sp,
                                    ),
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
