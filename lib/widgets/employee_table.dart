import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/widgets/action_items_dialog.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/notifications/presentation/providers/notification_provider.dart';
import 'web_safe_image.dart';

/// Paginated employee list: a table on wide screens, compact rows on phones.
/// Tapping an employee's name opens their details.
class EmployeeTable extends StatefulWidget {
  final List<EmployeeEntity> employees;

  /// Changes whenever the search/filters change, so the table goes back to
  /// the first page. Reloads with the same filters keep the current page.
  final Object filterKey;
  final bool canDelete;
  final ValueChanged<EmployeeEntity> onOpen;
  final ValueChanged<EmployeeEntity> onEdit;
  final ValueChanged<EmployeeEntity> onDelete;
  final void Function(EmployeeEntity employee, bool isActive) onToggleStatus;

  const EmployeeTable({
    super.key,
    required this.employees,
    required this.filterKey,
    required this.canDelete,
    required this.onOpen,
    required this.onEdit,
    required this.onDelete,
    required this.onToggleStatus,
  });

  @override
  State<EmployeeTable> createState() => _EmployeeTableState();
}

class _EmployeeTableState extends State<EmployeeTable> {
  static const List<int> _pageSizes = [10, 20, 50];
  static const double _actionsWidth = 96;

  /// Below this width the Email column is dropped to make room for the
  /// Iqama and visa columns.
  static const double _emailMinWidth = 1250;

  int _page = 0;
  int _rowsPerPage = 20;
  bool _sortAscending = true;

  int get _pageCount =>
      math.max(1, (widget.employees.length / _rowsPerPage).ceil());

