import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../models/company_model.dart';
import '../services/database_service.dart';
import '../widgets/responsive_layout.dart';

class CompaniesScreen extends StatefulWidget {
  final Function(CompanyModel)? onCompanySelected;
  final bool isSelectionMode;

  const CompaniesScreen({
    super.key,
    this.onCompanySelected,
    this.isSelectionMode = false,
  });

  @override
  State<CompaniesScreen> createState() => _CompaniesScreenState();
}

class _CompaniesScreenState extends State<CompaniesScreen> {
  final _databaseService =
      DatabaseService.instance; // Use DatabaseService directly
  List<CompanyModel> _companies = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
  }

  Future<void> _loadCompanies() async {
    setState(() => _isLoading = true);
    try {
      final companies = await _databaseService.getAllCompanies();
      if (mounted) {
        setState(() {
          _companies = companies;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading companies: $e')));
      }
    }
  }

  Future<void> _deleteCompany(CompanyModel company) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Company'),
        content: Text(
          'Are you sure you want to delete ${company.companyName}?',
        ),
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
      await _databaseService.deleteCompany(company.id);
      _loadCompanies();
    }
  }

  Future<void> _toggleCompanyStatus(CompanyModel company, bool isActive) async {
    final updatedCompany = company.copyWith(
      status: isActive ? 'ACTIVE' : 'INACTIVE',
    );
    await _databaseService.updateCompany(updatedCompany);
    _loadCompanies();
  }

  Future<void> _navigateToForm(CompanyModel? company) async {
    final result = await context.push<CompanyModel>(
      '/companies/form',
      extra: company,
    );

    if (result != null) {
      _loadCompanies();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Companies'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _navigateToForm(null),
            tooltip: 'Add Company',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _companies.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.business, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  const Text(
                    'No companies yet',
                    style: TextStyle(fontSize: 18, color: Colors.grey),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => _navigateToForm(null),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First Company'),
                  ),
                ],
              ),
            )
          : ResponsiveLayout(
              mobile: ListView.builder(
                itemCount: _companies.length,
                padding: const EdgeInsets.all(8),
                itemBuilder: (context, index) =>
                    _buildCompanyCard(_companies[index]),
              ),
              desktop: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  childAspectRatio: 1.3,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _companies.length,
                itemBuilder: (context, index) =>
                    _buildCompanyCard(_companies[index]),
              ),
            ),
    );
  }

  Widget _buildCompanyCard(CompanyModel company) {
    bool isActive = company.status == 'ACTIVE';

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          if (widget.isSelectionMode) {
            Navigator.pop(context, company);
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Left: Logo
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.business,
                      color: Colors.blue,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Middle: Company Info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          company.companyName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (company.city != null ||
                            company.streetAddress != null)
                          Text(
                            '${company.streetAddress ?? ''}${company.streetAddress != null && company.city != null ? ', ' : ''}${company.city ?? ''}',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        if (company.usesCaseCode)
                          Padding(
                            padding: const EdgeInsets.only(top: 4.0),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                '${company.caseCodes.length} Case Codes',
                                style: const TextStyle(
                                  fontSize: 10,
                                  color: Colors.deepOrange,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Top Right: Menu
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.remove_red_eye,
                          color: Colors.blue,
                        ),
                        onPressed: () => _showDetails(company),
                        tooltip: 'View Details',
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert),
                        onSelected: (value) async {
                          if (value == 'edit') {
                            _navigateToForm(company);
                          } else if (value == 'delete') {
                            _deleteCompany(company);
                          } else if (value == 'copy_link') {
                            final String link =
                                '${Uri.base.origin}/register?companyId=${company.id}';

                            await Clipboard.setData(ClipboardData(text: link));
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Registration link copied to clipboard!',
                                  ),
                                ),
                              );
                            }
                          }
                        },
                        itemBuilder: (context) => [
                          const PopupMenuItem(
                            value: 'copy_link',
                            child: Row(
                              children: [
                                Icon(Icons.link, size: 20),
                                SizedBox(width: 8),
                                Text('Copy Link'),
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
                          const PopupMenuItem(
                            value: 'delete',
                            child: Row(
                              children: [
                                Icon(Icons.delete, color: Colors.red, size: 20),
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
                    ],
                  ),
                ],
              ),

              const Spacer(),
              const Divider(height: 24),

              // Bottom Section: Status Toggle
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
                      onChanged: (val) => _toggleCompanyStatus(company, val),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showDetails(CompanyModel company) {
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
                    'Company Details',
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
                      _buildDetailRow(
                        'Company Name',
                        company.companyName,
                        Icons.business,
                      ),
                      if (company.email != null)
                        _buildDetailRow('Email', company.email!, Icons.email),
                      if (company.city != null)
                        _buildDetailRow(
                          'City',
                          company.city!,
                          Icons.location_city,
                        ),
                      if (company.taxRegistrationNumber != null)
                        _buildDetailRow(
                          'VAT Number',
                          company.taxRegistrationNumber!,
                          Icons.receipt,
                        ),
                      if (company.streetAddress != null)
                        _buildDetailRow(
                          'Address',
                          company.streetAddress!,
                          Icons.location_on,
                        ),
                      if (company.usesCaseCode)
                        _buildDetailRow(
                          'Case Codes',
                          company.caseCodes.join(', '),
                          Icons.list,
                        ),
                      _buildDetailRow(
                        'Status',
                        company.status,
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
