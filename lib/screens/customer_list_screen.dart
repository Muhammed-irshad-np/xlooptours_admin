import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:url_launcher/url_launcher.dart';
import '../features/notifications/domain/entities/notification_entity.dart';
import '../features/notifications/presentation/providers/notification_provider.dart';
import '../features/customer/domain/entities/customer_entity.dart';
import '../features/customer/presentation/providers/customer_provider.dart';
import '../features/employee/presentation/providers/employee_provider.dart';
import '../features/employee/domain/entities/employee_entity.dart';
import '../widgets/responsive_layout.dart';

class CustomerListScreen extends StatefulWidget {
  final Function(CustomerEntity)? onCustomerSelected;
  final bool isSelectionMode;

  const CustomerListScreen({
    super.key,
    this.onCustomerSelected,
    this.isSelectionMode = false,
  });

  @override
  State<CustomerListScreen> createState() => _CustomerListScreenState();
}

class _CustomerListScreenState extends State<CustomerListScreen> {
  bool _showInactive = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CustomerProvider>().fetchAllCustomers();
    });
  }

  Future<void> _deleteCustomer(CustomerEntity customer) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Customer'),
        content: Text('Are you sure you want to delete ${customer.name}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Create Notification for Deletion
      final notification = NotificationEntity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Customer Deleted',
        message: 'Customer ${customer.name} has been deleted.',
        timestamp: DateTime.now(),
        type: NotificationType.system,
        relatedId: customer.id,
      );

      if (context.mounted) {
        await context.read<NotificationProvider>().insertNotification(
          notification,
        );

        try {
          await context.read<CustomerProvider>().deleteCustomer(customer.id);
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error deleting customer: $e')),
            );
          }
        }
      }
    }
  }

  Future<void> _navigateToForm(CustomerEntity? customer) async {
    final result = await context.push<CustomerEntity?>(
      '/customers/form',
      extra: customer,
    );

    if (result != null && context.mounted) {
      context.read<CustomerProvider>().fetchAllCustomers();
    }
  }

  Future<void> _recordFeedback(CustomerEntity customer) async {
    showDialog(
      context: context,
      builder: (context) => _RecordFeedbackDialog(customer: customer),
    );
  }

  Future<void> _toggleCustomerStatus(
    CustomerEntity customer,
    bool isActive,
  ) async {
    final updatedCustomer = customer.copyWith(
      status: isActive ? 'ACTIVE' : 'INACTIVE',
    );
    try {
      if (context.mounted) {
        await context.read<CustomerProvider>().updateCustomer(updatedCustomer);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error updating status: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CustomerProvider>(
      builder: (context, provider, child) {
        final filteredCustomers = provider.customers.where((c) {
          if (_showInactive) return c.status == 'INACTIVE';
          return true; // show all
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Customers'),
            actions: [
              Row(
                children: [
                  Text(
                    'Show Inactive',
                    style: TextStyle(fontSize: 10.sp, color: Colors.grey[600]),
                  ),
                  Transform.scale(
                    scale: 0.7,
                    child: Switch(
                      value: _showInactive,
                      onChanged: (val) {
                        setState(() {
                          _showInactive = val;
                        });
                      },
                    ),
                  ),
                ],
              ),
              IconButton(
                icon: const Icon(Icons.add),
                onPressed: () => _navigateToForm(null),
                tooltip: 'Add Customer',
              ),
            ],
          ),
          body: provider.isLoading
              ? const Center(child: CircularProgressIndicator())
              : filteredCustomers.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 64,
                        color: Colors.grey,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        provider.customers.isEmpty
                            ? 'No customers yet'
                            : 'No customers match the filter',
                        style: const TextStyle(fontSize: 18, color: Colors.grey),
                      ),
                      const SizedBox(height: 8),
                      if (provider.customers.isEmpty)
                        ElevatedButton.icon(
                          onPressed: () => _navigateToForm(null),
                          icon: const Icon(Icons.add),
                          label: const Text('Add First Customer'),
                        ),
                    ],
                  ),
                )
              : ResponsiveLayout(
                  mobile: ListView.builder(
                    itemCount: filteredCustomers.length,
                    padding: const EdgeInsets.all(8),
                    itemBuilder: (context, index) =>
                        _buildCustomerCard(filteredCustomers[index]),
                  ),
                  desktop: GridView.builder(
                    padding: const EdgeInsets.all(16),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 400,
                          childAspectRatio: 1.6,
                          crossAxisSpacing: 16,
                          mainAxisSpacing: 16,
                        ),
                    itemCount: filteredCustomers.length,
                    itemBuilder: (context, index) =>
                        _buildCustomerCard(filteredCustomers[index]),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildCustomerCard(CustomerEntity customer) {
    bool isActive = customer.status == 'ACTIVE';

    return Card(
      elevation: 0,
      color: Colors.white,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.withOpacity(0.2)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo/Icon
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.person_rounded,
                    color: Colors.blue,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),

                // Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              customer.name,
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          // Menu
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(
                                  Icons.remove_red_eye,
                                  color: Colors.blue,
                                  size: 20,
                                ),
                                onPressed: () => _showDetails(customer),
                                tooltip: 'View Details',
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                height: 24,
                                width: 24,
                                child: PopupMenuButton<String>(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(
                                    Icons.more_horiz,
                                    color: Colors.grey,
                                  ),
                                  onSelected: (value) {
                                    if (value == 'edit') {
                                      _navigateToForm(customer);
                                    } else if (value == 'delete') {
                                      _deleteCustomer(customer);
                                    } else if (value == 'record_feedback') {
                                      _recordFeedback(customer);
                                    }
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(
                                      value: 'record_feedback',
                                      child: Row(
                                        children: [
                                          Icon(Icons.rate_review_outlined, size: 20),
                                          SizedBox(width: 8),
                                          Text('Record Feedback'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Row(
                                        children: [
                                          Icon(Icons.edit_outlined, size: 20),
                                          SizedBox(width: 8),
                                          Text('Edit'),
                                        ],
                                      ),
                                    ),
                                    const PopupMenuItem(
                                      value: 'delete',
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.delete_outline,
                                            color: Colors.red,
                                            size: 20,
                                          ),
                                          SizedBox(width: 8),
                                          Text(
                                            'Delete',
                                            style: TextStyle(color: Colors.red),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customer.phone,
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[600],
                          height: 1.3,
                        ),
                      ),
                      if (customer.companyName != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 6.0),
                          child: Row(
                            children: [
                              Icon(
                                Icons.business,
                                size: 14,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  customer.companyName!,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[800],
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),

            const Spacer(),
            const Divider(height: 24),

            // Bottom Status Bar
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.green.withOpacity(0.1)
                        : Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: isActive ? Colors.green : Colors.grey,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        isActive ? 'Active' : 'Inactive',
                        style: TextStyle(
                          color: isActive
                              ? Colors.green[700]
                              : Colors.grey[600],
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  height: 24,
                  child: Switch(
                    value: isActive,
                    activeThumbColor: Colors.white,
                    activeTrackColor: Colors.green,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey[300],
                    trackOutlineColor: WidgetStateProperty.all(
                      Colors.transparent,
                    ),
                    onChanged: (val) => _toggleCustomerStatus(customer, val),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showDetails(CustomerEntity customer) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 500,
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Customer Details',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Divider(height: 32),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow('Name', customer.name, Icons.person),
                      _buildDetailRow(
                        'Email',
                        customer.email ?? 'N/A',
                        Icons.email,
                      ),
                      _buildDetailRow('Phone', customer.phone, Icons.phone),
                      _buildDetailRow(
                        'Company',
                        customer.companyName ?? 'N/A',
                        Icons.business,
                      ),
                      const Divider(),
                      if (customer.assignedCaseCodes.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Assigned Case Codes:',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.grey[600],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 8,
                                children: customer.assignedCaseCodes
                                    .map(
                                      (code) => Chip(
                                        label: Text(code),
                                        backgroundColor: Colors.blue
                                            .withOpacity(0.1),
                                      ),
                                    )
                                    .toList(),
                              ),
                            ],
                          ),
                        ),
                      _buildDetailRow(
                        'Status',
                        customer.status,
                        Icons.info_outline,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: Colors.grey),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
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

class _RecordFeedbackDialog extends StatefulWidget {
  final CustomerEntity customer;

  const _RecordFeedbackDialog({required this.customer});

  @override
  State<_RecordFeedbackDialog> createState() => _RecordFeedbackDialogState();
}

class _RecordFeedbackDialogState extends State<_RecordFeedbackDialog> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  EmployeeEntity? _selectedDriver;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<EmployeeProvider>().fetchAllEmployees();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _generateFeedbackUrl(EmployeeEntity selectedDriver) {
    final currentUrl = Uri.base.toString();
    final baseUrl = currentUrl.contains('#')
        ? currentUrl.substring(0, currentUrl.indexOf('#'))
        : currentUrl;
    final finalBaseUrl = baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl;

    final uri = Uri.parse(finalBaseUrl);
    final hostUrl = '${uri.scheme}://${uri.host}${uri.hasPort ? ":${uri.port}" : ""}';
    final clientNameEncoded = Uri.encodeComponent(widget.customer.name);
    final companyNameEncoded = widget.customer.companyName != null ? Uri.encodeComponent(widget.customer.companyName!) : '';
    final driverNameEncoded = Uri.encodeComponent(selectedDriver.fullName);
    return '$hostUrl/feedback?clientName=$clientNameEncoded&companyName=$companyNameEncoded&driverName=$driverNameEncoded';
  }

  Future<void> _shareToWhatsApp(EmployeeEntity driver, String url) async {
    String country = driver.countryCode ?? '';
    country = country.replaceAll(RegExp(r'[^0-9]'), '');
    if (country.isEmpty) country = '966'; // Default KSA country code
    String phone = driver.phoneNumber.replaceAll(RegExp(r'[^0-9]'), '');
    if (phone.startsWith('0')) {
      phone = phone.substring(1);
    }
    final cleanPhone = '$country$phone';

    final text = 'Hi ${driver.fullName},\n\nPlease ask the customer (${widget.customer.name}) to fill out their feedback using this link:\n\n$url';
    final whatsappUrl = 'https://wa.me/$cleanPhone?text=${Uri.encodeComponent(text)}';
    
    final Uri uri = Uri.parse(whatsappUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch WhatsApp link');
    }
  }

  Future<void> _shareViaEmail(EmployeeEntity driver, String url) async {
    final subject = Uri.encodeComponent('Feedback Link for Customer ${widget.customer.name}');
    final body = Uri.encodeComponent(
      'Hi ${driver.fullName},\n\nPlease share this link with the customer (${widget.customer.name}) to collect their feedback:\n\n$url\n\nBest regards,\nAdmin Team',
    );
    final emailUrl = 'mailto:${driver.email}?subject=$subject&body=$body';
    final Uri uri = Uri.parse(emailUrl);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      debugPrint('Could not launch Email link');
    }
  }

  Future<void> _copyToClipboard(String url) async {
    await Clipboard.setData(ClipboardData(text: url));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Feedback link copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_selectedDriver != null) {
      return _buildShareDialog(_selectedDriver!);
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 500.w,
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Record Feedback',
                  style: TextStyle(fontSize: 22.sp, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            Text(
              'Select a driver to generate a unique feedback link for ${widget.customer.name}. The customer will not need to select the driver, and the driver\'s name will be locked.',
              style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            ),
            Divider(height: 32.h),
            // Search field
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search driver by name...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _query = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                contentPadding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
              ),
              onChanged: (val) {
                setState(() {
                  _query = val.trim();
                });
              },
            ),
            SizedBox(height: 16.h),
            // Drivers List
            Flexible(
              child: Consumer<EmployeeProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: const CircularProgressIndicator(),
                      ),
                    );
                  }

                  final allEmployees = provider.employees;
                  final drivers = allEmployees.where((e) =>
                      e.isActive &&
                      (e.position.toLowerCase().contains('driver') ||
                          e.driverType != null)).toList();

                  final filteredDrivers = drivers.where((driver) {
                    return driver.fullName.toLowerCase().contains(_query.toLowerCase());
                  }).toList();

                  if (filteredDrivers.isEmpty) {
                    return Center(
                      child: Padding(
                        padding: EdgeInsets.all(24.w),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.person_off_outlined, size: 48.sp, color: Colors.grey[400]),
                            SizedBox(height: 8.h),
                            Text(
                              'No drivers found',
                              style: TextStyle(color: Colors.grey[600], fontSize: 15.sp),
                            ),
                          ],
                        ),
                      ),
                    );
                  }

                  return ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: MediaQuery.of(context).size.height * 0.4,
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: filteredDrivers.length,
                      separatorBuilder: (context, index) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final driver = filteredDrivers[index];
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: const Color(0xFF1C9E73).withOpacity(0.1),
                            backgroundImage: driver.imageUrl != null && driver.imageUrl!.isNotEmpty
                                ? NetworkImage(driver.imageUrl!)
                                : null,
                            child: driver.imageUrl == null || driver.imageUrl!.isEmpty
                                ? Text(
                                    driver.fullName.isNotEmpty ? driver.fullName[0].toUpperCase() : 'D',
                                    style: const TextStyle(
                                      color: Color(0xFF1B4E41),
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            driver.fullName,
                            style: TextStyle(
                              fontSize: 16.sp,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF111827),
                            ),
                          ),
                          subtitle: Text(
                            driver.phoneNumber,
                            style: TextStyle(color: Colors.grey[500], fontSize: 13.sp),
                          ),
                          onTap: () {
                            setState(() {
                              _selectedDriver = driver;
                            });
                          },
                        );
                      },
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

  Widget _buildShareDialog(EmployeeEntity driver) {
    final feedbackUrl = _generateFeedbackUrl(driver);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 450.w,
        padding: EdgeInsets.all(24.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Feedback Link Ready!',
                  style: TextStyle(
                    fontSize: 20.sp,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF13b1f2),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            // Driver Profile Info
            Container(
              padding: EdgeInsets.all(12.w),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.03),
                borderRadius: BorderRadius.circular(12.r),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 20.r,
                    backgroundColor: const Color(0xFF1C9E73).withOpacity(0.1),
                    backgroundImage: driver.imageUrl != null && driver.imageUrl!.isNotEmpty
                        ? NetworkImage(driver.imageUrl!)
                        : null,
                    child: driver.imageUrl == null || driver.imageUrl!.isEmpty
                        ? Text(
                            driver.fullName.isNotEmpty ? driver.fullName[0].toUpperCase() : 'D',
                            style: const TextStyle(
                              color: Color(0xFF1B4E41),
                              fontWeight: FontWeight.bold,
                            ),
                          )
                        : null,
                  ),
                  SizedBox(width: 12.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          driver.fullName,
                          style: TextStyle(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1A1A1A),
                          ),
                        ),
                        SizedBox(height: 2.h),
                        Text(
                          'Driver • ${driver.phoneNumber}',
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            // Link container box
            Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF7F6F2),
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      feedbackUrl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.sp,
                        color: Colors.grey[700],
                        fontFamily: 'monospace',
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  IconButton(
                    icon: Icon(Icons.copy, color: const Color(0xFF13b1f2), size: 18.sp),
                    onPressed: () => _copyToClipboard(feedbackUrl),
                    tooltip: 'Copy Feedback Link',
                    constraints: const BoxConstraints(),
                    padding: EdgeInsets.zero,
                  ),
                ],
              ),
            ),
            SizedBox(height: 20.h),
            // Share actions list
            InkWell(
              onTap: () => _shareToWhatsApp(driver, feedbackUrl),
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: const BoxDecoration(
                        color: Color(0xFFE8F5E9),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.chat_bubble_outline, color: const Color(0xFF25D366), size: 22.w),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        'Send to Driver via WhatsApp',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.h),
            InkWell(
              onTap: () => _shareViaEmail(driver, feedbackUrl),
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: const BoxDecoration(
                        color: Color(0xFFFFEBEE),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.email_outlined, color: Colors.redAccent, size: 22.w),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        'Share with Driver via Email',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            SizedBox(height: 10.h),
            InkWell(
              onTap: () => _copyToClipboard(feedbackUrl),
              borderRadius: BorderRadius.circular(12.r),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 12.h, horizontal: 16.w),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey[200]!),
                  borderRadius: BorderRadius.circular(12.r),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.w),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE3F2FD),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.link, color: const Color(0xFF13b1f2), size: 22.w),
                    ),
                    SizedBox(width: 16.w),
                    Expanded(
                      child: Text(
                        'Copy Link to Clipboard',
                        style: TextStyle(
                          fontSize: 14.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                  ],
                ),
              ),
            ),
            SizedBox(height: 24.h),
            // Dialog Footer navigation
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () {
                    setState(() {
                      _selectedDriver = null;
                    });
                  },
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Change Driver'),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.grey[700],
                  ),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF13b1f2),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                  ),
                  child: const Text('Done'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
