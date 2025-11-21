import 'package:flutter/material.dart';
import 'invoice_form_screen.dart';
import 'customer_list_screen.dart';
import 'pdf_preview_screen.dart';
import '../models/invoice_model.dart';
import '../models/customer_model.dart';
import '../models/line_item_model.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  // Generate demo invoice for testing
  InvoiceModel _generateDemoInvoice() {
    final demoCustomer = CustomerModel(
      id: 'demo-001',
      companyName: 'ABC Company Ltd.',
      country: 'Kingdom of Bahrain',
      vatRegisteredInKSA: true,
      taxRegistrationNumber: '100200300400',
      city: 'Manama',
      streetAddress: '123 Business Street',
      buildingNumber: '10',
      district: 'Financial District',
      addressAdditionalNumber: 'Suite 5A',
      postalCode: '12345',
    );

    final lineItems = [
      LineItemModel(
        description: 'TRANSPORTATION CHARGES',
        referenceCode: 'ARSA-0041',
        unit: '1',
        unitType: 'LOT',
        subtotalAmount: 1000.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(1000.00, 3.0),
      ),
      LineItemModel(
        description: 'TRANSPORTATION CHARGES',
        referenceCode: 'ARSA-0042',
        unit: '2',
        unitType: 'LOT',
        subtotalAmount: 1500.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(1500.00, 3.0),
      ),
      LineItemModel(
        description: 'TRANSPORTATION CHARGES',
        referenceCode: 'ARSA-0043',
        unit: '3',
        unitType: 'LOT',
        subtotalAmount: 2000.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(2000.00, 3.0),
      ),
      LineItemModel(
        description: 'TRANSPORTATION CHARGES',
        referenceCode: 'ARSA-0044',
        unit: '4',
        unitType: 'LOT',
        subtotalAmount: 1200.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(1200.00, 3.0),
      ),
      LineItemModel(
        description: 'TRANSPORTATION CHARGES',
        referenceCode: 'ARSA-0045',
        unit: '5',
        unitType: 'LOT',
        subtotalAmount: 1800.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(1800.00, 3.0),
      ),
      LineItemModel(
        description: '',
        referenceCode: 'ARSA-0046',
        unit: '6',
        unitType: 'LOT',
        subtotalAmount: 900.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(900.00, 3.0),
      ),
      LineItemModel(
        description: 'EXPRESS DELIVERY',
        referenceCode: 'ARSA-0047',
        unit: '7',
        unitType: 'EA',
        subtotalAmount: 750.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(750.00, 3.0),
      ),
      LineItemModel(
        description: 'TRANSPORTATION CHARGES',
        referenceCode: 'ARSA-0048',
        unit: '8',
        unitType: 'EA',
        subtotalAmount: 2200.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(2200.00, 3.0),
      ),
      LineItemModel(
        description: '',
        referenceCode: 'ARSA-0049',
        unit: '9',
        unitType: 'LOT',
        subtotalAmount: 1350.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(1350.00, 3.0),
      ),
      LineItemModel(
        description: 'TRANSPORTATION CHARGES',
        referenceCode: 'ARSA-0050',
        unit: '10',
        unitType: 'LOT',
        subtotalAmount: 1650.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(1650.00, 3.0),
      ),
      LineItemModel(
        description: 'HANDLING FEES',
        referenceCode: 'ARDA-0051',
        unit: '11',
        unitType: 'EA',
        subtotalAmount: 1450.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(1450.00, 3.0),
      ),
      LineItemModel(
        description: '',
        referenceCode: 'ARSA-0051',
        unit: '12',
        unitType: 'LOT',
        subtotalAmount: 1750.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(1750.00, 3.0),
      ),
      LineItemModel(
        description: 'TRANSPORTATION CHARGES',
        referenceCode: 'ARSA-0052',
        unit: '13',
        unitType: 'LOT',
        subtotalAmount: 2100.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(2100.00, 3.0),
      ),
      LineItemModel(
        description: 'TRANSPORTATION CHARGES',
        referenceCode: 'ARSA-0053',
        unit: '14',
        unitType: 'EA',
        subtotalAmount: 980.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(980.00, 3.0),
      ),
      LineItemModel(
        description: '',
        referenceCode: 'ARSA-0053',
        unit: '15',
        unitType: 'LOT',
        subtotalAmount: 1250.00,
        discountRate: 3.0,
        totalAmount: LineItemModel.calculateTotal(1250.00, 3.0),
      ),
    ];

    return InvoiceModel(
      date: DateTime.now(),
      invoiceNumber: 'INV-2024-001',
      contractReference: 'CONTRACT-REF-12345',
      paymentTerms: 'Net 30 Days',
      customer: demoCustomer,
      lineItems: lineItems,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.receipt_long,
              size: 80,
              color: Colors.blue,
            ),
            const SizedBox(height: 24),
            const Text(
              'XLOOP',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Invoice Generator',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 48),
            SizedBox(
              width: 250,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const InvoiceFormScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.add),
                label: const Text('Create New Invoice'),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 250,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const CustomerListScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.people),
                label: const Text('Manage Customers'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: 250,
              child: OutlinedButton.icon(
                onPressed: () {
                  final demoInvoice = _generateDemoInvoice();
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PDFPreviewScreen(invoice: demoInvoice),
                    ),
                  );
                },
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text('View Demo Invoice'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Colors.orange),
                  foregroundColor: Colors.orange,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

