import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../features/company/domain/entities/company_entity.dart';
import '../features/company/presentation/providers/company_provider.dart';
import '../widgets/responsive_layout.dart';

class CompanyFormScreen extends StatefulWidget {
  final CompanyEntity? company;

  const CompanyFormScreen({super.key, this.company});

  @override
  State<CompanyFormScreen> createState() => _CompanyFormScreenState();
}

class _CompanyFormScreenState extends State<CompanyFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _companyNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _countryController = TextEditingController();
  final _taxRegController = TextEditingController();
  final _cityController = TextEditingController();
  final _streetController = TextEditingController();
  final _buildingNumberController = TextEditingController();
  final _districtController = TextEditingController();
  final _addressAdditionalController = TextEditingController();
  final _postalCodeController = TextEditingController();

  // Case Code Logic
  final ValueNotifier<bool> _usesCaseCode = ValueNotifier(false);
  final _caseCodeLabelController = TextEditingController(text: 'Case Code');
  final _newCaseCodeController = TextEditingController();
  final ValueNotifier<List<String>> _caseCodes = ValueNotifier([]);

  final ValueNotifier<bool> _vatRegisteredInKSA = ValueNotifier(false);

  final ValueNotifier<bool> _isSaving = ValueNotifier(false);

  @override
  void initState() {
    super.initState();
    if (widget.company != null) {
      final company = widget.company!;
      _companyNameController.text = company.companyName;
      _emailController.text = company.email ?? '';
      _countryController.text = company.country ?? '';
      _vatRegisteredInKSA.value = company.vatRegisteredInKSA;
      _taxRegController.text = company.taxRegistrationNumber ?? '';
      _cityController.text = company.city ?? '';
      _streetController.text = company.streetAddress ?? '';
      _buildingNumberController.text = company.buildingNumber ?? '';
      _districtController.text = company.district ?? '';
      _addressAdditionalController.text = company.addressAdditionalNumber ?? '';
      _postalCodeController.text = company.postalCode ?? '';

      // Load Case Code settings
      _usesCaseCode.value = company.usesCaseCode;
      if (company.caseCodeLabel != null) {
        _caseCodeLabelController.text = company.caseCodeLabel!;
      }
      _caseCodes.value = List.from(company.caseCodes);
    }
  }

  @override
  void dispose() {
    _companyNameController.dispose();
    _emailController.dispose();
    _countryController.dispose();
    _taxRegController.dispose();
    _cityController.dispose();
    _streetController.dispose();
    _buildingNumberController.dispose();
    _districtController.dispose();
    _addressAdditionalController.dispose();
    _postalCodeController.dispose();
    _caseCodeLabelController.dispose();
    _newCaseCodeController.dispose();
    _usesCaseCode.dispose();
    _vatRegisteredInKSA.dispose();
    _isSaving.dispose();
    _caseCodes.dispose();
    super.dispose();
  }

  Future<void> _saveCompany() async {
    if (_formKey.currentState!.validate() && !_isSaving.value) {
      _isSaving.value = true;

      try {
        final company = CompanyEntity(
          id:
              widget.company?.id ??
              DateTime.now().millisecondsSinceEpoch.toString(),
          companyName: _companyNameController.text.trim(),
          email: _emailController.text.trim().isEmpty
              ? null
              : _emailController.text.trim(),
          country: _countryController.text.trim().isEmpty
              ? null
              : _countryController.text.trim(),
          vatRegisteredInKSA: _vatRegisteredInKSA.value,
          taxRegistrationNumber: _taxRegController.text.trim().isEmpty
              ? null
              : _taxRegController.text.trim(),
          city: _cityController.text.trim().isEmpty
              ? null
              : _cityController.text.trim(),
          streetAddress: _streetController.text.trim().isEmpty
              ? null
              : _streetController.text.trim(),
          buildingNumber: _buildingNumberController.text.trim().isEmpty
              ? null
              : _buildingNumberController.text.trim(),
          district: _districtController.text.trim().isEmpty
              ? null
              : _districtController.text.trim(),
          addressAdditionalNumber:
              _addressAdditionalController.text.trim().isEmpty
              ? null
              : _addressAdditionalController.text.trim(),
          postalCode: _postalCodeController.text.trim().isEmpty
              ? null
              : _postalCodeController.text.trim(),
          // New Fields
          usesCaseCode: _usesCaseCode.value,
          caseCodeLabel: _usesCaseCode.value
              ? _caseCodeLabelController.text.trim()
              : null,
          caseCodes: _usesCaseCode.value ? _caseCodes.value : [],
          createdAt:
              widget.company?.createdAt ??
              DateTime.now(), // Preserve creation time if editing
        );

        debugPrint('Saving company: ${company.companyName}');
        bool success = false;
        if (mounted) {
          if (widget.company != null) {
            success = await context.read<CompanyProvider>().updateCompany(
              company,
            );
          } else {
            success = await context.read<CompanyProvider>().insertCompany(
              company,
            );
          }
        }

        if (mounted && success) {
          Navigator.pop(context, company);
        } else if (mounted && !success) {
          final error = context.read<CompanyProvider>().errorMessage;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to save: $error'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        debugPrint('Error saving company: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error saving company: $e'),
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
      if (!_caseCodes.value.contains(code)) {
        _caseCodes.value = [..._caseCodes.value, code];
        _newCaseCodeController.clear();
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Case code already exists')),
        );
      }
    }
  }

  void _removeCaseCode(String code) {
    _caseCodes.value = _caseCodes.value.where((c) => c != code).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.company == null ? 'Add Company' : 'Edit Company'),
      ),
      body: Form(
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
                        _buildBusinessDetailsSection(),
                        const SizedBox(height: 16),
                        _buildCaseCodeSection(),
                        const SizedBox(height: 16),
                        _buildAddressSection(),
                      ],
                    ),
                    desktop: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildBusinessDetailsSection(),
                              const SizedBox(height: 16),
                              _buildCaseCodeSection(),
                            ],
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(child: _buildAddressSection()),
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
                          onPressed: isSaving ? null : _saveCompany,
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 16),
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
                              : const Text('Save Company'),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBusinessDetailsSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Business Details',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _companyNameController,
              decoration: const InputDecoration(
                labelText: 'Company Name *',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.business),
              ),
              validator: (value) => value == null || value.trim().isEmpty
                  ? 'Enter company name'
                  : null,
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.email),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            const Text(
              'VAT Treatment',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            ValueListenableBuilder<bool>(
              valueListenable: _vatRegisteredInKSA,
              builder: (context, vatRegisteredInKSA, _) {
                return Column(
                  children: [
                    RadioListTile<bool>(
                      title: const Text('Not VAT registered in KSA'),
                      value: false,
                      groupValue: vatRegisteredInKSA,
                      onChanged: (val) => _vatRegisteredInKSA.value = val!,
                    ),
                    RadioListTile<bool>(
                      title: const Text('VAT registered in KSA'),
                      value: true,
                      groupValue: vatRegisteredInKSA,
                      onChanged: (val) => _vatRegisteredInKSA.value = val!,
                    ),
                    if (vatRegisteredInKSA)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: TextFormField(
                          controller: _taxRegController,
                          decoration: const InputDecoration(
                            labelText: 'Tax Registration Number',
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.confirmation_number),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCaseCodeSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ValueListenableBuilder<bool>(
          valueListenable: _usesCaseCode,
          builder: (context, usesCaseCode, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Case Code Settings',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Switch(
                      value: usesCaseCode,
                      onChanged: (val) => _usesCaseCode.value = val,
                    ),
                  ],
                ),
                if (usesCaseCode) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _caseCodeLabelController,
                    decoration: const InputDecoration(
                      labelText: 'Case Code Label (e.g. "Project Code")',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _newCaseCodeController,
                          decoration: const InputDecoration(
                            labelText: 'Add Case Code',
                            hintText: 'e.g. OW-A12',
                            border: OutlineInputBorder(),
                          ),
                          onFieldSubmitted: (_) => _addCaseCode(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton.filled(
                        onPressed: _addCaseCode,
                        icon: const Icon(Icons.add),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  ValueListenableBuilder<List<String>>(
                    valueListenable: _caseCodes,
                    builder: (context, caseCodes, _) {
                      if (caseCodes.isEmpty) {
                        return const Text(
                          'No case codes added yet.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontStyle: FontStyle.italic,
                          ),
                        );
                      }
                      return Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: caseCodes.map((code) {
                          return Chip(
                            label: Text(code),
                            onDeleted: () => _removeCaseCode(code),
                          );
                        }).toList(),
                      );
                    },
                  ),
                ] else ...[
                  const Text(
                    'Enable this if this company uses Case Codes or Project Codes for billing.',
                    style: TextStyle(color: Colors.grey),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildAddressSection() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Address',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _countryController,
              decoration: const InputDecoration(
                labelText: 'Country',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.flag),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _cityController,
              decoration: const InputDecoration(
                labelText: 'City',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.location_city),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _streetController,
              decoration: const InputDecoration(
                labelText: 'Street address',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.streetview),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _buildingNumberController,
              decoration: const InputDecoration(
                labelText: 'Building number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.home),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _districtController,
              decoration: const InputDecoration(
                labelText: 'District',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.map),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _addressAdditionalController,
              decoration: const InputDecoration(
                labelText: 'Address additional number',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.add_location_alt),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _postalCodeController,
              decoration: const InputDecoration(
                labelText: 'Postal code',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.local_post_office),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
