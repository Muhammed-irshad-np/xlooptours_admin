import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:xloop_invoice/services/database_service.dart'
    show DatabaseService;
import 'package:xloop_invoice/services/storage_service.dart';
import '../models/invoice_model.dart';
import '../models/company_model.dart';
import '../models/line_item_model.dart';
import 'companies_screen.dart';
import '../widgets/line_item_row_widget.dart';
import 'pdf_preview_screen.dart';
import '../widgets/responsive_layout.dart';

class InvoiceFormScreen extends StatefulWidget {
  final InvoiceModel? invoiceToEdit;

  const InvoiceFormScreen({super.key, this.invoiceToEdit});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _contractRefController = TextEditingController();
  final _taxRateController = TextEditingController(
    text: '15.0',
  ); // Updated default valid tax rate
  final _discountController = TextEditingController(text: '0.0');
  final _paymentTermsController = TextEditingController();
  final List<String> _paymentTermsOptions = const [
    'Advance 100% Cash',
    'Advance 100% Bank Transfer',
    '30 Days',
    '15 Days',
  ];
  String _selectedPaymentTermsOption = 'Advance 100% Cash';
  bool _useCustomPaymentTerms = false;

  DateTime _selectedDate = DateTime.now();
  CompanyModel? _selectedCompany;
  List<LineItemModel> _lineItems = [];
  final _storageService = StorageService();

  @override
  void initState() {
    super.initState();
    if (widget.invoiceToEdit != null) {
      _loadInvoice(widget.invoiceToEdit!);
    } else {
      _loadDraft();
    }

    // Add listeners for auto-save
    _contractRefController.addListener(_saveDraft);
    _taxRateController.addListener(_saveDraft);
    _discountController.addListener(_saveDraft);
    _paymentTermsController.addListener(_saveDraft);
  }

