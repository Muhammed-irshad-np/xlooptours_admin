import 'package:flutter/material.dart';
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
    final currencyFormat = NumberFormat.currency(symbol: 'SR ', decimalDigits: 2);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'Item ${index + 1}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: onDelete,
                  iconSize: 20,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              controller: TextEditingController(text: item.description),
              onChanged: (value) {
                onChanged(item.copyWith(description: value));
              },
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Item Code / Reference (optional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              controller: TextEditingController(text: item.referenceCode ?? ''),
              onChanged: (value) {
                onChanged(item.copyWith(referenceCode: value));
              },
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Quantity',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    controller: TextEditingController(text: item.unit),
                    onChanged: (value) {
                      onChanged(item.copyWith(unit: value));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    decoration: const InputDecoration(
                      labelText: 'Unit Type',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    value: item.unitType,
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
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Subtotal Amount',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    controller: TextEditingController(
                      text: item.subtotalAmount > 0 ? item.subtotalAmount.toStringAsFixed(2) : '',
                    ),
                    onChanged: (value) {
                      final subtotal = double.tryParse(value) ?? 0.0;
                      final total = LineItemModel.calculateTotal(subtotal, item.discountRate);
                      onChanged(item.copyWith(
                        subtotalAmount: subtotal,
                        totalAmount: total,
                      ));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Discount Rate (%)',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    controller: TextEditingController(
                      text: item.discountRate > 0 ? item.discountRate.toStringAsFixed(2) : '3.00',
                    ),
                    onChanged: (value) {
                      final discount = double.tryParse(value) ?? 3.0;
                      final total = LineItemModel.calculateTotal(item.subtotalAmount, discount);
                      onChanged(item.copyWith(
                        discountRate: discount,
                        totalAmount: total,
                      ));
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Total Amount',
                      border: OutlineInputBorder(),
                      isDense: true,
                      filled: true,
                    ),
                    readOnly: true,
                    controller: TextEditingController(
                      text: currencyFormat.format(item.totalAmount),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

