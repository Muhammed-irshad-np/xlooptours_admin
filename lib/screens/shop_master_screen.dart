import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:provider/provider.dart';
import 'package:uuid/uuid.dart';

import '../features/vehicle/domain/entities/shop_entity.dart';
import '../features/vehicle/presentation/providers/vehicle_provider.dart';
import '../core/widgets/modern_app_bar.dart';

class ShopMasterScreen extends StatefulWidget {
  const ShopMasterScreen({super.key});

  @override
  State<ShopMasterScreen> createState() => _ShopMasterScreenState();
}

class _ShopMasterScreenState extends State<ShopMasterScreen> {
  final ValueNotifier<List<ShopEntity>> _shops = ValueNotifier([]);
  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadShops();
  }

  Future<void> _loadShops() async {
    _isLoading.value = true;
    try {
      if (mounted) {
        await context.read<VehicleProvider>().fetchAllShops();
        if (!mounted) return;
        _shops.value = context.read<VehicleProvider>().shops;
        _isLoading.value = false;
      }
    } catch (e) {
      debugPrint('Error loading shops: $e');
      if (mounted) {
        _isLoading.value = false;
      }
    }
  }

  Future<void> _deleteShop(String id) async {
    try {
      if (mounted) {
        await context.read<VehicleProvider>().deleteShop(id);
        _loadShops();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error deleting shop: $e')),
        );
      }
    }
  }

  void _showAddEditDialog({ShopEntity? shop}) {
    showDialog(
      context: context,
      builder: (context) => _AddEditShopDialog(
        shop: shop,
        onSave: (newShop) async {
          if (shop == null) {
            await context.read<VehicleProvider>().addShop(newShop);
          } else {
            await context.read<VehicleProvider>().updateShop(newShop);
          }
          _loadShops();
        },
      ),
    );
  }

  @override
  void dispose() {
    _shops.dispose();
    _isLoading.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const ModernAppBar(title: 'Maintenance Shops Master'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddEditDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Add Shop'),
        backgroundColor: Colors.blue,
      ),
      body: Column(
        children: [
          Padding(
            padding: EdgeInsets.all(16.w),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by shop name, phone, or address...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {
                            _searchQuery = '';
                          });
                        },
                      )
                    : null,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.r),
                ),
                filled: true,
                fillColor: Colors.grey.withValues(alpha: 0.05),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.trim().toLowerCase();
                });
              },
            ),
          ),
          Expanded(
            child: AnimatedBuilder(
              animation: Listenable.merge([_isLoading, _shops]),
              builder: (context, _) {
                if (_isLoading.value) {
                  return const Center(child: CircularProgressIndicator());
                }

                final filteredList = _shops.value.where((shop) {
                  if (_searchQuery.isEmpty) return true;
                  final nameMatch = shop.name.toLowerCase().contains(_searchQuery);
                  final phoneMatch = shop.phone?.toLowerCase().contains(_searchQuery) ?? false;
                  final addressMatch = shop.address?.toLowerCase().contains(_searchQuery) ?? false;
                  return nameMatch || phoneMatch || addressMatch;
                }).toList();

                if (filteredList.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.storefront_outlined, size: 64.sp, color: Colors.grey),
                        SizedBox(height: 16.h),
                        Text(
                          _searchQuery.isEmpty ? 'No maintenance shops found' : 'No shops matching search',
                          style: TextStyle(color: Colors.grey, fontSize: 16.sp),
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 80.h),
                  itemCount: filteredList.length,
                  separatorBuilder: (context, index) => SizedBox(height: 12.h),
                  itemBuilder: (context, index) {
                    final shop = filteredList[index];
                    return Card(
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: ListTile(
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: 16.w,
                          vertical: 8.h,
                        ),
                        leading: CircleAvatar(
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          child: Icon(Icons.storefront, color: Colors.blue, size: 24.sp),
                        ),
                        title: Text(
                          shop.name,
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16.sp,
                          ),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (shop.phone != null && shop.phone!.isNotEmpty) ...[
                              SizedBox(height: 4.h),
                              Row(
                                children: [
                                  Icon(Icons.phone_outlined, size: 14.sp, color: Colors.grey[600]),
                                  SizedBox(width: 4.w),
                                  Text(
                                    shop.phone!,
                                    style: TextStyle(color: Colors.grey[700], fontSize: 13.sp),
                                  ),
                                ],
                              ),
                            ],
                            if (shop.address != null && shop.address!.isNotEmpty) ...[
                              SizedBox(height: 2.h),
                              Row(
                                children: [
                                  Icon(Icons.location_on_outlined, size: 14.sp, color: Colors.grey[600]),
                                  SizedBox(width: 4.w),
                                  Expanded(
                                    child: Text(
                                      shop.address!,
                                      style: TextStyle(color: Colors.grey[700], fontSize: 13.sp),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                            if (shop.notes != null && shop.notes!.isNotEmpty) ...[
                              SizedBox(height: 2.h),
                              Text(
                                shop.notes!,
                                style: TextStyle(color: Colors.grey[500], fontSize: 12.sp, fontStyle: FontStyle.italic),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit, color: Colors.orange),
                              onPressed: () => _showAddEditDialog(shop: shop),
                              tooltip: 'Edit',
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.red),
                              onPressed: () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                    title: const Text('Delete Shop'),
                                    content: Text(
                                      'Are you sure you want to delete "${shop.name}"?',
                                    ),
                                    actions: [
                                      TextButton(
                                        onPressed: () => Navigator.pop(c, false),
                                        child: const Text('Cancel'),
                                      ),
                                      ElevatedButton(
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.red,
                                        ),
                                        onPressed: () => Navigator.pop(c, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );
                                if (confirm == true) {
                                  _deleteShop(shop.id);
                                }
                              },
                              tooltip: 'Delete',
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AddEditShopDialog extends StatefulWidget {
  final ShopEntity? shop;
  final Function(ShopEntity) onSave;

  const _AddEditShopDialog({this.shop, required this.onSave});

  @override
  State<_AddEditShopDialog> createState() => _AddEditShopDialogState();
}

class _AddEditShopDialogState extends State<_AddEditShopDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _addressController;
  late TextEditingController _notesController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.shop?.name ?? '');
    _phoneController = TextEditingController(text: widget.shop?.phone ?? '');
    _addressController = TextEditingController(text: widget.shop?.address ?? '');
    _notesController = TextEditingController(text: widget.shop?.notes ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final shop = ShopEntity(
        id: widget.shop?.id ?? const Uuid().v4(),
        name: _nameController.text.trim(),
        phone: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        address: _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
        createdAt: widget.shop?.createdAt ?? DateTime.now(),
      );

      await widget.onSave(shop);
      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving shop: $e')),
        );
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.shop == null ? 'Add Shop' : 'Edit Shop'),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'Shop / Workshop Name *',
                  hintText: 'e.g. Al-Amana Auto Repair',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.storefront),
                ),
                textCapitalization: TextCapitalization.words,
                validator: (v) => v == null || v.trim().isEmpty ? 'Required' : null,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(
                  labelText: 'Phone Number (Optional)',
                  hintText: 'e.g. 0501234567',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
                keyboardType: TextInputType.phone,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _addressController,
                decoration: const InputDecoration(
                  labelText: 'Address / Location (Optional)',
                  hintText: 'e.g. Industrial Area 2, Riyadh',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.location_on),
                ),
                textCapitalization: TextCapitalization.sentences,
              ),
              SizedBox(height: 16.h),
              TextFormField(
                controller: _notesController,
                decoration: const InputDecoration(
                  labelText: 'Notes / Contact Person (Optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.note),
                ),
                maxLines: 2,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _isSaving ? null : _submit,
          child: _isSaving
              ? SizedBox(
                  width: 16.w,
                  height: 16.w,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
