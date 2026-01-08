import 'package:flutter/material.dart';
import 'invoice_form_screen.dart';
import 'customer_list_screen.dart';
import 'invoice_list_screen.dart';
import 'analytics_screen.dart';
import '../models/invoice_model.dart';
import '../models/customer_model.dart';
import '../models/line_item_model.dart';
import '../widgets/responsive_layout.dart';

import '../services/auth_service.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            onPressed: () async {
              await AuthService.instance.signOut();
            },
            icon: const Icon(Icons.logout),
            tooltip: 'Sign Out',
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.receipt_long, size: 80, color: Colors.blue),
              const SizedBox(height: 24),
              const Text(
                'XLoop Tours',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 2),
              const Text(
                'Invoices Dashboard',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 48),
              ResponsiveLayout(
                mobile: Column(
                  children: _buildMenuButtons(context, width: 250),
                ),
                tablet: Wrap(
                  spacing: 24,
                  runSpacing: 24,
                  alignment: WrapAlignment.center,
                  children: _buildMenuButtons(context, width: 200),
                ),
                desktop: Wrap(
                  spacing: 32,
                  runSpacing: 32,
                  alignment: WrapAlignment.center,
                  children: _buildMenuButtons(context, width: 220),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildMenuButtons(
    BuildContext context, {
    required double width,
  }) {
    return [
      SizedBox(
        width: width,
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
        width: width,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AnalyticsScreen()),
            );
          },
          icon: const Icon(Icons.analytics),
          label: const Text('Analytics'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
            side: const BorderSide(color: Colors.orange),
            foregroundColor: Colors.orange,
          ),
        ),
      ),
      const SizedBox(height: 16),
      SizedBox(
        width: width,
        child: OutlinedButton.icon(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const InvoiceListScreen(),
              ),
            );
          },
          icon: const Icon(Icons.folder_open),
          label: const Text('Saved Invoices'),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
    ];
  }
}
