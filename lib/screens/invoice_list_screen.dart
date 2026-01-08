import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/invoice_model.dart';
import '../services/database_service.dart';
import 'pdf_preview_screen.dart';
import '../widgets/responsive_layout.dart';
import 'invoice_form_screen.dart';

class InvoiceListScreen extends StatefulWidget {
  const InvoiceListScreen({super.key});

  @override
  State<InvoiceListScreen> createState() => _InvoiceListScreenState();
}

class _InvoiceListScreenState extends State<InvoiceListScreen> {
  List<InvoiceModel> _invoices = [];
  bool _isLoading = true;
  int? _selectedMonth; // Null means "All"
  int? _selectedYear; // Null means "All"

  @override
  void initState() {
    super.initState();
    _loadInvoices();
  }

  Future<void> _loadInvoices() async {
    setState(() => _isLoading = true);
    try {
      final invoices = await DatabaseService.instance.getAllInvoices(
        month: _selectedMonth,
        year: _selectedYear,
      );
      setState(() {
        _invoices = invoices;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error loading invoices: $e')));
      }
    }
  }

  Future<void> _openInvoice(InvoiceModel invoice) async {
    // Navigate to PDF preview
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PDFPreviewScreen(invoice: invoice),
      ),
    );
  }

  Future<void> _editInvoice(InvoiceModel invoice) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            InvoiceFormScreen(invoiceToEdit: invoice), // Pass invoice to edit
      ),
    );
    _loadInvoices(); // Reload list after edit
  }

  Future<void> _deleteInvoice(InvoiceModel invoice) async {
    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Invoice'),
        content: Text(
          'Are you sure you want to delete invoice ${invoice.invoiceNumber}?',
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

    if (confirmed == true && invoice.id != null) {
      try {
        await DatabaseService.instance.deleteInvoice(invoice.id!);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Invoice deleted successfully')),
          );
          _loadInvoices(); // Reload the list
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error deleting invoice: $e')));
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'SR ',
      decimalDigits: 2,
    );
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Saved Invoices'),
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.filter_list),
                if (_selectedMonth != null || _selectedYear != null)
                  Positioned(
                    right: 0,
                    top: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.red,
                        shape: BoxShape.circle,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 8,
                        minHeight: 8,
                      ),
                    ),
                  ),
              ],
            ),
            onPressed: _showFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _invoices.isEmpty
          ? const Center(child: Text('No invoices found'))
          : ResponsiveLayout(
              mobile: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: _invoices.length,
                itemBuilder: (context, index) => _buildInvoiceItem(
                  _invoices[index],
                  currencyFormat,
                  dateFormat,
                ),
              ),
              desktop: GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 400,
                  childAspectRatio: 2.5,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                ),
                itemCount: _invoices.length,
                itemBuilder: (context, index) => _buildInvoiceItem(
                  _invoices[index],
                  currencyFormat,
                  dateFormat,
                ),
              ),
            ),
    );
  }

  void _showFilterDialog() {
    int? tempMonth = _selectedMonth;
    int? tempYear = _selectedYear;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Filter Invoices',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<int?>(
                    value: tempMonth,
                    decoration: const InputDecoration(
                      labelText: 'Month',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(12, (index) {
                      return DropdownMenuItem(
                        value: index + 1,
                        child: Text(
                          DateFormat('MMMM').format(DateTime(2024, index + 1)),
                        ),
                      );
                    }),
                    onChanged: (value) {
                      setModalState(() => tempMonth = value);
                    },
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<int?>(
                    value: tempYear,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(5, (index) {
                      final year = DateTime.now().year - 2 + index;
                      return DropdownMenuItem(
                        value: year,
                        child: Text(year.toString()),
                      );
                    }),
                    onChanged: (value) {
                      setModalState(() => tempYear = value);
                    },
                  ),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () {
                            setState(() {
                              _selectedMonth = null;
                              _selectedYear = null;
                            });
                            _loadInvoices();
                            Navigator.pop(context);
                          },
                          child: const Text('Reset'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: FilledButton(
                          onPressed: () {
                            setState(() {
                              _selectedMonth = tempMonth;
                              _selectedYear = tempYear;
                            });
                            _loadInvoices();
                            Navigator.pop(context);
                          },
                          child: const Text('Apply Filter'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildInvoiceItem(
    InvoiceModel invoice,
    NumberFormat currencyFormat,
    DateFormat dateFormat,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          invoice.invoiceNumber,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              '${dateFormat.format(invoice.date)} • ${invoice.company?.companyName ?? "Unknown Customer"}',
            ),
            Text(
              currencyFormat.format(invoice.grandTotal),
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _editInvoice(invoice);
                } else if (value == 'delete') {
                  _deleteInvoice(invoice);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: Row(
                    children: [
                      Icon(Icons.edit, size: 20),
                      SizedBox(width: 8),
                      Text('Edit'),
                    ],
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: Row(
                    children: [
                      Icon(Icons.delete, color: Colors.red, size: 20),
                      SizedBox(width: 8),
                      Text('Delete', style: TextStyle(color: Colors.red)),
                    ],
                  ),
                ),
              ],
            ),
            const Icon(Icons.arrow_forward_ios, size: 16),
          ],
        ),
        onTap: () => _openInvoice(invoice),
      ),
    );
  }
}
