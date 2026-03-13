import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import 'document_viewer_screen.dart';

import '../features/employee/domain/entities/employee_documents.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../features/vehicle/domain/entities/vehicle_entity.dart';

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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Employee Details'),
          elevation: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Personal', icon: Icon(Icons.person)),
              Tab(text: 'Documents & IDs', icon: Icon(Icons.folder_shared)),
              Tab(text: 'Others', icon: Icon(Icons.more_horiz)),
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

                // Tab 3: Others
                SingleChildScrollView(
                  padding: EdgeInsets.all(16.w),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (employee.phoneRechargeDate != null) ...[
                        _buildSectionHeader('Other Details'),
                        _buildOtherDetailsCard(),
                      ] else ...[
                        Padding(
                          padding: EdgeInsets.symmetric(vertical: 40.h),
                          child: Center(
                            child: Text(
                              'No other details available.',
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

  Widget _buildOtherDetailsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Padding(
        padding: EdgeInsets.all(20.w),
        child: Column(
          children: [
            _buildDetailRow(
              'Phone Recharge Date',
              _formatDate(employee.phoneRechargeDate),
              Icons.phone_android,
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
            extraInfo: employee.iqama!.insuranceExpiryDate != null
                ? 'Insurance Expiry: ${_formatDate(employee.iqama!.insuranceExpiryDate)}'
                : null,
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
          ),
        if (employee.saudiVisa != null)
          _buildVisaCard(context, 'Saudi Visa', employee.saudiVisa!),
        if (employee.bahrainVisa != null)
          _buildVisaCard(context, 'Bahrain Visa', employee.bahrainVisa!),
        if (employee.dubaiVisa != null)
          _buildVisaCard(context, 'Dubai Visa', employee.dubaiVisa!),
        if (employee.qatarVisa != null)
          _buildVisaCard(context, 'Qatar Visa', employee.qatarVisa!),
        if (employee.authorization != null)
          _buildDocumentCard(
            context,
            title: 'Authorization',
            icon: Icons.security,
            number: 'N/A',
            expiryDate: employee.authorization!.expiryDate,
            attachmentUrl: employee.authorization!.attachmentUrl,
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
        employee.passport == null &&
        employee.drivingLicense == null &&
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
}
