import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class ModernAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final PreferredSizeWidget? bottom;
  final Widget? leading;

  const ModernAppBar({
    super.key,
    required this.title,
    this.actions,
    this.bottom,
    this.leading,
  });

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          fontSize: 20.sp,
          fontWeight: FontWeight.bold,
          color: Colors.black87,
        ),
      ),
      elevation: 0,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
      leading: leading,
      actions: actions != null
          ? actions!.map((a) {
              return Padding(
                padding: EdgeInsets.only(right: 8.w),
                child: a,
              );
            }).toList()
          : null,
      bottom: bottom,
      shape: Border(
        bottom: BorderSide(color: Colors.grey.withOpacity(0.2), width: 1),
      ),
    );
  }

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));
}
