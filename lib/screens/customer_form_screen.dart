import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/company/domain/entities/company_entity.dart';
import '../features/company/presentation/providers/company_provider.dart';
import '../features/customer/domain/entities/customer_entity.dart';
import '../features/customer/presentation/providers/customer_provider.dart';
import '../widgets/responsive_layout.dart';

class CustomerFormScreen extends StatefulWidget {
  final CustomerEntity? customer;

  const CustomerFormScreen({super.key, this.customer});

  @override
  State<CustomerFormScreen> createState() => _CustomerFormScreenState();
}

class _CustomerFormScreenState extends State<CustomerFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  // Company Selection
  final ValueNotifier<CompanyEntity?> _selectedCompany = ValueNotifier(null);
  final ValueNotifier<List<CompanyEntity>> _availableCompanies = ValueNotifier(
    [],
  );
  final ValueNotifier<bool> _isLoadingCompanies = ValueNotifier(true);

  // Case Code Selection
  final ValueNotifier<List<String>> _assignedCaseCodes = ValueNotifier([]);

  final ValueNotifier<bool> _isSaving = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    if (widget.customer != null) {
      final customer = widget.customer!;
      _nameController.text = customer.name;
      _phoneController.text = customer.phone;
      _assignedCaseCodes.value = List.from(customer.assignedCaseCodes);
    }
  }

  Future<void> _loadCompanies() async {
    try {
      if (mounted) {
        await context.read<CompanyProvider>().loadCompanies();
        if (!mounted) return;
        final companies = context.read<CompanyProvider>().companies;
        _availableCompanies.value = companies;
        _isLoadingCompanies.value = false;

        // If editing, set the selected company
        if (widget.customer != null && widget.customer!.companyId != null) {
          try {
            _selectedCompany.value = companies.firstWhere(
              (c) => c.id == widget.customer!.companyId,
            );
          } catch (e) {
            // Company might have been deleted
            debugPrint(
              'Associated company not found: ${widget.customer!.companyId}',
            );
          }
        }
      }
    } catch (e) {
      debugPrint('Error loading companies: $e');
      if (mounted) {
        _isLoadingCompanies.value = false;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _selectedCompany.dispose();
    _availableCompanies.dispose();
    _isLoadingCompanies.dispose();
    _assignedCaseCodes.dispose();
    _isSaving.dispose();
    super.dispose();
  }

  Future<void> _saveCustomer() async {
    if (_formKey.currentState!.validate() && !_isSaving.value) {
      _isSaving.value = true;

      try {
        final customer = CustomerEntity(
          id:
              widget.customer?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          phone: _phoneController.text.trim(),
          companyId: _selectedCompany.value?.id,
          companyName: _selectedCompany.value?.companyName,
          assignedCaseCodes: _selectedCompany.value?.usesCaseCode == true
              ? _assignedCaseCodes.value
              : [],
          createdAt: widget.customer?.createdAt ?? DateTime.now(),
        );

        debugPrint('Saving customer: ${customer.name}');

        if (mounted) {
          if (widget.customer != null) {
            await context.read<CustomerProvider>().updateCustomer(customer);
          } else {
            await context.read<CustomerProvider>().addCustomer(customer);
          }
        }

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
          _isSaving.value = false;
        }
      }
    }
  }

  void _toggleCaseCode(String code, bool? selected) {
    if (selected == true) {
      if (!_assignedCaseCodes.value.contains(code)) {
        _assignedCaseCodes.value = [..._assignedCaseCodes.value, code];
      }
    } else {
      _assignedCaseCodes.value = _assignedCaseCodes.value
          .where((c) => c != code)
          .toList();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.customer == null ? 'Add Customer' : 'Edit Customer'),
      ),
      body: ValueListenableBuilder<bool>(
        valueListenable: _isLoadingCompanies,
        builder: (context, isLoadingCompanies, _) {
          return isLoadingCompanies
              ? const Center(child: CircularProgressIndicator())
              : Form(
                  key: _formKey,
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 800),
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
                                  Expanded(
                                    child: _buildPersonalDetailsSection(),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(child: _buildCompanySection()),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              child: ValueListenableBuilder<bool>(
                                valueListenable: _isSaving,
                                builder: (context, isSaving, _) {
                                  return ElevatedButton(
                                    onPressed: isSaving ? null : _saveCustomer,
                                    style: ElevatedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 16,
                                      ),
                                    ),
                                    child: isSaving
                                        ? const SizedBox(
                                            height: 20,
                                            width: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Colors.white,
                                            ),
                                          )
                                        : const Text('Save Customer'),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
        },
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
            ValueListenableBuilder<List<CompanyEntity>>(
              valueListenable: _availableCompanies,
              builder: (context, availableCompanies, _) {
                return ValueListenableBuilder<CompanyEntity?>(
                  valueListenable: _selectedCompany,
                  builder: (context, selectedCompany, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<CompanyEntity>(
                          value: selectedCompany,
                          decoration: const InputDecoration(
                            labelText: 'Select Company',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.business),
                            helperText:
                                'Select "None" for independent travelers',
                          ),
                          items: [
                            const DropdownMenuItem<CompanyEntity>(
                              value: null,
                              child: Text('None / Independent'),
                            ),
                            ...availableCompanies.map((company) {
                              return DropdownMenuItem<CompanyEntity>(
                                value: company,
                                child: Text(company.companyName),
                              );
                            }),
                          ],
                          onChanged: (CompanyEntity? newValue) {
                            _selectedCompany.value = newValue;
                            // Clear assigned case codes if company changes or is removed
                            if (newValue == null || !newValue.usesCaseCode) {
                              _assignedCaseCodes.value = [];
                            }
                          },
                        ),

                        if (selectedCompany != null &&
                            selectedCompany.usesCaseCode) ...[
                          const SizedBox(height: 24),
                          const Divider(),
                          const SizedBox(height: 8),
                          Text(
                            'Assigned Case Codes (${selectedCompany.caseCodeLabel ?? 'Code'})',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          if (selectedCompany.caseCodes.isEmpty)
                            const Text(
                              'This company has no case codes defined.',
                              style: TextStyle(color: Colors.grey),
                            ),

                          ValueListenableBuilder<List<String>>(
                            valueListenable: _assignedCaseCodes,
                            builder: (context, assignedCaseCodes, _) {
                              return Column(
                                children: selectedCompany.caseCodes.map((code) {
                                  return CheckboxListTile(
                                    title: Text(code),
                                    value: assignedCaseCodes.contains(code),
                                    onChanged: (bool? value) =>
                                        _toggleCaseCode(code, value),
                                    dense: true,
                                    contentPadding: EdgeInsets.zero,
                                  );
                                }).toList(),
                              );
                            },
                          ),
                        ],
                      ],
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
