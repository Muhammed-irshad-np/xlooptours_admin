import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../features/company/presentation/providers/company_provider.dart';
import '../../../features/customer/presentation/providers/customer_provider.dart';
import '../../../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../../../features/invoice/presentation/providers/invoice_provider.dart';
import '../../../features/employee/presentation/providers/employee_provider.dart';
import 'search_result_model.dart';

class GlobalSearchPalette extends StatefulWidget {
  const GlobalSearchPalette({super.key});

  @override
  State<GlobalSearchPalette> createState() => _GlobalSearchPaletteState();
}

class _GlobalSearchPaletteState extends State<GlobalSearchPalette> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  
  List<SearchResult> _allResults = [];
  List<SearchResult> _filteredResults = [];
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _buildAllResults();
    _filteredResults = _allResults;
    _searchController.addListener(_onSearchChanged);
    
    // Auto focus the search field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _searchFocusNode.requestFocus();
    });
  }

  void _buildAllResults() {
    final companyProvider = context.read<CompanyProvider>();
    final customerProvider = context.read<CustomerProvider>();
    final vehicleProvider = context.read<VehicleProvider>();
    final invoiceProvider = context.read<InvoiceProvider>();
    final employeeProvider = context.read<EmployeeProvider>();

    List<SearchResult> results = [];

    // 1. Static Actions
    results.addAll([
      SearchResult(
        id: 'action_create_invoice',
        title: 'Create Invoice',
        subtitle: 'Quick Action',
        icon: Icons.add_circle_outline,
        iconColor: const Color(0xFF13B1F2),
        onTap: () {
          Navigator.of(context).pop();
          context.push('/invoice');
        },
      ),
      SearchResult(
        id: 'action_view_invoices',
        title: 'View Invoices',
        subtitle: 'Navigation',
        icon: Icons.receipt_long_outlined,
        onTap: () {
          Navigator.of(context).pop();
          context.push('/invoices');
        },
      ),
      SearchResult(
        id: 'action_view_analytics',
        title: 'View Analytics',
        subtitle: 'Navigation',
        icon: Icons.analytics_outlined,
        onTap: () {
          Navigator.of(context).pop();
          context.push('/analytics');
        },
      ),
      SearchResult(
        id: 'action_view_expiries',
        title: 'View Expiries',
        subtitle: 'Navigation',
        icon: Icons.warning_amber_rounded,
        onTap: () {
          Navigator.of(context).pop();
          context.push('/expiries');
        },
      ),
    ]);

    // 2. Customers
    for (var customer in customerProvider.customers) {
      results.add(SearchResult(
        id: 'customer_${customer.id}',
        title: customer.name,
        subtitle: 'Customer • ${customer.phone}',
        icon: Icons.person_outline,
        iconColor: Colors.green,
        onTap: () {
          Navigator.of(context).pop();
          context.push('/customers/form', extra: customer);
        },
      ));
    }

    // 3. Companies
    for (var company in companyProvider.companies) {
      results.add(SearchResult(
        id: 'company_${company.id}',
        title: company.companyName,
        subtitle: 'Company • ${company.email ?? ""}',
        icon: Icons.business_outlined,
        iconColor: Colors.blueAccent,
        onTap: () {
          Navigator.of(context).pop();
          context.push('/companies/form', extra: company);
        },
      ));
    }

    // 4. Vehicles
    for (var vehicle in vehicleProvider.vehicles) {
      results.add(SearchResult(
        id: 'vehicle_${vehicle.id}',
        title: vehicle.plateNumber,
        subtitle: 'Vehicle • ${vehicle.make} ${vehicle.model}',
        icon: Icons.directions_car_outlined,
        iconColor: Colors.orange,
        onTap: () {
          Navigator.of(context).pop();
          context.push('/vehicles/form', extra: vehicle);
        },
      ));
    }

    // 5. Employees
    for (var employee in employeeProvider.employees) {
      results.add(SearchResult(
        id: 'employee_${employee.id}',
        title: employee.fullName,
        subtitle: 'Employee • ${employee.position}',
        icon: Icons.badge_outlined,
        iconColor: Colors.purple,
        onTap: () {
          Navigator.of(context).pop();
          // We don't have an employee form route yet based on main.dart
          // but we can add it later if needed.
        },
      ));
    }

    // 6. Invoices
    for (var invoice in invoiceProvider.invoices) {
      results.add(SearchResult(
        id: 'invoice_${invoice.id}',
        title: invoice.invoiceNumber,
        subtitle: 'Invoice • ${invoice.company?.companyName ?? 'Unknown'}',
        icon: Icons.receipt_outlined,
        iconColor: Colors.teal,
        onTap: () {
          Navigator.of(context).pop();
          context.push('/preview', extra: invoice);
        },
      ));
    }

    _allResults = results;
  }

  void _onSearchChanged() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredResults = _allResults;
      } else {
        _filteredResults = _allResults.where((result) {
          return result.title.toLowerCase().contains(query) ||
                 result.subtitle.toLowerCase().contains(query);
        }).toList();
      }
      _selectedIndex = 0; // Reset selection on new search
    });
  }



  @override
  void dispose() {
    _searchController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 48.h),
        child: Focus(
          autofocus: true,
          onKeyEvent: (node, event) {
            if (event.logicalKey == LogicalKeyboardKey.arrowDown && event is KeyDownEvent) {
              setState(() {
                if (_selectedIndex < _filteredResults.length - 1) {
                  _selectedIndex++;
                }
              });
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.arrowUp && event is KeyDownEvent) {
              setState(() {
                if (_selectedIndex > 0) {
                  _selectedIndex--;
                }
              });
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.enter && event is KeyDownEvent) {
              if (_filteredResults.isNotEmpty) {
                _filteredResults[_selectedIndex].onTap();
              }
              return KeyEventResult.handled;
            } else if (event.logicalKey == LogicalKeyboardKey.escape && event is KeyDownEvent) {
              Navigator.of(context).pop();
              return KeyEventResult.handled;
            }
            return KeyEventResult.ignored;
          },
          child: Container(
            width: 600.w,
            height: 500.h,
            decoration: BoxDecoration(
              color: const Color(0xFF1E222D),
              borderRadius: BorderRadius.circular(16.r),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: 0.05),
                  blurRadius: 0,
                  spreadRadius: 1,
                  offset: const Offset(0, 0),
                ),
              ],
            ),
            child: Column(
              children: [
                // Search Input Header
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 16.h),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.search, color: const Color(0xFF7A8BA0), size: 24.sp),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: TextField(
                          controller: _searchController,
                          focusNode: _searchFocusNode,
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 18.sp,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search for anything...',
                            hintStyle: GoogleFonts.inter(
                              color: const Color(0xFF7A8BA0),
                              fontSize: 18.sp,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          'ESC',
                          style: GoogleFonts.inter(
                            color: const Color(0xFF7A8BA0),
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Results List
                Expanded(
                  child: _filteredResults.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: EdgeInsets.symmetric(vertical: 8.h),
                          itemCount: _filteredResults.length,
                          itemBuilder: (context, index) {
                            final result = _filteredResults[index];
                            final isSelected = index == _selectedIndex;
                            return _buildResultItem(result, isSelected, index);
                          },
                        ),
                ),
                // Footer
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    border: Border(
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
                    ),
                    color: Colors.white.withValues(alpha: 0.02),
                    borderRadius: BorderRadius.vertical(bottom: Radius.circular(16.r)),
                  ),
                  child: Row(
                    children: [
                      _buildShortcutHint(Icons.keyboard_arrow_up, Icons.keyboard_arrow_down, 'Navigate'),
                      SizedBox(width: 16.w),
                      _buildShortcutHint(Icons.keyboard_return, null, 'Select'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, color: const Color(0xFF7A8BA0).withValues(alpha: 0.5), size: 48.sp),
          SizedBox(height: 16.h),
          Text(
            'No results found',
            style: GoogleFonts.inter(
              color: const Color(0xFF7A8BA0),
              fontSize: 14.sp,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultItem(SearchResult result, bool isSelected, int index) {
    return MouseRegion(
      onEnter: (_) {
        setState(() {
          _selectedIndex = index;
        });
      },
      child: GestureDetector(
        onTap: result.onTap,
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 12.w, vertical: 2.h),
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          decoration: BoxDecoration(
            color: isSelected ? const Color(0xFF13B1F2).withValues(alpha: 0.15) : Colors.transparent,
            borderRadius: BorderRadius.circular(8.r),
            border: isSelected
                ? Border.all(color: const Color(0xFF13B1F2).withValues(alpha: 0.5), width: 1)
                : Border.all(color: Colors.transparent, width: 1),
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: (result.iconColor ?? Colors.white).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(
                  result.icon,
                  color: result.iconColor ?? Colors.white,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: 16.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 14.sp,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      result.subtitle,
                      style: GoogleFonts.inter(
                        color: const Color(0xFF7A8BA0),
                        fontSize: 12.sp,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected)
                Icon(Icons.keyboard_return, color: const Color(0xFF7A8BA0).withValues(alpha: 0.5), size: 16.sp),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildShortcutHint(IconData icon1, IconData? icon2, String label) {
    return Row(
      children: [
        Container(
          padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(4.r),
          ),
          child: Icon(icon1, color: const Color(0xFF7A8BA0), size: 14.sp),
        ),
        if (icon2 != null) ...[
          SizedBox(width: 4.w),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 2.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(4.r),
            ),
            child: Icon(icon2, color: const Color(0xFF7A8BA0), size: 14.sp),
          ),
        ],
        SizedBox(width: 8.w),
        Text(
          label,
          style: GoogleFonts.inter(
            color: const Color(0xFF7A8BA0),
            fontSize: 12.sp,
          ),
        ),
      ],
    );
  }
}
