import 'package:flutter/material.dart';
import 'package:xloop_invoice/core/utils/app_snack_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/vehicle/domain/entities/vehicle_documents.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:xloop_invoice/features/auth/presentation/providers/auth_provider.dart';
import 'package:xloop_invoice/screens/vehicle_detail_screen.dart';
import 'package:xloop_invoice/screens/document_viewer_screen.dart';
import 'package:xloop_invoice/widgets/complete_follow_up_dialog.dart';
import 'package:xloop_invoice/core/utils/activity_logger.dart';

class _VehicleMaintenanceItem {
  final VehicleEntity vehicle;
  final MaintenanceRecord record;

  _VehicleMaintenanceItem({
    required this.vehicle,
    required this.record,
  });
}

class AllVehiclesMaintenanceHistoryScreen extends StatefulWidget {
  const AllVehiclesMaintenanceHistoryScreen({super.key});

  @override
  State<AllVehiclesMaintenanceHistoryScreen> createState() =>
      _AllVehiclesMaintenanceHistoryScreenState();
}

class _AllVehiclesMaintenanceHistoryScreenState
    extends State<AllVehiclesMaintenanceHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedFilter = 'All'; // 'All', 'Follow-ups', 'Extensions'
  String _selectedVehicleFilter = 'All Vehicles';
  String _selectedShopFilter = 'All Shops';

  // Pagination states
  int _currentPage = 1;
  int _itemsPerPage = 10;
  final List<int> _allowedPageSizes = [10, 20, 50];

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_VehicleMaintenanceItem> _gatherAllFleetHistory(
    List<VehicleEntity> vehicles,
  ) {
    final List<_VehicleMaintenanceItem> items = [];

    for (var vehicle in vehicles) {
      final List<MaintenanceRecord> history = List.from(
        vehicle.maintenanceHistory ?? [],
      );

      // Legacy fallback
      if (history.isEmpty && vehicle.maintenance != null) {
        final m = vehicle.maintenance!;
        _addRecordIfNotNull(history, m.engineOil, 'Engine Oil');
        _addRecordIfNotNull(history, m.gearOil, 'Gear Oil');
        _addRecordIfNotNull(history, m.housingOil, 'Housing Oil');
        _addRecordIfNotNull(history, m.tyreChange, 'Tyre Change');
        _addRecordIfNotNull(history, m.batteryChange, 'Battery Change');
        _addRecordIfNotNull(history, m.brakePads, 'Brake Pads');
        _addRecordIfNotNull(history, m.airFilter, 'Air Filter');
        _addRecordIfNotNull(history, m.acService, 'AC Service');
        _addRecordIfNotNull(history, m.wheelAlignment, 'Wheel Alignment');
        _addRecordIfNotNull(history, m.sparkPlugs, 'Spark Plugs');
        _addRecordIfNotNull(history, m.coolantFlush, 'Coolant Flush');
        _addRecordIfNotNull(history, m.wiperBlades, 'Wiper Blades');
        _addRecordIfNotNull(history, m.timingBelt, 'Timing Belt');
        _addRecordIfNotNull(history, m.transmissionFluid, 'Transmission Fluid');
        _addRecordIfNotNull(history, m.brakeFluid, 'Brake Fluid');
        _addRecordIfNotNull(history, m.fuelFilter, 'Fuel Filter');
      }

      for (var record in history) {
        items.add(_VehicleMaintenanceItem(vehicle: vehicle, record: record));
      }
    }

    // Sort by created/service date descending (most recent first)
    items.sort((a, b) => b.record.date.compareTo(a.record.date));
    return items;
  }

  void _addRecordIfNotNull(
    List<MaintenanceRecord> history,
    MaintenanceRecord? record,
    String overrideType,
  ) {
    if (record != null) {
      history.add(
        MaintenanceRecord(
          date: record.date,
          mileage: record.mileage,
          attachmentUrl: record.attachmentUrl,
          attachmentUrls: record.attachmentUrls,
          notificationDays: record.notificationDays,
          cost: record.cost,
          partsCost: record.partsCost,
          laborCost: record.laborCost,
          serviceProvider: record.serviceProvider,
          workOrderNumber: record.workOrderNumber,
          serviceType: record.serviceType ?? overrideType,
          partsReplaced: record.partsReplaced,
          notes: record.notes,
          nextServiceMileage: record.nextServiceMileage,
          nextServiceDate: record.nextServiceDate,
          isFollowUpRequired: record.isFollowUpRequired,
          followUpReason: record.followUpReason,
          isFollowUpCompleted: record.isFollowUpCompleted,
          extendedMileage: record.extendedMileage,
          extendedDate: record.extendedDate,
          extensionReason: record.extensionReason,
          isExtended: record.isExtended,
          followUpIntervalKm: record.followUpIntervalKm,
          followUpTimesCount: record.followUpTimesCount,
          followUpCompletions: record.followUpCompletions,
          performedBy: record.performedBy,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAdmin = context.watch<AuthProvider>().user?.isAdmin ?? false;

    return Consumer<VehicleProvider>(
      builder: (context, vehicleProvider, _) {
        if (vehicleProvider.isLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        final vehicles = vehicleProvider.vehicles;
        final allItems = _gatherAllFleetHistory(vehicles);

        // Gather unique vehicle names & shops for dropdown filters
        final Map<String, String> vehicleOptions = {'All Vehicles': 'All Vehicles'};
        for (var v in vehicles) {
          vehicleOptions[v.id] = '${v.make} ${v.model} (${v.plateNumber})';
        }

        final Set<String> availableShops = {'All Shops'};
        for (var item in allItems) {
          if (item.record.serviceProvider != null &&
              item.record.serviceProvider!.isNotEmpty) {
            availableShops.add(item.record.serviceProvider!);
          }
        }

        // Apply filters
        final filteredItems = allItems.where((item) {
          final v = item.vehicle;
          final r = item.record;

          // Category filter
          if (_selectedFilter == 'Follow-ups' && r.isFollowUpRequired != true) {
            return false;
          }
          if (_selectedFilter == 'Extensions' &&
              r.isExtended != true &&
              !(r.serviceType != null &&
                  r.serviceType!.startsWith('Extension:'))) {
            return false;
          }

          // Vehicle filter
          if (_selectedVehicleFilter != 'All Vehicles' &&
              v.id != _selectedVehicleFilter) {
            return false;
          }

          // Shop filter
          if (_selectedShopFilter != 'All Shops' &&
              r.serviceProvider != _selectedShopFilter) {
            return false;
          }

          // Search query filter
          if (_searchQuery.trim().isNotEmpty) {
            final query = _searchQuery.trim().toLowerCase();
            final vehicleMatch =
                '${v.make} ${v.model} ${v.plateNumber} ${v.color}'
                    .toLowerCase()
                    .contains(query);
            final serviceTypeMatch =
                (r.serviceType ?? '').toLowerCase().contains(query);
            final providerMatch =
                (r.serviceProvider ?? '').toLowerCase().contains(query);
            final workOrderMatch =
                (r.workOrderNumber ?? '').toLowerCase().contains(query);
            final notesMatch = (r.notes ?? '').toLowerCase().contains(query);
            final performedByMatch =
                (r.performedBy ?? '').toLowerCase().contains(query);
            if (!vehicleMatch &&
                !serviceTypeMatch &&
                !providerMatch &&
                !workOrderMatch &&
                !notesMatch &&
                !performedByMatch) {
              return false;
            }
          }

          return true;
        }).toList();

        // Calculate pagination
        final totalItems = filteredItems.length;
        final totalPages = (totalItems == 0)
            ? 1
            : ((totalItems - 1) ~/ _itemsPerPage) + 1;

        if (_currentPage > totalPages) {
          _currentPage = totalPages;
        }
        if (_currentPage < 1) {
          _currentPage = 1;
        }

        final startIndex = (totalItems == 0) ? 0 : (_currentPage - 1) * _itemsPerPage;
        final endIndex = (startIndex + _itemsPerPage > totalItems)
            ? totalItems
            : startIndex + _itemsPerPage;

        final pageItems = (totalItems == 0)
            ? <_VehicleMaintenanceItem>[]
            : filteredItems.sublist(startIndex, endIndex);

        final double totalCost = filteredItems.fold(
          0.0,
          (sum, item) => sum + (item.record.cost ?? 0.0),
        );

        return Scaffold(
          backgroundColor: Colors.grey[50],
          body: Column(
            children: [
              _buildSearchBar(),
              _buildFilterBar(vehicleOptions, availableShops.toList()),
              if (isAdmin)
                _buildCostSummaryCard(totalCost, filteredItems.length),
              Expanded(
                child: filteredItems.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.build_circle_outlined,
                              size: 64.sp,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 12.h),
                            Text(
                              'No maintenance records found',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.grey[600],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (_searchQuery.isNotEmpty ||
                                _selectedFilter != 'All' ||
                                _selectedVehicleFilter != 'All Vehicles' ||
                                _selectedShopFilter != 'All Shops') ...[
                              SizedBox(height: 8.h),
                              TextButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _searchController.clear();
                                    _searchQuery = '';
                                    _selectedFilter = 'All';
                                    _selectedVehicleFilter = 'All Vehicles';
                                    _selectedShopFilter = 'All Shops';
                                    _currentPage = 1;
                                  });
                                },
                                icon: const Icon(Icons.clear_all),
                                label: const Text('Reset Filters'),
                              ),
                            ],
                          ],
                        ),
                      )
                    : ListView.separated(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 12.h,
                        ),
                        itemCount: pageItems.length,
                        separatorBuilder: (context, index) =>
                            SizedBox(height: 12.h),
                        itemBuilder: (context, index) {
                          final item = pageItems[index];
                          return _buildHistoryCard(
                            context,
                            item.vehicle,
                            item.record,
                            isAdmin: isAdmin,
                          );
                        },
                      ),
              ),
              if (totalItems > 0)
                _buildPaginationBar(
                  totalItems: totalItems,
                  totalPages: totalPages,
                  startIndex: startIndex,
                  endIndex: endIndex,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      color: Colors.white,
      child: TextField(
        controller: _searchController,
        onChanged: (val) {
          setState(() {
            _searchQuery = val;
            _currentPage = 1;
          });
        },
        decoration: InputDecoration(
          hintText: 'Search by vehicle, service, shop, or notes...',
          hintStyle: TextStyle(fontSize: 13.sp, color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, size: 20.sp, color: Colors.grey[600]),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.clear, size: 18.sp, color: Colors.grey[600]),
                  onPressed: () {
                    setState(() {
                      _searchController.clear();
                      _searchQuery = '';
                      _currentPage = 1;
                    });
                  },
                )
              : null,
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10.r),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  Widget _buildFilterBar(
    Map<String, String> vehicleOptions,
    List<String> availableShops,
  ) {
    final categories = ['All', 'Follow-ups', 'Extensions'];

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: categories.map((cat) {
                      final isSelected = _selectedFilter == cat;
                      return Padding(
                        padding: EdgeInsets.only(right: 6.w),
                        child: ChoiceChip(
                          label: Text(
                            cat,
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.grey[700],
                              fontWeight:
                                  isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11.sp,
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (val) {
                            if (val) {
                              setState(() {
                                _selectedFilter = cat;
                                _currentPage = 1;
                              });
                            }
                          },
                          selectedColor: Colors.blue[700],
                          backgroundColor: Colors.grey[100],
                          checkmarkColor: Colors.white,
                          padding: EdgeInsets.symmetric(horizontal: 4.w),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16.r),
                            side: BorderSide(
                              color: isSelected
                                  ? Colors.blue.shade700
                                  : Colors.grey.shade300,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 6.h),
          Row(
            children: [
              // Vehicle Dropdown
              Expanded(
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: vehicleOptions.containsKey(_selectedVehicleFilter)
                          ? _selectedVehicleFilter
                          : 'All Vehicles',
                      isExpanded: true,
                      icon: Icon(Icons.directions_car, size: 16.sp, color: Colors.blue[700]),
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.black87,
                        fontWeight: FontWeight.w500,
                      ),
                      items: vehicleOptions.entries.map((entry) {
                        return DropdownMenuItem<String>(
                          value: entry.key,
                          child: Text(
                            entry.value,
                            overflow: TextOverflow.ellipsis,
                          ),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null) {
                          setState(() {
                            _selectedVehicleFilter = val;
                            _currentPage = 1;
                          });
                        }
                      },
                    ),
                  ),
                ),
              ),
              if (availableShops.length > 1) ...[
                SizedBox(width: 8.w),
                // Shop Dropdown
                Expanded(
                  child: Container(
                    padding: EdgeInsets.symmetric(horizontal: 10.w),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _selectedShopFilter,
                        isExpanded: true,
                        icon: Icon(Icons.storefront, size: 16.sp, color: Colors.teal[700]),
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.black87,
                          fontWeight: FontWeight.w500,
                        ),
                        items: availableShops.map((shop) {
                          return DropdownMenuItem<String>(
                            value: shop,
                            child: Text(
                              shop,
                              overflow: TextOverflow.ellipsis,
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedShopFilter = val;
                              _currentPage = 1;
                            });
                          }
                        },
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
          SizedBox(height: 4.h),
        ],
      ),
    );
  }

  Widget _buildCostSummaryCard(double totalCost, int recordCount) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16.w, vertical: 6.h),
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 10.h),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue.shade800, Colors.indigo.shade900],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(10.r),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withValues(alpha: 0.15),
            blurRadius: 6,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(6.w),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.account_balance_wallet,
                  color: Colors.white,
                  size: 18.sp,
                ),
              ),
              SizedBox(width: 10.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Fleet Total Maintenance Cost',
                    style: TextStyle(
                      color: Colors.white70,
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    'SAR ${totalCost.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Text(
              '$recordCount Records',
              style: TextStyle(
                color: Colors.white,
                fontSize: 11.sp,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(
    BuildContext context,
    VehicleEntity vehicle,
    MaintenanceRecord record, {
    required bool isAdmin,
  }) {
    final dateStr = DateFormat('MMM dd, yyyy').format(record.date);

    return Card(
      elevation: 2,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(14.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Vehicle Header Badge
            InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => VehicleDetailScreen(vehicle: vehicle),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(8.r),
              child: Container(
                padding: EdgeInsets.all(8.w),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(8.r),
                  border: Border.all(
                    color: Colors.blue.withValues(alpha: 0.15),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 38.w,
                      height: 38.w,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(6.r),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: vehicle.imageUrl != null
                          ? Image.network(
                              vehicle.imageUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  Icon(Icons.directions_car, size: 20.sp, color: Colors.blue[700]),
                            )
                          : Icon(Icons.directions_car, size: 20.sp, color: Colors.blue[700]),
                    ),
                    SizedBox(width: 10.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${vehicle.make} ${vehicle.model} (${vehicle.year})',
                            style: TextStyle(
                              fontSize: 13.sp,
                              fontWeight: FontWeight.bold,
                              color: Colors.blue[900],
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            'Plate: ${vehicle.plateNumber} • ${vehicle.color} • Odo: ${vehicle.currentOdometer ?? 0} KM',
                            style: TextStyle(
                              fontSize: 11.sp,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(
                      Icons.chevron_right,
                      size: 18.sp,
                      color: Colors.blue[700],
                    ),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.h),

            // Service Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    record.serviceType?.toUpperCase() ?? 'MAINTENANCE RECORD',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      dateStr,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (isAdmin) ...[
                      SizedBox(width: 6.w),
                      IconButton(
                        icon: Icon(
                          Icons.delete_outline,
                          color: Colors.red[600],
                          size: 18.sp,
                        ),
                        onPressed: () => _showDeleteConfirmation(
                          vehicle,
                          record,
                        ),
                        constraints: const BoxConstraints(),
                        padding: EdgeInsets.zero,
                        tooltip: 'Delete record',
                      ),
                    ],
                  ],
                ),
              ],
            ),

            // Follow Up status chip if applicable
            if (record.isFollowUpRequired == true) ...[
              SizedBox(height: 6.h),
              Row(
                children: [
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: record.isFollowUpCompleted == true
                          ? Colors.green.withValues(alpha: 0.1)
                          : Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                      border: Border.all(
                        color: record.isFollowUpCompleted == true
                            ? Colors.green.shade300
                            : Colors.orange.shade300,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          record.isFollowUpCompleted == true
                              ? Icons.check_circle_outline
                              : Icons.warning_amber_rounded,
                          size: 12.sp,
                          color: record.isFollowUpCompleted == true
                              ? Colors.green.shade700
                              : Colors.orange.shade700,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          record.isFollowUpCompleted == true
                              ? 'Follow-up Completed'
                              : 'Follow-up Pending',
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.bold,
                            color: record.isFollowUpCompleted == true
                                ? Colors.green.shade700
                                : Colors.orange.shade700,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (record.isFollowUpCompleted != true) ...[
                    SizedBox(width: 8.w),
                    TextButton.icon(
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 2.h),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      onPressed: () {
                        showDialog(
                          context: context,
                          builder: (context) => CompleteFollowUpDialog(
                            vehicle: vehicle,
                            record: record,
                          ),
                        );
                      },
                      icon: Icon(Icons.check, size: 12.sp),
                      label: Text(
                        'Mark Completed',
                        style: TextStyle(fontSize: 11.sp),
                      ),
                    ),
                  ],
                ],
              ),
            ],

            Divider(height: 20.h),
            _buildInfoRow(Icons.speed, 'Mileage', '${record.mileage} KM'),
            if (record.isFollowUpRequired == true) ...[
              _buildInfoRow(
                Icons.info_outline,
                'Follow-up Reason',
                record.followUpReason ?? 'General Revisit',
              ),
              if (record.nextServiceDate != null)
                _buildInfoRow(
                  Icons.calendar_month,
                  'Follow-up Date',
                  DateFormat('MMM dd, yyyy').format(record.nextServiceDate!),
                ),
              if (record.nextServiceMileage != null &&
                  record.nextServiceMileage! > 0)
                _buildInfoRow(
                  Icons.speed,
                  'Follow-up Odometer',
                  '${record.nextServiceMileage} KM',
                ),
            ],
            if (record.serviceProvider != null &&
                record.serviceProvider!.isNotEmpty)
              _buildInfoRow(
                Icons.build_circle,
                'Provider',
                record.serviceProvider!,
              ),
            if (record.workOrderNumber != null &&
                record.workOrderNumber!.isNotEmpty)
              _buildInfoRow(
                Icons.receipt_long,
                'Work Order',
                record.workOrderNumber!,
              ),
            if (isAdmin && record.cost != null)
              _buildInfoRow(
                Icons.attach_money,
                'Total Cost',
                'SAR ${record.cost!.toStringAsFixed(2)}',
              ),
            if (record.notes != null && record.notes!.isNotEmpty)
              _buildInfoRow(Icons.notes, 'Notes', record.notes!),
            if (record.performedBy != null && record.performedBy!.isNotEmpty)
              _buildInfoRow(Icons.person_outline, 'Logged by', record.performedBy!),

            // Documents / Receipts
            (() {
              final List<String> urls = [];
              if (record.attachmentUrls != null &&
                  record.attachmentUrls!.isNotEmpty) {
                urls.addAll(record.attachmentUrls!);
              } else if (record.attachmentUrl != null &&
                  record.attachmentUrl!.isNotEmpty) {
                urls.add(record.attachmentUrl!);
              }

              if (urls.isEmpty) return const SizedBox.shrink();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 8.h),
                  Text(
                    'Documents:',
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.grey[600],
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Wrap(
                    spacing: 6.w,
                    runSpacing: 6.h,
                    children: urls.asMap().entries.map((entry) {
                      final idx = entry.key;
                      final url = entry.value;
                      final displayName =
                          urls.length == 1 ? 'Receipt' : 'Receipt #${idx + 1}';

                      return ActionChip(
                        avatar: Icon(
                          Icons.file_present_rounded,
                          size: 14.sp,
                          color: Colors.blue.shade700,
                        ),
                        label: Text(
                          displayName,
                          style: TextStyle(
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        backgroundColor:
                            Colors.blue.shade50.withValues(alpha: 0.5),
                        side: BorderSide(color: Colors.blue.shade100),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => DocumentViewerScreen(
                                attachmentUrl: url,
                                title:
                                    '${record.serviceType ?? 'Maintenance'} - $displayName',
                              ),
                            ),
                          );
                        },
                      );
                    }).toList(),
                  ),
                ],
              );
            })(),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationBar({
    required int totalItems,
    required int totalPages,
    required int startIndex,
    required int endIndex,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 8.h),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey.shade200)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Items per page selector & status text
          Row(
            children: [
              Text(
                'Per page: ',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[700]),
              ),
              DropdownButton<int>(
                value: _itemsPerPage,
                isDense: true,
                underline: const SizedBox(),
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue[800],
                ),
                items: _allowedPageSizes.map((size) {
                  return DropdownMenuItem<int>(
                    value: size,
                    child: Text(size.toString()),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _itemsPerPage = val;
                      _currentPage = 1;
                    });
                  }
                },
              ),
              SizedBox(width: 8.w),
              Text(
                '${startIndex + 1}-$endIndex of $totalItems',
                style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
              ),
            ],
          ),

          // Page navigation controls
          Row(
            children: [
              IconButton(
                icon: Icon(Icons.first_page, size: 18.sp),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage = 1)
                    : null,
              ),
              SizedBox(width: 6.w),
              IconButton(
                icon: Icon(Icons.chevron_left, size: 18.sp),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _currentPage > 1
                    ? () => setState(() => _currentPage--)
                    : null,
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: 8.w),
                child: Text(
                  '$_currentPage / $totalPages',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                ),
              ),
              IconButton(
                icon: Icon(Icons.chevron_right, size: 18.sp),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage++)
                    : null,
              ),
              SizedBox(width: 6.w),
              IconButton(
                icon: Icon(Icons.last_page, size: 18.sp),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                onPressed: _currentPage < totalPages
                    ? () => setState(() => _currentPage = totalPages)
                    : null,
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(
    VehicleEntity vehicle,
    MaintenanceRecord record,
  ) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete Record'),
        content: const Text(
          'Are you sure you want to delete this maintenance record? This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('CANCEL'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(dialogContext);
              try {
                await context.read<VehicleProvider>().deleteMaintenanceRecord(
                      vehicle,
                      record,
                    );
                if (mounted) {
                  await ActivityLogger.log(
                    context,
                    title: 'Maintenance Deleted',
                    message: 'Deleted maintenance record (${record.serviceType}) for vehicle ${vehicle.make} ${vehicle.model} (${vehicle.plateNumber}).',
                    relatedId: vehicle.id,
                  );
                }
                if (context.mounted) {
                  AppSnackBar.showSuccess(context, 'Maintenance record deleted successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  AppSnackBar.showError(context, 'Failed to delete maintenance record: $e');
                }
              }
            },
            child: const Text('DELETE', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: EdgeInsets.only(bottom: 4.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15.sp, color: Colors.grey[600]),
          SizedBox(width: 6.w),
          Text(
            '$label: ',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
