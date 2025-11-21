import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_model.dart';
import '../models/customer_model.dart';
import '../models/line_item_model.dart';
import 'customer_list_screen.dart';
import '../widgets/line_item_row_widget.dart';
import 'pdf_preview_screen.dart';

class InvoiceFormScreen extends StatefulWidget {
  const InvoiceFormScreen({super.key});

  @override
  State<InvoiceFormScreen> createState() => _InvoiceFormScreenState();
}

class _InvoiceFormScreenState extends State<InvoiceFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _invoiceNumberController = TextEditingController();
  final _contractRefController = TextEditingController();
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
  CustomerModel? _selectedCustomer;
  List<LineItemModel> _lineItems = [];

  @override
  void initState() {
    super.initState();
    _selectedPaymentTermsOption = _paymentTermsOptions.first;
    _paymentTermsController.text = _selectedPaymentTermsOption;
    // Add one empty line item by default
    _lineItems.add(LineItemModel(
      description: '',
      unit: '',
      unitType: 'LOT',
      referenceCode: '',
      subtotalAmount: 0.0,
      discountRate: 3.0,
      totalAmount: 0.0,
    ));
  }

  @override
  void dispose() {
    _invoiceNumberController.dispose();
    _contractRefController.dispose();
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
    }
  }

  Future<void> _selectCustomer() async {
    final customer = await Navigator.push<CustomerModel>(
      context,
      MaterialPageRoute(
        builder: (context) => const CustomerListScreen(),
      ),
    );

    if (customer != null) {
      setState(() => _selectedCustomer = customer);
    }
  }

  void _addLineItem() {
    setState(() {
      _lineItems.add(LineItemModel(
        description: '',
        unit: '',
        unitType: 'LOT',
        referenceCode: '',
        subtotalAmount: 0.0,
        discountRate: 3.0,
        totalAmount: 0.0,
      ));
    });
  }

  void _removeLineItem(int index) {
    setState(() {
      _lineItems.removeAt(index);
    });
  }

  void _updateLineItem(int index, LineItemModel item) {
    setState(() {
      _lineItems[index] = item;
    });
  }

  List<LineItemModel> _getActiveLineItems() {
    return _lineItems
        .where((item) => item.subtotalAmount > 0)
        .toList();
  }

  InvoiceModel _buildInvoice() {
    return InvoiceModel(
      date: _selectedDate,
      invoiceNumber: _invoiceNumberController.text.trim(),
      contractReference: _contractRefController.text.trim(),
      paymentTerms: _paymentTermsController.text.trim(),
      customer: _selectedCustomer,
      lineItems: _getActiveLineItems(),
    );
  }

  void _generatePDF() {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    if (_selectedCustomer == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a customer')),
      );
      return;
    }

    final validItems = _getActiveLineItems();
    if (validItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please add at least one line item')),
      );
      return;
    }

    final invoice = _buildInvoice();
    // Navigate to PDF preview/generation
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFPreviewScreen(invoice: invoice),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('yyyy-MM-dd');
    final currencyFormat = NumberFormat.currency(symbol: 'SR ', decimalDigits: 2);

    final invoice = _buildInvoice();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Invoice'),
        actions: [
          IconButton(
            icon: const Icon(Icons.picture_as_pdf),
            onPressed: _generatePDF,
            tooltip: 'Generate PDF',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // Invoice Details Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Invoice Details',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: _selectDate,
                            child: InputDecorator(
                              decoration: const InputDecoration(
                                labelText: 'Date',
                                border: OutlineInputBorder(),
                                prefixIcon: Icon(Icons.calendar_today),
                              ),
                              child: Text(dateFormat.format(_selectedDate)),
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            controller: _invoiceNumberController,
                            decoration: const InputDecoration(
                              labelText: 'Invoice Number *',
                              border: OutlineInputBorder(),
                              prefixIcon: Icon(Icons.numbers),
                            ),
                            validator: (value) {
                              if (value == null || value.trim().isEmpty) {
                                return 'Required';
                              }
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _contractRefController,
                      decoration: const InputDecoration(
                        labelText: 'Contract Reference',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.description),
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      value: _selectedPaymentTermsOption,
                      decoration: const InputDecoration(
                        labelText: 'Payment Terms',
                        border: OutlineInputBorder(),
                        prefixIcon: Icon(Icons.payment),
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
                                _selectedPaymentTermsOption = value;
                                _paymentTermsController.text = value;
                              });
                            },
                    ),
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Custom payment terms'),
                      value: _useCustomPaymentTerms,
                      onChanged: (value) {
                        setState(() {
                          _useCustomPaymentTerms = value ?? false;
                          if (_useCustomPaymentTerms) {
                            _paymentTermsController.clear();
                          } else {
                            _paymentTermsController.text =
                                _selectedPaymentTermsOption;
                          }
                        });
                      },
                      controlAffinity: ListTileControlAffinity.leading,
                    ),
                    if (_useCustomPaymentTerms) ...[
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _paymentTermsController,
                        decoration: const InputDecoration(
                          labelText: 'Custom Payment Terms',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.edit),
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
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Bill To Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Bill To',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        TextButton.icon(
                          onPressed: _selectCustomer,
                          icon: const Icon(Icons.person_add),
                          label: Text(_selectedCustomer == null ? 'Select Customer' : 'Change'),
                        ),
                      ],
                    ),
                    if (_selectedCustomer != null) ...[
                      const Divider(),
                      Text(
                        _selectedCustomer!.companyName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${_selectedCustomer!.streetAddress}, Building ${_selectedCustomer!.buildingNumber}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        '${_selectedCustomer!.district}, ${_selectedCustomer!.city}, ${_selectedCustomer!.postalCode}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        _selectedCustomer!.country,
                        style: const TextStyle(color: Colors.grey),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'VAT: ${_selectedCustomer!.vatRegisteredInKSA ? 'Registered in KSA' : 'Not registered in KSA'}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                      Text(
                        'Tax No: ${_selectedCustomer!.taxRegistrationNumber}',
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ] else
                      const Padding(
                        padding: EdgeInsets.all(16.0),
                        child: Text(
                          'No customer selected',
                          style: TextStyle(color: Colors.grey, fontStyle: FontStyle.italic),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Line Items Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Line Items',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add),
                          onPressed: _addLineItem,
                          tooltip: 'Add Line Item',
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(
                      _lineItems.length,
                      (index) => LineItemRowWidget(
                        item: _lineItems[index],
                        index: index,
                        onChanged: (item) => _updateLineItem(index, item),
                        onDelete: () => _removeLineItem(index),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Summary Section
            Card(
              color: Colors.grey[100],
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Summary',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    _buildSummaryRow('Subtotal:', currencyFormat.format(invoice.subtotalAmount)),
                    _buildSummaryRow('Total Discount:', '-${currencyFormat.format(invoice.totalDiscount)}'),
                    _buildSummaryRow('Total Amount:', currencyFormat.format(invoice.totalAmount)),
                    _buildSummaryRow('WHT 5%:', '-${currencyFormat.format(invoice.whtAmount)}'),
                    const Divider(),
                    _buildSummaryRow(
                      'Grand Total:',
                      currencyFormat.format(invoice.grandTotal),
                      isBold: true,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Generate PDF Button
            ElevatedButton.icon(
              onPressed: _generatePDF,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('Generate PDF'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
                backgroundColor: Colors.red,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSummaryRow(String label, String value, {bool isBold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
              fontSize: isBold ? 16 : 14,
            ),
          ),
        ],
      ),
    );
  }
}

