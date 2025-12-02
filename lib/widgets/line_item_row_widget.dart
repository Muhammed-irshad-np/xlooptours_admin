import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../models/line_item_model.dart';

class LineItemRowWidget extends StatelessWidget {
  final LineItemModel item;
  final int index;
  final Function(LineItemModel) onChanged;
  final VoidCallback onDelete;

  const LineItemRowWidget({
    super.key,
    required this.item,
    required this.index,
    required this.onChanged,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      symbol: 'SR ',
      decimalDigits: 2,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.blue[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'Item ${index + 1}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: Colors.blue[800],
                    fontSize: 12,
                  ),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
                tooltip: 'Remove Item',
                style: IconButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  hoverColor: Colors.red[50],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: item.description,
            decoration: _buildInputDecoration('Description'),
            onChanged: (value) {
              onChanged(item.copyWith(description: value));
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: item.referenceCode,
            decoration: _buildInputDecoration(
              'Item Code / Reference (optional)',
            ),
            onChanged: (value) {
              onChanged(item.copyWith(referenceCode: value));
            },
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextFormField(
                  initialValue: item.unit,
                  decoration: _buildInputDecoration('Quantity'),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
                  ],
                  onChanged: (value) {
                    final qty = double.tryParse(value) ?? 0.0;
                    // Auto-set unit type: 1 = LOT, >1 = EA
                    final newUnitType = qty == 1.0 ? 'LOT' : 'EA';
                    final total = LineItemModel.calculateTotal(
                      item.subtotalAmount,
                      value,
                    );
                    onChanged(
                      item.copyWith(
                        unit: value,
                        unitType: newUnitType,
                        totalAmount: total,
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: item.unitType,
                  decoration: _buildInputDecoration('Unit'),
                  items: const [
                    DropdownMenuItem(value: 'LOT', child: Text('LOT')),
                    DropdownMenuItem(value: 'EA', child: Text('EA')),
                  ],
                  onChanged: (value) {
                    if (value != null) {
                      onChanged(item.copyWith(unitType: value));
                    }
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          TextFormField(
            initialValue: item.subtotalAmount > 0
                ? item.subtotalAmount.toStringAsFixed(2)
                : '',
            decoration: _buildInputDecoration('Price'),
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d*')),
            ],
            onChanged: (value) {
              final unitPrice = double.tryParse(value) ?? 0.0;
              final total = LineItemModel.calculateTotal(unitPrice, item.unit);
              onChanged(
                item.copyWith(subtotalAmount: unitPrice, totalAmount: total),
              );
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Total',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    color: Colors.grey,
                  ),
                ),
                Text(
                  currencyFormat.format(item.totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.blue, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      isDense: true,
    );
  }
}
