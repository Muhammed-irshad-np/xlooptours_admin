import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

class DriversScreen extends StatelessWidget {
  const DriversScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Drivers & Employees')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_pin, size: 80.sp, color: Colors.grey),
            SizedBox(height: 16.h),
            Text(
              'Manage Drivers & Employees',
              style: TextStyle(fontSize: 24.sp, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8.h),
            Text('Feature coming soon...', style: TextStyle(fontSize: 14.sp)),
            SizedBox(height: 24.h),
            ElevatedButton.icon(
              onPressed: () {},
              icon: Icon(Icons.add, size: 20.sp),
              label: Text('Add New Driver', style: TextStyle(fontSize: 14.sp)),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
