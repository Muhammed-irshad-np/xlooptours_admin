import 'package:flutter/material.dart';
import 'package:xloop_invoice/core/utils/app_snack_bar.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../domain/entities/managed_user_entity.dart';
import '../providers/user_management_provider.dart';
import '../../../../core/utils/activity_logger.dart';

/// Admin / Super Admin: change a user's login email (username).
class ChangeLoginEmailDialog extends StatefulWidget {
  final ManagedUserEntity user;

  const ChangeLoginEmailDialog({super.key, required this.user});

  @override
  State<ChangeLoginEmailDialog> createState() => _ChangeLoginEmailDialogState();
}

class _ChangeLoginEmailDialogState extends State<ChangeLoginEmailDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailController;
  late final TextEditingController _confirmController;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.user.email);
    _confirmController = TextEditingController();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    final provider = context.read<UserManagementProvider>();
    final success = await provider.changeLoginEmail(
      uid: widget.user.uid,
      newEmail: _emailController.text.trim(),
    );

    if (!mounted) return;
    setState(() => _isSubmitting = false);

    if (success) {
      final newEmail = _emailController.text.trim();
      await ActivityLogger.log(
        context,
        title: 'User Email Changed',
        message: 'Email for user ${widget.user.email} has been changed to $newEmail.',
        relatedId: widget.user.uid,
      );
      if (mounted) {
        Navigator.pop(context);
        AppSnackBar.showSuccess(context, 'Login email updated for ${widget.user.displayName.isNotEmpty ? widget.user.displayName : widget.user.email}');
      }
    } else {
      AppSnackBar.showError(context, provider.errorMessage ?? 'Failed to change login email');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
      child: Container(
        width: 420.w,
        padding: EdgeInsets.all(24.w),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Change Login Email',
                      style: GoogleFonts.notoSans(
                        fontSize: 18.sp,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF0B0F1A),
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                  ),
                ],
              ),
              Text(
                widget.user.displayName.isNotEmpty
                    ? widget.user.displayName
                    : widget.user.email,
                style: GoogleFonts.notoSans(
                  fontSize: 13.sp,
                  color: const Color(0xFF64748B),
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                'Current: ${widget.user.email}\nThis updates Firebase login and User Management. They must use the new email next time.',
                style: GoogleFonts.notoSans(
                  fontSize: 12.sp,
                  color: const Color(0xFF94A3B8),
                ),
              ),
              const Divider(height: 28),

              TextFormField(
                controller: _emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'New login email (username)',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Email is required';
                  }
                  if (!val.contains('@')) return 'Enter a valid email';
                  return null;
                },
              ),
              SizedBox(height: 16.h),

              TextFormField(
                controller: _confirmController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'Confirm new email',
                  prefixIcon: const Icon(Icons.email_outlined),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                ),
                validator: (val) {
                  if (val?.trim().toLowerCase() !=
                      _emailController.text.trim().toLowerCase()) {
                    return 'Emails do not match';
                  }
                  return null;
                },
              ),
              SizedBox(height: 24.h),

              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed:
                        _isSubmitting ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  SizedBox(width: 12.w),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF13B1F2),
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: 24.w,
                        vertical: 12.h,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                    ),
                    child: _isSubmitting
                        ? SizedBox(
                            width: 20.w,
                            height: 20.h,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Update Email'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
