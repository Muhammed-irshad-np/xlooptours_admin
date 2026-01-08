import 'package:flutter/material.dart';
import '../models/customer_model.dart';
import '../models/company_model.dart';
import '../services/database_service.dart';
import '../widgets/responsive_layout.dart';

class CustomerFormScreen extends StatefulWidget {
  final CustomerModel? customer;

  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Company Selection
  CompanyModel? _selectedCompany;
  List<CompanyModel> _availableCompanies = [];
  bool _isLoadingCompanies = true;

  // Case Code Selection
  List<String> _assignedCaseCodes = [];

  final _databaseService = DatabaseService.instance;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    if (widget.customer != null) {
      final customer = widget.customer!;
      _nameController.text = customer.name;
      _phoneController.text = customer.phone;
      _assignedCaseCodes = List.from(customer.assignedCaseCodes);
    }
  }

  Future<void> _loadCompanies() async {
    try {
      final companies = await _databaseService.getAllCompanies();
      setState(() {
        _availableCompanies = companies;
        _isLoadingCompanies = false;

        // If editing, set the selected company
        if (widget.customer != null && widget.customer!.companyId != null) {
          try {
            _selectedCompany = companies.firstWhere(
              (c) => c.id == widget.customer!.companyId,
            );
          } catch (e) {
            // Company might have been deleted
            debugPrint(
              'Associated company not found: ${widget.customer!.companyId}',
            );
          }
        }
      });
    } catch (e) {
      debugPrint('Error loading companies: $e');
      setState(() => _isLoadingCompanies = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate() && !_isSaving) {
      setState(() => _isSaving = true);

      try {
        final customer = CustomerModel(
          id:
              widget.customer?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          companyId: _selectedCompany?.id,
          companyName: _selectedCompany?.companyName,
          assignedCaseCodes: _selectedCompany?.usesCaseCode == true
              ? _assignedCaseCodes
              : [],
          createdAt: widget.customer?.createdAt,
        );

        debugPrint('Saving customer: ${customer.name}');
        await _databaseService.insertCustomer(customer);

        if (mounted) {
          Navigator.pop(context, customer);
        }
      } catch (e) {
        debugPrint('Error saving customer: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving customer: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isSaving = false);
        }
      }
    }
  }

  void _toggleCaseCode(String code, bool? selected) {
    setState(() {
      if (selected == true) {
        if (!_assignedCaseCodes.contains(code)) {
          _assignedCaseCodes.add(code);
        }
      } else {
        _assignedCaseCodes.remove(code);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer == null ? 'Add Customer' : 'Edit Customer'),
      ),
      body: _isLoadingCompanies
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    ResponsiveLayout(
                      mobile: Column(
                        children: [
                          _buildPersonalDetailsSection(),
                          const SizedBox(height: 16),
                          _buildCompanySection(),
                        ],
                      ),
                      desktop: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildPersonalDetailsSection()),
                          const SizedBox(width: 16),
                          Expanded(child: _buildCompanySection()),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveCustomer,
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Text('Save Customer'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildPersonalDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Personal Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'Full Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.person),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter full name'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _phoneController,
              decoration: const InputDecoration(
                labelText: 'Mobile Number *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.phone),
              ),
              keyboardType: TextInputType.phone,
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter mobile number'
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompanySection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Company Association',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<CompanyModel>(
              value: _selectedCompany,
              decoration: const InputDecoration(
                labelText: 'Select Company',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
                helperText: 'Select "None" for independent travelers',
              ),
              items: [
                const DropdownMenuItem<CompanyModel>(
                  value: null,
                  child: Text('None / Independent'),
                ),
                ..._availableCompanies.map((company) {
                  return DropdownMenuItem<CompanyModel>(
                    value: company,
                    child: Text(company.companyName),
                  );
                }),
              ],
              onChanged: (CompanyModel? newValue) {
                setState(() {
                  _selectedCompany = newValue;
                  // Clear assigned case codes if company changes or is removed
                  if (newValue == null || !newValue.usesCaseCode) {
                    _assignedCaseCodes.clear();
                  }
                });
              },
            ),

            if (_selectedCompany != null && _selectedCompany!.usesCaseCode) ...[
              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 8),
              Text(
                'Assigned Case Codes (${_selectedCompany!.caseCodeLabel ?? 'Code'})',
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              if (_selectedCompany!.caseCodes.isEmpty)
                const Text(
                  'This company has no case codes defined.',
                  style: TextStyle(color: Colors.grey),
                ),

              ..._selectedCompany!.caseCodes.map((code) {
                return CheckboxListTile(
                  title: Text(code),
                  value: _assignedCaseCodes.contains(code),
                  onChanged: (bool? value) => _toggleCaseCode(code, value),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                );
              }),
            ],
          ],
        ),
      ),
    );
  }
}