  @override
  void didUpdateWidget(EmployeeTable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.filterKey != oldWidget.filterKey) {
      _page = 0;
    } else if (_page >= _pageCount) {
      _page = _pageCount - 1;
    }
  }

  List<EmployeeEntity> get _pageEmployees {
    final sorted = List<EmployeeEntity>.from(widget.employees)
      ..sort((a, b) {
        final cmp = a.fullName.toLowerCase().compareTo(
          b.fullName.toLowerCase(),
        );
        return _sortAscending ? cmp : -cmp;
      });
    final start = _page * _rowsPerPage;
    final end = math.min(start + _rowsPerPage, sorted.length);
    return sorted.sublist(start, end);
  }

  @override
  Widget build(BuildContext context) {
    final rows = _pageEmployees;
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 800;
        final showEmail = constraints.maxWidth >= _emailMinWidth;
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              if (isWide) ...[
                _buildHeader(showEmail),
                Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
              ],
              Expanded(
                child: ListView.separated(
                  itemCount: rows.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    color: Colors.grey.withValues(alpha: 0.15),
                  ),
                  itemBuilder: (context, index) => isWide
                      ? _buildWideRow(rows[index], showEmail)
                      : _buildCompactRow(rows[index]),
                ),
              ),
              Divider(height: 1, color: Colors.grey.withValues(alpha: 0.2)),
              _buildFooter(isWide),
            ],
          ),
        );
      },
    );
  }

  /// A table column; header and rows share the same flex so they line up.
  Widget _cell(int flex, Widget child) {
    return Expanded(
      flex: flex,
      child: Padding(padding: const EdgeInsets.only(right: 12), child: child),
    );
  }

  Widget _buildHeader(bool showEmail) {
    final style = TextStyle(
      fontSize: 12.sp,
      fontWeight: FontWeight.w600,
      color: Colors.grey[700],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          _cell(
            4,
            Align(
              alignment: Alignment.centerLeft,
              child: InkWell(
                borderRadius: BorderRadius.circular(4),
                onTap: () => setState(() => _sortAscending = !_sortAscending),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Name', style: style),
                    const SizedBox(width: 4),
                    Icon(
                      _sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 14.sp,
                      color: Colors.grey[700],
                    ),
                  ],
                ),
              ),
            ),
          ),
          _cell(3, Text('Role', style: style)),
          _cell(3, Text('Phone', style: style)),
          _cell(3, Text('Iqama No.', style: style)),
          _cell(3, Text('Iqama Expiry', style: style)),
          _cell(3, Text('Saudi Visa Expiry', style: style)),
          if (showEmail) _cell(4, Text('Email', style: style)),
          _cell(2, Text('Status', style: style)),
          const SizedBox(width: _actionsWidth),
        ],
      ),
    );
  }

  Widget _buildWideRow(EmployeeEntity employee, bool showEmail) {
    final cellStyle = TextStyle(fontSize: 12.sp, color: Colors.grey[800]);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          _cell(
            4,
            Row(
              children: [
                _buildAvatar(employee, 36),
                const SizedBox(width: 12),
                Flexible(
                  child: _NameLink(
                    name: employee.fullName,
                    onTap: () => widget.onOpen(employee),
                  ),
                ),
              ],
            ),
          ),
          _cell(3, _buildRoleCell(employee, cellStyle)),
          _cell(
            3,
            Text(
              _formatPhone(employee),
              style: cellStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _cell(
            3,
            Text(
              employee.iqama?.number ?? '—',
              style: cellStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          _cell(3, _buildExpiry(employee.iqama?.expiryDate, cellStyle)),
          _cell(3, _buildExpiry(employee.saudiVisa?.expiryDate, cellStyle)),
          if (showEmail)
            _cell(
              4,
              Text(
                employee.email.isEmpty ? '—' : employee.email,
                style: cellStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          _cell(2, _buildStatus(employee)),
          SizedBox(
            width: _actionsWidth,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _buildAlerts(employee),
                _buildMenu(employee),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactRow(EmployeeEntity employee) {
    final subtitle = [
      employee.position,
      if (employee.isExternal) employee.employmentType,
      _formatPhone(employee),
    ].where((s) => s.isNotEmpty).join(' · ');
    final iqama = employee.iqama;
    final visa = employee.saudiVisa;
    final documents = [
      if (iqama != null) 'Iqama ${iqama.number} · exp ${_formatDate(iqama.expiryDate)}',
      if (visa != null) 'Saudi visa exp ${_formatDate(visa.expiryDate)}',
    ].join(' · ');
    return InkWell(
      onTap: () => widget.onOpen(employee),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        child: Row(
          children: [
            _buildAvatar(employee, 40),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _NameLink(
                    name: employee.fullName,
                    onTap: () => widget.onOpen(employee),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 12.sp, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (documents.isNotEmpty)
                    Text(
                      documents,
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 4),
                  _buildStatus(employee),
                ],
              ),
            ),
            _buildAlerts(employee),
            _buildMenu(employee),
          ],
        ),
      ),
    );
  }

  Widget _buildRoleCell(EmployeeEntity employee, TextStyle style) {
    final vehicle = employee.externalVehicle;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Flexible(
              child: Text(
                employee.position,
                style: style,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (employee.isExternal) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.orange, width: 0.5),
                ),
                child: Text(
                  employee.employmentType,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
        if (vehicle != null && !vehicle.isEmpty)
          Text(
            vehicle.summary,
            style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
      ],
    );
  }

  Widget _buildAvatar(EmployeeEntity employee, double size) {
    final hasImage = employee.imageUrl != null && employee.imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.blue.withValues(alpha: 0.1),
        shape: BoxShape.circle,
      ),
      child: ClipOval(
        child: hasImage
            ? WebSafeImage(
                imageUrl: employee.imageUrl!,
                fit: BoxFit.cover,
                width: size,
                height: size,
                errorWidget: _buildInitial(employee, size),
              )
            : _buildInitial(employee, size),
      ),
    );
  }

  Widget _buildInitial(EmployeeEntity employee, double size) {
    return Center(
      child: Text(
        employee.fullName.isNotEmpty
            ? employee.fullName[0].toUpperCase()
            : '?',
        style: TextStyle(
          fontSize: size * 0.4,
          color: Colors.blue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  /// Expiry date; red once expired, orange within 30 days.
  Widget _buildExpiry(DateTime? date, TextStyle style) {
    if (date == null) return Text('—', style: style);
    final daysLeft = date.difference(DateTime.now()).inDays;
    final color = date.isBefore(DateTime.now())
        ? Colors.red[700]
        : daysLeft <= 30
        ? Colors.orange[800]
        : style.color;
    return Text(
      _formatDate(date),
      style: style.copyWith(
        color: color,
        fontWeight: color == style.color ? null : FontWeight.w600,
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildStatus(EmployeeEntity employee) {
    final color = employee.isActive ? Colors.green[700]! : Colors.grey;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            employee.isActive ? 'Active' : 'Inactive',
            style: TextStyle(
              fontSize: 12.sp,
              color: color,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  Widget _buildAlerts(EmployeeEntity employee) {
    return Consumer<NotificationProvider>(
      builder: (context, provider, _) {
        final alerts = provider.getNotificationsByRelatedId(employee.id);
        if (alerts.isEmpty) return const SizedBox.shrink();

        return IconButton(
          onPressed: () =>
              ActionItemsDialog.show(context, employee.fullName, employee.id),
          icon: Badge(
            label: Text(
              alerts.length.toString(),
              style: TextStyle(fontSize: 10.sp, color: Colors.white),
            ),
            backgroundColor: Colors.red,
            child: Icon(
              Icons.warning_amber_rounded,
              color: Colors.red,
              size: 22.sp,
            ),
          ),
          tooltip: 'Action Items',
        );
      },
    );
  }

  Widget _buildMenu(EmployeeEntity employee) {
    return PopupMenuButton<String>(
      tooltip: 'More actions',
      onSelected: (value) {
        switch (value) {
          case 'view':
            widget.onOpen(employee);
          case 'edit':
            widget.onEdit(employee);
          case 'status':
            widget.onToggleStatus(employee, !employee.isActive);
          case 'delete':
            widget.onDelete(employee);
        }
      },
      itemBuilder: (context) => [
        const PopupMenuItem(
          value: 'view',
          child: Row(
            children: [
              Icon(Icons.remove_red_eye, size: 20, color: Colors.blue),
              SizedBox(width: 8),
              Text('View Details'),
            ],
          ),
        ),
        const PopupMenuItem(
          value: 'edit',
          child: Row(
            children: [
              Icon(Icons.edit, size: 20),
              SizedBox(width: 8),
              Text('Edit'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'status',
          child: Row(
            children: [
              Icon(
                employee.isActive
                    ? Icons.toggle_off_outlined
                    : Icons.toggle_on_outlined,
                size: 20,
                color: employee.isActive ? Colors.grey : Colors.green,
              ),
              const SizedBox(width: 8),
              Text(employee.isActive ? 'Mark Inactive' : 'Mark Active'),
            ],
          ),
        ),
        if (widget.canDelete)
          const PopupMenuItem(
            value: 'delete',
            child: Row(
              children: [
                Icon(Icons.delete, size: 20, color: Colors.red),
                SizedBox(width: 8),
                Text('Delete', style: TextStyle(color: Colors.red)),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFooter(bool isWide) {
    final total = widget.employees.length;
    final start = total == 0 ? 0 : _page * _rowsPerPage + 1;
    final end = math.min((_page + 1) * _rowsPerPage, total);
    final textStyle = TextStyle(fontSize: 12.sp, color: Colors.grey[700]);

    final pageSize = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('Rows per page', style: textStyle),
        const SizedBox(width: 8),
        DropdownButton<int>(
          value: _rowsPerPage,
          isDense: true,
          underline: const SizedBox.shrink(),
          style: textStyle.copyWith(fontWeight: FontWeight.w600),
          items: _pageSizes
              .map((n) => DropdownMenuItem(value: n, child: Text('$n')))
              .toList(),
          onChanged: (n) {
            if (n == null) return;
            setState(() {
              _rowsPerPage = n;
              _page = 0;
            });
          },
        ),
      ],
    );

    final pager = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text('$start–$end of $total', style: textStyle),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.chevron_left),
          tooltip: 'Previous page',
          visualDensity: VisualDensity.compact,
          onPressed: _page > 0 ? () => setState(() => _page--) : null,
        ),
        Text('${_page + 1} / $_pageCount', style: textStyle),
        IconButton(
          icon: const Icon(Icons.chevron_right),
          tooltip: 'Next page',
          visualDensity: VisualDensity.compact,
          onPressed: _page < _pageCount - 1
              ? () => setState(() => _page++)
              : null,
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: isWide
          ? Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [pageSize, const SizedBox(width: 24), pager],
            )
          : Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [pageSize, pager],
            ),
    );
  }

  String _formatDate(DateTime date) => DateFormat('MMM dd, yyyy').format(date);

  String _formatPhone(EmployeeEntity employee) {
    if (employee.phoneNumber.isEmpty) return '';
    return '${employee.countryCode ?? '+966'} ${employee.phoneNumber}';
  }
}

/// Employee name styled as a link; underlines on hover.
class _NameLink extends StatefulWidget {
  final String name;
  final VoidCallback onTap;

  const _NameLink({required this.name, required this.onTap});

  @override
  State<_NameLink> createState() => _NameLinkState();
}

class _NameLinkState extends State<_NameLink> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final color = Colors.blue[800];
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: Text(
          widget.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13.sp,
            fontWeight: FontWeight.w600,
            color: color,
            decoration: _hovered
                ? TextDecoration.underline
                : TextDecoration.none,
            decorationColor: color,
          ),
        ),
      ),
    );
  }
}