  Future<void> _loadDraft() async {
    final draft = await _storageService.getInvoiceDraft();
    if (draft != null && mounted) {
      _loadInvoice(draft);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft restored'),
          duration: Duration(seconds: 2),
        ),
      );
    } else {
      _resetForm();
    }
  }

  void _loadInvoice(InvoiceModel invoice) {
    setState(() {
      _selectedDate = invoice.date;
      _contractRefController.text = invoice.contractReference;
      _taxRateController.text = invoice.taxRate.toString();
      _discountController.text = invoice.discount.toString();
      _selectedCompany = invoice.company;
      _lineItems = List.from(invoice.lineItems);

      if (_paymentTermsOptions.contains(invoice.paymentTerms)) {
        _selectedPaymentTermsOption = invoice.paymentTerms;
        _paymentTermsController.text = invoice.paymentTerms;
        _useCustomPaymentTerms = false;
      } else {
        _useCustomPaymentTerms = true;
        _paymentTermsController.text = invoice.paymentTerms;
      }
    });
  }

  void _resetForm() {
    setState(() {
      _selectedDate = DateTime.now();
      _contractRefController.clear();
      _taxRateController.text = '15.0';
      _discountController.text = '0.0';
      _selectedCompany = null;
      _selectedPaymentTermsOption = _paymentTermsOptions.first;
      _paymentTermsController.text = _selectedPaymentTermsOption;
      _useCustomPaymentTerms = false;
      _lineItems = [
        LineItemModel(
          description: 'TRANSPORTATION CHARGES',
          unit: '1',
          unitType: 'LOT',
          referenceCode: '',
          subtotalAmount: 0.0,
          totalAmount: 0.0,
        ),
      ];
    });
  }

  Future<void> _saveDraft() async {
    if (widget.invoiceToEdit != null)
      return; // Don't save draft if editing existing invoice

    final invoice = InvoiceModel(
      date: _selectedDate,
      invoiceNumber: 'DRAFT',
      contractReference: _contractRefController.text,
      paymentTerms: _useCustomPaymentTerms
          ? _paymentTermsController.text
          : _selectedPaymentTermsOption,
      taxRate: double.tryParse(_taxRateController.text) ?? 5.0,
      discount: double.tryParse(_discountController.text) ?? 0.0,
      company: _selectedCompany,
      lineItems: _lineItems,
    );

    await _storageService.saveInvoiceDraft(invoice);
  }

  Future<void> _clearForm() async {
    await _storageService.clearInvoiceDraft();
    _resetForm();
    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Form cleared')));
    }
  }

  @override
  void dispose() {
    _contractRefController.removeListener(_saveDraft);
    _taxRateController.removeListener(_saveDraft);
    _discountController.removeListener(_saveDraft);
    _paymentTermsController.removeListener(_saveDraft);
    _contractRefController.dispose();
    _taxRateController.dispose();
    _discountController.dispose();
    _paymentTermsController.dispose();
    super.dispose();
  }

  Future<void> _selectDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
      _saveDraft();
    }
  }

  Future<void> _selectCompany() async {
    final company = await Navigator.push<CompanyModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const CompaniesScreen(isSelectionMode: true),
      ),
    );

    if (company != null) {
      setState(() => _selectedCompany = company);
      _saveDraft();
    }
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(
        LineItemModel(
          description: 'TRANSPORTATION CHARGES',
          unit: '1',
          unitType: 'LOT',
          referenceCode: '',
          subtotalAmount: 0.0,
          totalAmount: 0.0,
        ),
      );
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
    _saveDraft();
  }

  void _updateLineItem(int index, LineItemModel item) {
    setState(() {
      _lineItems[index] = item;
    });
    _saveDraft();
  }

  List<LineItemModel> _getActiveLineItems() {
    return _lineItems.where((item) => item.subtotalAmount > 0).toList();
  }

  void _previewInvoice() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_selectedCompany == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a company')));
      return;
    }

    final validItems = _getActiveLineItems();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item')),
      );
      return;
    }

    // Create invoice for preview only (no save)
    final invoice = InvoiceModel(
      id: 'preview-${DateTime.now().millisecondsSinceEpoch}', // Temporary ID for preview
      date: _selectedDate,
      invoiceNumber: 'PREVIEW', // Temporary number for preview
      contractReference: _contractRefController.text,
      paymentTerms: _useCustomPaymentTerms
          ? _paymentTermsController.text
          : _selectedPaymentTermsOption,
      taxRate: double.tryParse(_taxRateController.text) ?? 15.0,
      discount: double.tryParse(_discountController.text) ?? 0.0,
      company: _selectedCompany,
      lineItems: validItems,
    );

    // Navigate to PDF preview
    if (mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              PDFPreviewScreen(invoice: invoice, showActionButtons: false),
        ),
      );
    }
  }

  void _generatePDF() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_selectedCompany == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please select a company')));
      return;
    }

    final validItems = _getActiveLineItems();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item')),
      );
      return;
    }

    try {
      // Generate invoice number
      final invoiceNumber = await DatabaseService.instance
          .generateNewInvoiceNumber();

      final invoice = InvoiceModel(
        id: DateTime.now().millisecondsSinceEpoch
            .toString(), // Generate unique ID
        date: _selectedDate,
        invoiceNumber: invoiceNumber,
        contractReference: _contractRefController.text,
        paymentTerms: _useCustomPaymentTerms
            ? _paymentTermsController.text
            : _selectedPaymentTermsOption,
        taxRate: double.tryParse(_taxRateController.text) ?? 15.0,
        discount: double.tryParse(_discountController.text) ?? 0.0,
        company: _selectedCompany,
        lineItems: validItems,
      );

      // Save to database
      if (widget.invoiceToEdit != null) {
        // Update existing invoice
        final updatedInvoice = invoice.copyWith(id: widget.invoiceToEdit!.id);
        await DatabaseService.instance.updateInvoice(updatedInvoice);

        // Also update legacy local storage for resilience if needed, but DatabaseService handles cloud
      } else {
        // Insert new invoice
        await DatabaseService.instance.insertInvoice(invoice);
      }

      // Clear draft after successful generation
      await _storageService.clearInvoiceDraft();
      _resetForm();

      // Navigate to PDF preview
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PDFPreviewScreen(invoice: invoice),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error generating invoice: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('dd-MM-yyyy');
    final currencyFormat = NumberFormat.currency(
      symbol: 'SR ',
      decimalDigits: 2,
    );
    // Build invoice for preview (live)
    final invoice = InvoiceModel(
      date: _selectedDate,
      invoiceNumber: 'Preview',
      contractReference: _contractRefController.text.trim(),
      paymentTerms: _useCustomPaymentTerms
          ? _paymentTermsController.text.trim()
          : _selectedPaymentTermsOption,
      taxRate: double.tryParse(_taxRateController.text) ?? 15.0,
      discount: double.tryParse(_discountController.text) ?? 0.0,
      company: _selectedCompany,
      lineItems: _getActiveLineItems(),
    );

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black87,
        title: Text(
          widget.invoiceToEdit != null ? 'Edit Invoice' : 'Create Invoice',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.clear_all, color: Colors.red),
            label: const Text(
              'Clear All',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.w600),
            ),
            onPressed: _clearForm,
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1400),
            child: ResponsiveLayout(
              mobile: SingleChildScrollView(
                padding: const EdgeInsets.all(20.0),
                child: Column(
                  children: [
                    _buildInvoiceDetailsSection(dateFormat),
                    const SizedBox(height: 20),
                    _buildBillToSection(),
                    const SizedBox(height: 20),
                    _buildLineItemsSection(),
                    const SizedBox(height: 20),
                    _buildSummarySection(currencyFormat, invoice),
                    const SizedBox(height: 32),
                    _buildActionButtons(),
                  ],
                ),
              ),
              desktop: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Column: Form Fields
                  Expanded(
                    flex: 2,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          _buildSectionCard(
                            title: 'Invoice Details',
                            icon: Icons.receipt_long,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Column(
                                      children: [
                                        InkWell(
                                          onTap: _selectDate,
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          child: InputDecorator(
                                            decoration: _buildInputDecoration(
                                              'Date',
                                              Icons.calendar_today,
                                            ),
                                            child: Text(
                                              dateFormat.format(_selectedDate),
                                              style: const TextStyle(
                                                fontSize: 16,
                                              ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        TextFormField(
                                          controller: _contractRefController,
                                          decoration: _buildInputDecoration(
                                            'Contract Reference',
                                            Icons.description_outlined,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: TextFormField(
                                                controller: _taxRateController,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r'^\d*\.?\d*'),
                                                  ),
                                                ],
                                                decoration:
                                                    _buildInputDecoration(
                                                      'WHT Rate (%)',
                                                      Icons.percent,
                                                    ).copyWith(
                                                      hintText: '15.0',
                                                    ),
                                                validator: (value) {
                                                  if (value == null ||
                                                      value.isEmpty) {
                                                    return 'Required';
                                                  }
                                                  if (double.tryParse(value) ==
                                                      null) {
                                                    return 'Invalid';
                                                  }
                                                  return null;
                                                },
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: TextFormField(
                                                controller: _discountController,
                                                keyboardType:
                                                    const TextInputType.numberWithOptions(
                                                      decimal: true,
                                                    ),
                                                inputFormatters: [
                                                  FilteringTextInputFormatter.allow(
                                                    RegExp(r'^\d*\.?\d*'),
                                                  ),
                                                ],
                                                decoration:
                                                    _buildInputDecoration(
                                                      'Discount (%)',
                                                      Icons.money_off,
                                                    ).copyWith(hintText: '0.0'),
                                                onChanged: (value) =>
                                                    setState(() {}),
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 16),
                                        DropdownButtonFormField<String>(
                                          value: _selectedPaymentTermsOption,
                                          decoration: _buildInputDecoration(
                                            'Payment Terms',
                                            Icons.payment,
                                          ),
                                          items: _paymentTermsOptions
                                              .map(
                                                (option) => DropdownMenuItem(
                                                  value: option,
                                                  child: Text(option),
                                                ),
                                              )
                                              .toList(),
                                          onChanged: _useCustomPaymentTerms
                                              ? null
                                              : (value) {
                                                  if (value == null) return;
                                                  setState(() {
                                                    _selectedPaymentTermsOption =
                                                        value;
                                                    _paymentTermsController
                                                            .text =
                                                        value;
                                                  });
                                                },
                                        ),
                                        if (_useCustomPaymentTerms) ...[
                                          const SizedBox(height: 8),
                                          TextFormField(
                                            controller: _paymentTermsController,
                                            decoration: _buildInputDecoration(
                                              'Custom Payment Terms',
                                              Icons.edit_outlined,
                                            ),
                                            validator: (value) {
                                              if (_useCustomPaymentTerms &&
                                                  (value == null ||
                                                      value.trim().isEmpty)) {
                                                return 'Enter payment terms';
                                              }
                                              return null;
                                            },
                                          ),
                                        ],
                                        CheckboxListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: const Text(
                                            'Use custom payment terms',
                                          ),
                                          value: _useCustomPaymentTerms,
                                          activeColor: Theme.of(
                                            context,
                                          ).primaryColor,
                                          onChanged: (value) {
                                            setState(() {
                                              _useCustomPaymentTerms =
                                                  value ?? false;
                                              if (_useCustomPaymentTerms) {
                                                _paymentTermsController.clear();
                                              } else {
                                                _paymentTermsController.text =
                                                    _selectedPaymentTermsOption;
                                              }
                                            });
                                          },
                                          controlAffinity:
                                              ListTileControlAffinity.leading,
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _buildBillToSection(),
                          const SizedBox(height: 20),
                          _buildLineItemsSection(isDesktop: true),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  // Right Column: Summary & Actions
                  Expanded(
                    flex: 1,
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        children: [
                          _buildSummarySection(currencyFormat, invoice),
                          const SizedBox(height: 20),
                          _buildActionButtons(isVertical: true),
                        ],
                      ),
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

  Widget _buildInvoiceDetailsSection(DateFormat dateFormat) {
    return _buildSectionCard(
      title: 'Invoice Details',
      icon: Icons.receipt_long,
      children: [
        InkWell(
          onTap: _selectDate,
          borderRadius: BorderRadius.circular(12),
          child: InputDecorator(
            decoration: _buildInputDecoration('Date', Icons.calendar_today),
            child: Text(
              dateFormat.format(_selectedDate),
              style: const TextStyle(fontSize: 16),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _contractRefController,
          decoration: _buildInputDecoration(
            'Contract Reference',
            Icons.description_outlined,
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _taxRateController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: _buildInputDecoration(
                  'WHT Rate (%)',
                  Icons.percent,
                ).copyWith(hintText: '15.0'),
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Required';
                  }
                  if (double.tryParse(value) == null) {
                    return 'Invalid';
                  }
                  return null;
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: TextFormField(
                controller: _discountController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                ],
                decoration: _buildInputDecoration(
                  'Discount (%)',
                  Icons.money_off,
                ).copyWith(hintText: '0.0'),
                onChanged: (value) => setState(() {}),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          value: _selectedPaymentTermsOption,
          decoration: _buildInputDecoration('Payment Terms', Icons.payment),
          items: _paymentTermsOptions
              .map(
                (option) =>
                    DropdownMenuItem(value: option, child: Text(option)),
              )
              .toList(),
          onChanged: _useCustomPaymentTerms
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedPaymentTermsOption = value;
                    _paymentTermsController.text = value;
                  });
                },
        ),
        const SizedBox(height: 8),
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Use custom payment terms'),
          value: _useCustomPaymentTerms,
          activeColor: Theme.of(context).primaryColor,
          onChanged: (value) {
            setState(() {
              _useCustomPaymentTerms = value ?? false;
              if (_useCustomPaymentTerms) {
                _paymentTermsController.clear();
              } else {
                _paymentTermsController.text = _selectedPaymentTermsOption;
              }
            });
          },
          controlAffinity: ListTileControlAffinity.leading,
        ),
        if (_useCustomPaymentTerms) ...[
          const SizedBox(height: 8),
          TextFormField(
            controller: _paymentTermsController,
            decoration: _buildInputDecoration(
              'Custom Payment Terms',
              Icons.edit_outlined,
            ),
            validator: (value) {
              if (_useCustomPaymentTerms &&
                  (value == null || value.trim().isEmpty)) {
                return 'Enter payment terms';
              }
              return null;
            },
          ),
        ],
      ],
    );
  }

  Widget _buildLineItemsSection({bool isDesktop = false}) {
    return _buildSectionCard(
      title: 'Line Items',
      icon: Icons.list_alt,
      action: FilledButton.icon(
        onPressed: _addLineItem,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Add Item'),
        style: FilledButton.styleFrom(
          visualDensity: VisualDensity.compact,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
      children: [
        if (_lineItems.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.all(32.0),
              child: Text('No items added yet'),
            ),
          )
        else
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth > 600;
              final itemWidth = isWide
                  ? (constraints.maxWidth - 16) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: List.generate(_lineItems.length, (index) {
                  return SizedBox(
                    width: itemWidth,
                    child: LineItemRowWidget(
                      item: _lineItems[index],
                      index: index,
                      onChanged: (item) => _updateLineItem(index, item),
                      onDelete: () => _removeLineItem(index),
                    ),
                  );
                }),
              );
            },
          ),
        if (_lineItems.isNotEmpty) ...[
          const SizedBox(height: 16),
          Center(
            child: OutlinedButton.icon(
              onPressed: _addLineItem,
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Add Another Item'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildBillToSection() {
    return _buildSectionCard(
      title: 'Bill To',
      icon: Icons.business,
      action: TextButton.icon(
        onPressed: _selectCompany,
        icon: const Icon(Icons.business, size: 20),
        label: Text(_selectedCompany == null ? 'Select Company' : 'Change'),
        style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
      ),
      children: [
        if (_selectedCompany != null) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _selectedCompany!.companyName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                _buildCustomerInfoRow(
                  Icons.location_on_outlined,
                  '${_selectedCompany!.streetAddress}, Building ${_selectedCompany!.buildingNumber}',
                ),
                _buildCustomerInfoRow(
                  Icons.map_outlined,
                  '${_selectedCompany!.district}, ${_selectedCompany!.city}, ${_selectedCompany!.postalCode}',
                ),
                _buildCustomerInfoRow(
                  Icons.public,
                  _selectedCompany!.country ?? '',
                ),
                const Divider(height: 24),
                if (_selectedCompany!.email != null &&
                    _selectedCompany!.email!.isNotEmpty)
                  _buildCustomerInfoRow(
                    Icons.email_outlined,
                    _selectedCompany!.email!,
                  ),
                _buildCustomerInfoRow(
                  Icons.numbers,
                  'Tax No: ${_selectedCompany!.taxRegistrationNumber ?? 'N/A'}',
                ),
                if (_selectedCompany!.usesCaseCode)
                  Padding(
                    padding: const EdgeInsets.only(top: 8.0),
                    child: _buildCustomerInfoRow(
                      Icons.work_outline,
                      'Uses ${_selectedCompany!.caseCodeLabel ?? 'Case Codes'}',
                    ),
                  ),
              ],
            ),
          ),
        ] else
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 24.0),
              child: Column(
                children: [
                  Icon(
                    Icons.business_outlined,
                    size: 48,
                    color: Colors.grey[300],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'No company selected',
                    style: TextStyle(color: Colors.grey[500]),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildSummarySection(
    NumberFormat currencyFormat,
    InvoiceModel invoice,
  ) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Payment Summary',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
            _buildSummaryRow(
              'Subtotal',
              currencyFormat.format(invoice.subtotalAmount),
            ),
            _buildSummaryRow(
              'Total Discount',
              '-${currencyFormat.format(invoice.totalDiscount)}',
              color: Colors.orange[700],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8.0),
              child: Divider(),
            ),
            _buildSummaryRow(
              'Total Amount',
              currencyFormat.format(invoice.totalAmount),
              isBold: true,
            ),
            _buildSummaryRow(
              'WHT (${invoice.taxRate}%)',
              currencyFormat.format(invoice.taxAmount),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const Text(
                      'Grand Total',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currencyFormat.format(invoice.grandTotal),
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButtons({bool isVertical = false}) {
    final buttons = [
      OutlinedButton.icon(
        onPressed: _previewInvoice,
        icon: const Icon(Icons.visibility_outlined),
        label: const Text(
          'Preview',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: const BorderSide(color: Colors.black87),
          foregroundColor: Colors.black87,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      const SizedBox(width: 16, height: 16),
      ElevatedButton.icon(
        onPressed: _generatePDF,
        icon: const Icon(Icons.check_circle_outline),
        label: const Text(
          'Generate Invoice',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          backgroundColor: Colors.black87,
          foregroundColor: Colors.white,
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    ];

    if (isVertical) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: buttons,
      );
    }

    return Row(
      children: [
        Expanded(child: buttons[0]),
        const SizedBox(width: 16),
        Expanded(child: buttons[2]),
      ],
    );
  }

  Widget _buildSectionCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? action,
  }) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Icon(icon, color: Colors.blue[700], size: 24),
                    const SizedBox(width: 12),
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                if (action != null) action,
              ],
            ),
            const SizedBox(height: 20),
            ...children,
          ],
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, size: 20, color: Colors.grey[600]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
    );
  }

  Widget _buildCustomerInfoRow(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: Colors.grey[600]),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.grey[700], fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryRow(
    String label,
    String value, {
    bool isBold = false,
    Color? color,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
              color: Colors.grey[700],
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.w500,
              fontSize: isBold ? 16 : 14,
              color: color ?? Colors.black87,
            ),
          ),
        ],
      ),
    );
  }
}
