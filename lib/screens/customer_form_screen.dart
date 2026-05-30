import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:country_picker/country_picker.dart';
import 'package:flutter/services.dart';
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

  // Country Code
  String _countryCode = '+966';

  // Company Selection
  final ValueNotifier<CompanyEntity?> _selectedCompany = ValueNotifier(null);
  final ValueNotifier<List<CompanyEntity>> _availableCompanies = ValueNotifier(
    [],
  );
  final ValueNotifier<bool> _isLoadingCompanies = ValueNotifier(true);

  // Case Code Selection
  final ValueNotifier<List<String>> _assignedCaseCodes = ValueNotifier([]);
  final TextEditingController _newCaseCodeController = TextEditingController();

  final ValueNotifier<bool> _isSaving = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    _loadCompanies();
    _newCaseCodeController.addListener(_updateCaseCodePreview);
    if (widget.customer != null) {
      final customer = widget.customer!;
      _nameController.text = customer.name;
      
      // Parse phone number to extract country code and actual number
      if (customer.phone.contains(' ')) {
        final parts = customer.phone.split(' ');
        if (parts.length > 1) {
          _countryCode = parts[0];
          _phoneController.text = parts.sublist(1).join(' ');
        } else {
          _phoneController.text = customer.phone;
        }
      } else {
        _phoneController.text = customer.phone;
      }
      
      _assignedCaseCodes.value = List.from(customer.assignedCaseCodes);
    }
  }

  void _updateCaseCodePreview() {
    final text = _newCaseCodeController.text.toUpperCase();
    final selection = _newCaseCodeController.selection;

    final newText = text.replaceAllMapped(
      RegExp(r'([A-Z])([0-9])'),
      (match) => '${match.group(1)}-${match.group(2)}',
    );

    if (newText != _newCaseCodeController.text) {
      int newOffset = selection.baseOffset;
      if (newText.length > text.length && selection.isValid) {
        if (selection.baseOffset == text.length) {
          newOffset = newText.length;
        } else {
          newOffset += 1;
        }
      }

      _newCaseCodeController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: newOffset.clamp(0, newText.length),
        ),
      );
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
    _newCaseCodeController.dispose();
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
        final phoneWithCode = '$_countryCode ${_phoneController.text.trim()}';

        // Check if we need to update company with new case codes
        if (_selectedCompany.value != null && _selectedCompany.value!.usesCaseCode) {
          final inputCodes = _assignedCaseCodes.value;
          final currentCompanyCodes = Set<String>.from(_selectedCompany.value!.caseCodes);
          bool companyUpdated = false;

          for (var code in inputCodes) {
            if (!currentCompanyCodes.contains(code)) {
              currentCompanyCodes.add(code);
              companyUpdated = true;
            }
          }

          if (companyUpdated) {
            final updatedCompany = _selectedCompany.value!.copyWith(
              caseCodes: currentCompanyCodes.toList(),
            );
            if (mounted) {
              await context.read<CompanyProvider>().updateCompany(updatedCompany);
            }
          }
        }

        final customer = CustomerEntity(
          id:
              widget.customer?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          name: _nameController.text.trim(),
          phone: phoneWithCode,
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

  void _addCaseCode() {
    final code = _newCaseCodeController.text.trim();
    if (code.isNotEmpty) {
      if (!_assignedCaseCodes.value.contains(code)) {
        _assignedCaseCodes.value = [..._assignedCaseCodes.value, code];
        _newCaseCodeController.clear();
      } else {
        _newCaseCodeController.clear();
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
              decoration: InputDecoration(
                labelText: 'Mobile Number *',
                border: const OutlineInputBorder(),
                prefixIcon: InkWell(
                  onTap: () {
                    showCountryPicker(
                      context: context,
                      showPhoneCode: true,
                      onSelect: (Country country) {
                        setState(() {
                          _countryCode = '+${country.phoneCode}';
                        });
                      },
                      countryListTheme: CountryListThemeData(
                        borderRadius: BorderRadius.circular(20),
                        inputDecoration: const InputDecoration(
                          labelText: 'Search',
                          hintText: 'Start typing to search',
                          prefixIcon: Icon(Icons.search),
                          border: OutlineInputBorder(),
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          _countryCode,
                          style: const TextStyle(
                            fontSize: 15,
                            color: Color(0xFF334155),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_drop_down,
                          color: Colors.grey[600],
                          size: 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              keyboardType: TextInputType.phone,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
                          initialValue: selectedCompany,
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
                          TextFormField(
                            controller: _newCaseCodeController,
                            decoration: InputDecoration(
                              labelText: 'Add New Case Code',
                              border: const OutlineInputBorder(),
                              prefixIcon: const Icon(Icons.confirmation_number_outlined),
                              suffixIcon: IconButton(
                                icon: const Icon(Icons.add_circle, color: Colors.blue),
                                onPressed: _addCaseCode,
                              ),
                            ),
                            textCapitalization: TextCapitalization.characters,
                            onFieldSubmitted: (_) => _addCaseCode(),
                          ),
                          const SizedBox(height: 12),
                          if (selectedCompany.caseCodes.isEmpty)
                            const Text(
                              'This company has no predefined case codes.',
                              style: TextStyle(color: Colors.grey),
                            ),

                          ValueListenableBuilder<List<String>>(
                            valueListenable: _assignedCaseCodes,
                            builder: (context, assignedCaseCodes, _) {
                              // Combine company case codes with any new ones added during this session
                              final allCodes = Set<String>.from(selectedCompany.caseCodes)
                                ..addAll(assignedCaseCodes);
                                
                              return Column(
                                children: allCodes.map((code) {
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
