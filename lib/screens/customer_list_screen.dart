import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../models/customer_model.dart';
import '../models/notification_model.dart'; // Added
import '../services/database_service.dart';
import '../widgets/responsive_layout.dart';

class CustomerListScreen extends StatefulWidget {
  final Function(CustomerModel)? onCustomerSelected;
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
  final _databaseService = DatabaseService.instance;
  List<CustomerModel> _customers = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCustomers();
  }

  Future<void> _loadCustomers() async {
    setState(() => _isLoading = true);
    try {
      final customers = await _databaseService.getAllCustomers();
      if (mounted) {
        setState(() {
          _customers = customers;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading customers: $e')));
      }
    }
  }

  Future<void> _deleteCustomer(CustomerModel customer) async {
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
      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'Customer Deleted',
        message: 'Customer ${customer.name} has been deleted.',
        timestamp: DateTime.now(),
        type: NotificationType.system,
        relatedId: customer.id,
      );

      await _databaseService.deleteCustomer(customer.id);
      await _databaseService.insertNotification(notification);

      _loadCustomers();
    }
  }

  Future<void> _navigateToForm(CustomerModel? customer) async {
    final result = await context.push<CustomerModel?>(
      '/customers/form',
      extra: customer,
    );

    if (result != null) {
      _loadCustomers();
    }
  }

  Future<void> _toggleCustomerStatus(
    CustomerModel customer,
    bool isActive,
  ) async {
    final updatedCustomer = customer.copyWith(
      status: isActive ? 'ACTIVE' : 'INACTIVE',
    );
    await _databaseService.updateCustomer(updatedCustomer);
    _loadCustomers();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Customers'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToForm(null),
            tooltip: 'Add Customer',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _customers.isEmpty
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
                  const Text(
                    'No customers yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
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
                itemCount: _customers.length,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) =>
                    _buildCustomerCard(_customers[index]),
              ),
              desktop: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  childAspectRatio: 1.6,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _customers.length,
                itemBuilder: (context, index) =>
                    _buildCustomerCard(_customers[index]),
              ),
            ),
    );
  }

  Widget _buildCustomerCard(CustomerModel customer) {
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
                                    }
                                  },
                                  itemBuilder: (context) => [
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
                    activeColor: Colors.white,
                    activeTrackColor: Colors.green,
                    inactiveThumbColor: Colors.white,
                    inactiveTrackColor: Colors.grey[300],
                    trackOutlineColor: MaterialStateProperty.all(
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

  void _showDetails(CustomerModel customer) {
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
