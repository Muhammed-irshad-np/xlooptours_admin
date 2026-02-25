import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../features/invoice/domain/entities/invoice_entity.dart';
import '../features/invoice/data/models/invoice_model.dart';

class StorageService {
  static const String _invoiceDraftKey = 'invoice_draft';

  // Invoice Draft operations
  Future<void> saveInvoiceDraft(InvoiceEntity invoice) async {
    final prefs = await SharedPreferences.getInstance();
    final model = InvoiceModel.fromEntity(invoice);
    final invoiceJson = jsonEncode(model.toJson());
    await prefs.setString(_invoiceDraftKey, invoiceJson);
  }

  Future<InvoiceEntity?> getInvoiceDraft() async {
    final prefs = await SharedPreferences.getInstance();
    final invoiceJson = prefs.getString(_invoiceDraftKey);
    if (invoiceJson != null) {
      try {
        return InvoiceModel.fromJson(jsonDecode(invoiceJson));
      } catch (e) {
        // If parsing fails, clear the corrupted draft
        await clearInvoiceDraft();
        return null;
      }
    }
    return null;
  }

  Future<void> clearInvoiceDraft() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_invoiceDraftKey);
  }
}
