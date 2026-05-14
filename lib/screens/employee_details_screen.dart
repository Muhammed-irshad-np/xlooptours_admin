import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'document_viewer_screen.dart';
import 'package:xloop_invoice/core/utils/share_helper.dart';

import '../features/employee/domain/entities/employee_contact.dart';
import '../features/employee/domain/entities/employee_documents.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/vehicle/domain/entities/vehicle_documents.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';
import 'package:xloop_invoice/features/employee/presentation/widgets/authorize_vehicle_dialog.dart';
import 'package:xloop_invoice/features/vehicle/presentation/providers/vehicle_provider.dart';
import 'package:provider/provider.dart';
import '../core/widgets/modern_app_bar.dart';
import '../core/widgets/modern_tab_bar.dart';
import 'tafweed_history_view_all_screen.dart';

class EmployeeDetailsScreen extends StatelessWidget {
  final EmployeeEntity employee;
  final VehicleEntity? assignedVehicle;

  const EmployeeDetailsScreen({
    super.key,
    required this.employee,
    this.assignedVehicle,
  });

  String _formatDate(DateTime? date) {
    if (date == null) return 'N/A';
    return DateFormat('MMM dd, yyyy').format(date);
  }

  Future<void> _launchUrl(String? urlString) async {
    if (urlString == null || urlString.isEmpty) return;
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch $urlString');
    }
  }

  Future<void> _confirmCancelTafweed(
    BuildContext context,
    VehicleEntity currentVehicle,
    TafweedRecord record,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancel Authorization'),
        content: const Text(
          'Are you sure you want to cancel the current authorization? This will record the end date as today and move it to history.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Confirm Cancel'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      final updatedActiveTafweeds = List<TafweedRecord>.from(
        currentVehicle.tafweeds ?? [],
      )..remove(record);

      final updatedHistory = List<TafweedRecord>.from(
        currentVehicle.tafweedHistory ?? [],
      );
      updatedHistory.add(record.copyWith(expiryDate: DateTime.now()));

      final updatedVehicle = currentVehicle.copyWith(
        tafweeds: updatedActiveTafweeds,
        tafweedHistory: updatedHistory,
      );
      await context.read<VehicleProvider>().updateVehicle(updatedVehicle);
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: const ModernAppBar(
          title: 'Employee Details',
          bottom: ModernTabBar(
            tabs: [
              Tab(text: 'Personal'),
              Tab(text: 'Documents & IDs'),
              Tab(text: 'Others'),
            ],
          ),
        ),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 800),
            child: TabBarView(
              children: [
                // Tab 1: Personal
                SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildProfileHeader(),
                      SizedBox(height: 24.h),
                      _buildSectionHeader('Personal Information'),
                      _buildPersonalInfoCard(),
                      if (assignedVehicle != null) ...[
                        SizedBox(height: 24.h),
                        _buildSectionHeader('Assigned Vehicle'),
                        _buildVehicleCard(),
                      ],
                      _buildAuthorizedVehiclesCard(context),
                      _buildTafweedHistorySection(context),
                    ],
                  ),
                ),

                // Tab 2: Documents & IDs
                SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildSectionHeader('Documents & IDs'),
                      _buildDocumentsSection(context),
                    ],
                  ),
                ),

                // Tab 3: Others (Contacts & Recharge)
                SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (employee.contacts.isNotEmpty) ...[
                        _buildSectionHeader('SIM / Contact Numbers'),
                        ...employee.contacts.map(
                          (contact) => _buildContactCard(contact),
                        ),
                      ] else ...[
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.h),
                          child: Center(
                            child: Text(
                              'No contacts added yet.',
                              style: TextStyle(
                                fontSize: 16.sp,
                                color: Colors.grey,
                                fontStyle: FontStyle.italic,
                              ),
                            ),
                          ),
                        ),
                      ],
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 18.sp,
          fontWeight: FontWeight.bold,
          color: Colors.blue[900],
        ),
      ),
    );
  }

  Widget _buildProfileHeader() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Row(
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: ClipOval(
                child:
                    (employee.imageUrl != null && employee.imageUrl!.isNotEmpty)
                    ? CachedNetworkImage(
                        imageUrl: employee.imageUrl!,
                        fit: BoxFit.cover,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(strokeWidth: 3),
                        ),
                        errorWidget: (context, url, error) => const Icon(
                          Icons.broken_image,
                          color: Colors.red,
                          size: 40,
                        ),
                      )
                    : Center(
                        child: Text(
                          employee.fullName.isNotEmpty
                              ? employee.fullName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
              ),
            ),
            SizedBox(width: 20.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    employee.fullName,
                    style: TextStyle(
                      fontSize: 22.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    employee.position,
                    style: TextStyle(
                      fontSize: 16.sp,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 8.h),
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: employee.isActive
                              ? Colors.green.withValues(alpha: 0.1)
                              : Colors.grey.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: employee.isActive
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                        child: Text(
                          employee.isActive ? 'Active' : 'Inactive',
                          style: TextStyle(
                            fontSize: 12.sp,
                            fontWeight: FontWeight.bold,
                            color: employee.isActive
                                ? Colors.green
                                : Colors.grey,
                          ),
                        ),
                      ),
                      if (employee.driverType != null) ...[
                        SizedBox(width: 8.w),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: 8.w,
                            vertical: 4.h,
                          ),
                          decoration: BoxDecoration(
                            color: employee.driverType == 'Internal'
                                ? Colors.blue.withValues(alpha: 0.1)
                                : Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8.r),
                            border: Border.all(
                              color: employee.driverType == 'Internal'
                                  ? Colors.blue
                                  : Colors.orange,
                            ),
                          ),
                          child: Text(
                            employee.driverType!,
                            style: TextStyle(
                              fontSize: 12.sp,
                              fontWeight: FontWeight.bold,
                              color: employee.driverType == 'Internal'
                                  ? Colors.blue
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPersonalInfoCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            if (employee.driverType != 'External')
              _buildDetailRow('Email', employee.email, Icons.email),
            _buildDetailRow('Phone', employee.phoneNumber, Icons.phone),
            _buildDetailRow('Nationality', employee.nationality, Icons.flag),
            _buildDetailRow('Gender', employee.gender, Icons.person),
            _buildDetailRow('ID Type', employee.idType, Icons.badge),
            _buildDetailRow('ID Number', employee.idNumber, Icons.numbers),
            if (employee.driverType != 'External') ...[
              _buildDetailRow(
                'Join Date',
                _formatDate(employee.joinDate),
                Icons.calendar_today,
              ),
              _buildDetailRow(
                'Birth Date',
                _formatDate(employee.birthDate),
                Icons.cake,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildVehicleCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.directions_car,
                color: Colors.blue,
                size: 30.sp,
              ),
            ),
            SizedBox(width: 16.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${assignedVehicle!.make} ${assignedVehicle!.model}',
                    style: TextStyle(
                      fontSize: 18.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    'Plate: ${assignedVehicle!.plateNumber}',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  ),
                  Text(
                    'Year: ${assignedVehicle!.year}',
                    style: TextStyle(fontSize: 14.sp, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorizedVehiclesCard(BuildContext context) {
    final vehicles = context.watch<VehicleProvider>().vehicles;
    final authorizedVehicles = vehicles.where((v) {
      if (v.tafweeds == null) return false;
      return v.tafweeds!.any((t) => t.driverId == employee.id);
    }).toList();

    if (authorizedVehicles.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: 24.h),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildSectionHeader('Tafweed (Authorized Vehicles)'),
              TextButton.icon(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) =>
                        AuthorizeVehicleDialog(employee: employee),
                  );
                },
                icon: const Icon(Icons.add_circle_outline, size: 20),
                label: const Text('Authorize'),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.blue[900],
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                ),
              ),
            ],
          ),
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Text(
                'No vehicles currently authorized for this employee.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
              ),
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 24.h),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionHeader('Tafweed (Authorized Vehicles)'),
            TextButton.icon(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (context) =>
                      AuthorizeVehicleDialog(employee: employee),
                );
              },
              icon: const Icon(Icons.add_circle_outline, size: 20),
              label: const Text('Authorize'),
              style: TextButton.styleFrom(
                foregroundColor: Colors.blue[900],
                padding: EdgeInsets.symmetric(horizontal: 12.w),
              ),
            ),
          ],
        ),
        ...authorizedVehicles.map((vehicle) {
          final tafweedsForEmployee = vehicle.tafweeds
              ?.where((t) => t.driverId == employee.id)
              .toList();
          final employeeTafweed =
              (tafweedsForEmployee != null && tafweedsForEmployee.isNotEmpty)
              ? tafweedsForEmployee.first
              : null;

          return Card(
            elevation: 2,
            margin: EdgeInsets.only(bottom: 12.h),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
            ),
            child: Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(12.w),
                        decoration: BoxDecoration(
                          color: Colors.purple.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.admin_panel_settings,
                          color: Colors.purple,
                          size: 30.sp,
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${vehicle.make} ${vehicle.model}',
                              style: TextStyle(
                                fontSize: 18.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 4.h),
                            Text(
                              'Plate: ${vehicle.plateNumber}',
                              style: TextStyle(
                                fontSize: 14.sp,
                                color: Colors.grey[700],
                              ),
                            ),
                            if (employeeTafweed != null) ...[
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Text(
                                    'Tafweed Expiry: ',
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      color: Colors.grey[700],
                                    ),
                                  ),
                                  Text(
                                    _formatDate(employeeTafweed.expiryDate),
                                    style: TextStyle(
                                      fontSize: 14.sp,
                                      fontWeight: FontWeight.bold,
                                      color: employeeTafweed.expiryDate
                                              .isBefore(DateTime.now())
                                          ? Colors.red
                                          : Colors.green,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (employeeTafweed != null) ...[
                    SizedBox(height: 12.h),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Padding(
                          padding: EdgeInsets.only(right: 8.w),
                          child: TextButton.icon(
                            onPressed: () => _confirmCancelTafweed(
                              context,
                              vehicle,
                              employeeTafweed,
                            ),
                            icon: Icon(Icons.cancel_outlined,
                                color: Colors.orange[700], size: 18.sp),
                            label: Text(
                              'Cancel Authorization',
                              style: TextStyle(
                                color: Colors.orange[700],
                                fontSize: 12.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: TextButton.styleFrom(
                              backgroundColor: Colors.orange[50],
                              padding: EdgeInsets.symmetric(horizontal: 12.w),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8.r),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildContactCard(EmployeeContact contact) {
    final bool isExpired =
        contact.rechargeExpiryDate != null &&
        contact.rechargeExpiryDate!.isBefore(DateTime.now());
    final bool isSwapped =
        contact.currentHolderId != null &&
        contact.currentHolderId != employee.id;

    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: Colors.blue.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.sim_card,
                    color: Colors.blue[700],
                    size: 24.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${contact.countryCode} ${contact.phoneNumber}',
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (contact.label.isNotEmpty) ...[
                        SizedBox(height: 2.h),
                        Text(
                          contact.label,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (isSwapped)
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 8.w,
                      vertical: 4.h,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8.r),
                      border: Border.all(color: Colors.orange),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.swap_horiz,
                          size: 14.sp,
                          color: Colors.orange,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          contact.currentHolderName ?? 'Swapped',
                          style: TextStyle(
                            fontSize: 11.sp,
                            color: Colors.orange,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12.h),
            Divider(height: 1, color: Colors.grey[200]),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _buildDetailRow(
                    'Recharge Expiry',
                    _formatDate(contact.rechargeExpiryDate),
                    isExpired ? Icons.warning : Icons.event,
                  ),
                ),
                Expanded(
                  child: _buildDetailRow(
                    'Recharge Cost',
                    contact.rechargeCost != null
                        ? contact.rechargeCost!.toStringAsFixed(2)
                        : 'N/A',
                    Icons.attach_money,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentsSection(BuildContext context) {
    return Column(
      children: [
        if (employee.iqama != null)
          _buildDocumentCard(
            context,
            title: 'Iqama',
            icon: Icons.badge,
            number: employee.iqama!.number,
            expiryDate: employee.iqama!.expiryDate,
            attachmentUrl: employee.iqama!.attachmentUrl,
            notificationDays: null,
          ),
        if (employee.bahrainResidence != null)
          _buildDocumentCard(
            context,
            title: 'Bahrain Residence ID',
            icon: Icons.badge,
            number: employee.bahrainResidence!.number,
            expiryDate: employee.bahrainResidence!.expiryDate,
            attachmentUrl: employee.bahrainResidence!.attachmentUrl,
            notificationDays: null,
          ),
        if (employee.passport != null)
          _buildDocumentCard(
            context,
            title: 'Passport',
            icon: Icons.book,
            number: employee.passport!.number,
            expiryDate: employee.passport!.expiryDate,
            attachmentUrl: employee.passport!.attachmentUrl,
            extraInfo: 'Name: ${employee.passport!.nameOnPassport}',
            notificationDays: null,
          ),
        if (employee.drivingLicense != null)
          _buildDocumentCard(
            context,
            title: 'Driving License',
            icon: Icons.drive_eta,
            number: employee.drivingLicense!.number,
            expiryDate: employee.drivingLicense!.expiryDate,
            attachmentUrl: employee.drivingLicense!.attachmentUrl,
            extraInfo:
                'Type: ${employee.drivingLicense!.type.name.toUpperCase()}\nCountry: ${employee.drivingLicense!.countryOfOrigin}',
            notificationDays: null,
          ),
        if (employee.saudiVisa != null)
          _buildVisaCard(context, 'Saudi Visa', employee.saudiVisa!),
        if (employee.bahrainVisa != null)
          _buildVisaCard(context, 'Bahrain Visa', employee.bahrainVisa!),
        if (employee.dubaiVisa != null)
          _buildVisaCard(context, 'Dubai Visa', employee.dubaiVisa!),
        if (employee.qatarVisa != null)
          _buildVisaCard(context, 'Qatar Visa', employee.qatarVisa!),
        if (employee.healthInsurance != null)
          _buildDocumentCard(
            context,
            title: 'Health Insurance',
            icon: Icons.health_and_safety,
            number: 'N/A',
            expiryDate: employee.healthInsurance!.expiryDate,
            attachmentUrl: employee.healthInsurance!.attachmentUrl,
            notificationDays: null,
          ),
        if (employee.authorization != null)
          _buildDocumentCard(
            context,
            title: 'Authorization',
            icon: Icons.security,
            number: 'N/A',
            expiryDate: employee.authorization!.expiryDate,
            attachmentUrl: employee.authorization!.attachmentUrl,
            notificationDays: null,
          ),
        if (_hasNoDocuments())
          Padding(
            padding: EdgeInsets.symmetric(vertical: 24.h),
            child: Text(
              'No documents uploaded for this employee.',
              style: TextStyle(
                color: Colors.grey,
                fontStyle: FontStyle.italic,
                fontSize: 16.sp,
              ),
              textAlign: TextAlign.center,
            ),
          ),
      ],
    );
  }

  bool _hasNoDocuments() {
    return employee.iqama == null &&
        employee.bahrainResidence == null &&
        employee.passport == null &&
        employee.drivingLicense == null &&
        employee.healthInsurance == null &&
        employee.saudiVisa == null &&
        employee.bahrainVisa == null &&
        employee.dubaiVisa == null &&
        employee.qatarVisa == null &&
        employee.authorization == null;
  }

  Widget _buildVisaCard(BuildContext context, String title, VisaDocument visa) {
    return _buildDocumentCard(
      context,
      title: title,
      icon: Icons.airplane_ticket,
      number: visa.number,
      expiryDate: visa.expiryDate,
      attachmentUrl: visa.attachmentUrl,
      extraInfo:
          'Type: ${visa.type == VisaType.singleEntry ? "Single Entry" : "Multiple Entry"}',
      notificationDays: null,
    );
  }

  Widget _buildDocumentCard(
    BuildContext context, {
    required String title,
    required IconData icon,
    required String number,
    required DateTime expiryDate,
    String? attachmentUrl,
    String? extraInfo,
    int? notificationDays,
  }) {
    final bool isExpired = expiryDate.isBefore(DateTime.now());

    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: 12.h),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icon, color: Colors.blue[700], size: 28.sp),
                SizedBox(width: 16.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 16.sp,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4.h),
                      if (number != 'N/A')
                        Text(
                          'No: $number',
                          style: TextStyle(
                            fontSize: 14.sp,
                            color: Colors.grey[800],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      SizedBox(height: 2.h),
                      Row(
                        children: [
                          Text(
                            'Expiry: ${_formatDate(expiryDate)}',
                            style: TextStyle(
                              fontSize: 14.sp,
                              color: isExpired ? Colors.red : Colors.grey[700],
                              fontWeight: isExpired
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          if (isExpired) ...[
                            SizedBox(width: 8.w),
                            Icon(Icons.warning, color: Colors.red, size: 16.sp),
                          ],
                        ],
                      ),
                      if (extraInfo != null) ...[
                        SizedBox(height: 4.h),
                        Text(
                          extraInfo,
                          style: TextStyle(
                            fontSize: 13.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
            if (attachmentUrl != null && attachmentUrl.isNotEmpty) ...[
              SizedBox(height: 12.h),
              Align(
                alignment: Alignment.centerRight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.share),
                      color: const Color(0xFF13b1f2),
                      tooltip: 'Share Document',
                      onPressed: () {
                        ShareHelper.shareDocument(
                          context,
                          url: attachmentUrl,
                          title: title,
                        );
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.visibility),
                      color: Colors.blue,
                      tooltip: 'View Document',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => DocumentViewerScreen(
                              attachmentUrl: attachmentUrl,
                              title: title,
                            ),
                          ),
                        );
                      },
                    ),
                    SizedBox(height: 4.h),
                    TextButton.icon(
                      onPressed: () => _launchUrl(attachmentUrl),
                      icon: const Icon(Icons.download),
                      label: const Text('Download Attachment'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.blue,
                        backgroundColor: Colors.blue.withValues(alpha: 0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(8.w),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(8.r),
            ),
            child: Icon(icon, size: 20.sp, color: Colors.blue[700]),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 16.sp,
                    color: Colors.black87,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Builds the Tafweed History timeline — all past and active authorizations
  /// for this driver across every vehicle, sorted newest issued-date first.
  Widget _buildTafweedHistorySection(BuildContext context) {
    final vehicles = context.watch<VehicleProvider>().vehicles;

    // Collect entries: { record, vehicle, isActive }
    final List<_TafweedHistoryEntry> entries = [];

    for (final vehicle in vehicles) {
      // Active records for this driver.
      final active = vehicle.tafweeds
              ?.where((t) => t.driverId == employee.id) ??
          [];
      for (final t in active) {
        entries.add(_TafweedHistoryEntry(record: t, vehicle: vehicle, isActive: true));
      }

      // Historical (archived) records for this driver.
      final history = vehicle.tafweedHistory
              ?.where((t) => t.driverId == employee.id) ??
          [];
      for (final t in history) {
        entries.add(_TafweedHistoryEntry(record: t, vehicle: vehicle, isActive: false));
      }
    }

    if (entries.isEmpty) return const SizedBox.shrink();

    // Sort newest issuedDate first.
    entries.sort((a, b) => b.record.issuedDate.compareTo(a.record.issuedDate));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: 24.h),
        Padding(
          padding: EdgeInsets.only(bottom: 12.h, left: 4.w),
          child: Row(
            children: [
              Icon(Icons.history, color: Colors.indigo[700], size: 20.sp),
              SizedBox(width: 8.w),
              Text(
                'Tafweed History',
                style: TextStyle(
                  fontSize: 18.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.indigo[900],
                ),
              ),
            ],
          ),
        ),
        ...entries.take(5).map((entry) => _buildHistoryEntry(entry)),
        if (entries.length > 5)
          Padding(
            padding: EdgeInsets.only(top: 8.h),
            child: TextButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TafweedHistoryViewAllScreen(
                      title: 'History: ${employee.fullName}',
                      id: employee.id,
                      type: TafweedHistoryType.employee,
                    ),
                  ),
                );
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.indigo[700],
                padding: EdgeInsets.symmetric(vertical: 12.h),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8.r),
                  side: BorderSide(color: Colors.indigo.withValues(alpha: 0.2)),
                ),
              ),
              child: const Text('View All History'),
            ),
          ),
      ],
    );
  }

  Widget _buildHistoryEntry(_TafweedHistoryEntry entry) {
    final now = DateTime.now();
    final isExpired = entry.record.expiryDate.isBefore(now);

    final Color statusColor;
    final String statusLabel;
    final IconData statusIcon;

    if (entry.isActive && !isExpired) {
      statusColor = Colors.green;
      statusLabel = 'Active';
      statusIcon = Icons.check_circle_outline;
    } else if (entry.isActive && isExpired) {
      statusColor = Colors.red;
      statusLabel = 'Expired';
      statusIcon = Icons.warning_amber_outlined;
    } else {
      statusColor = Colors.grey;
      statusLabel = 'Historical';
      statusIcon = Icons.archive_outlined;
    }

    return Card(
      elevation: 1,
      margin: EdgeInsets.only(bottom: 10.h),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12.r),
        side: BorderSide(
          color: statusColor.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Padding(
        padding: EdgeInsets.all(16.w),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Left accent bar
            Container(
              width: 4.w,
              height: 64.h,
              decoration: BoxDecoration(
                color: statusColor,
                borderRadius: BorderRadius.circular(4.r),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${entry.vehicle.make} ${entry.vehicle.model}',
                              style: TextStyle(
                                fontSize: 15.sp,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              'Plate: ${entry.vehicle.plateNumber}',
                              style: TextStyle(
                                fontSize: 13.sp,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Status badge
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8.w,
                          vertical: 4.h,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                          border: Border.all(
                            color: statusColor.withValues(alpha: 0.5),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(statusIcon, size: 13.sp, color: statusColor),
                            SizedBox(width: 4.w),
                            Text(
                              statusLabel,
                              style: TextStyle(
                                fontSize: 11.sp,
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 10.h),
                  // Date range row
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_outlined,
                        size: 13.sp,
                        color: Colors.grey[500],
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Issued: ${_formatDate(entry.record.issuedDate)}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          color: Colors.grey[700],
                        ),
                      ),
                      SizedBox(width: 16.w),
                      Icon(
                        Icons.event_outlined,
                        size: 13.sp,
                        color: isExpired ? Colors.red[400] : Colors.grey[500],
                      ),
                      SizedBox(width: 6.w),
                      Text(
                        'Expiry: ${_formatDate(entry.record.expiryDate)}',
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: isExpired
                              ? FontWeight.bold
                              : FontWeight.normal,
                          color: isExpired ? Colors.red : Colors.grey[700],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Simple data class for bundling a tafweed record with its vehicle context.
class _TafweedHistoryEntry {
  final TafweedRecord record;
  final VehicleEntity vehicle;
  final bool isActive;

  const _TafweedHistoryEntry({
    required this.record,
    required this.vehicle,
    required this.isActive,
  });
}
