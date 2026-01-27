import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:url_launcher/url_launcher.dart';

class UnderMaintenanceScreen extends StatelessWidget {
  const UnderMaintenanceScreen({super.key});

  Future<void> _launchEmail() async {
    final Uri launchUri = Uri(
      scheme: 'mailto',
      path: 'enquiries@xlooptours.com',
    );
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth > 900) {
            return _buildDesktopLayout();
          } else {
            return _buildMobileLayout();
          }
        },
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Stack(
      children: [
        // Background Image with Blur
        Container(
          decoration: const BoxDecoration(
            image: DecorationImage(
              image: AssetImage('assets/images/bg_desktop.jpg'),
              fit: BoxFit.cover,
            ),
          ),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),
        ),

        // Center Content
        Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo
                Container(
                  padding: EdgeInsets.only(right: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo/xloop_logo_new.png',
                    height: 100.h,
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: 40.h),

                // Main Heading
                Text(
                  'We are Under Maintenance',
                  style: GoogleFonts.merriweather(
                    fontSize: 32.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20.h),

                // Subheading
                Text(
                  'Our website is currently undergoing scheduled maintenance.\nWe should be back shortly. Thank you for your patience.',
                  style: GoogleFonts.notoSans(
                    fontSize: 16.sp,
                    color: Colors.white.withOpacity(0.9),
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 60.h),

                // Additional Info / Contact (Optional)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _launchEmail,
                    borderRadius: BorderRadius.circular(30),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 30.w,
                        vertical: 15.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(30),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: Colors.white,
                            size: 20.sp,
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            'Contact us: enquiries@xlooptours.com',
                            style: GoogleFonts.notoSans(
                              fontSize: 14.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Footer
        Positioned(
          bottom: 30.h,
          left: 0,
          right: 0,
          child: Text(
            'XLOOP TOURS W.L.L © ${DateTime.now().year}',
            style: GoogleFonts.notoSans(
              fontSize: 12.sp,
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }

  Widget _buildMobileLayout() {
    return Stack(
      fit: StackFit.expand,
      children: [
        // 0. Full Screen Background Image (No Blur as requested or implied by 'mobile layout' patterns usually)
        Image.asset('assets/images/bg_mobile.jpg', fit: BoxFit.cover),

        // 1. Dark Overlay
        Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.black.withOpacity(0.3),
                Colors.black.withOpacity(0.8),
              ],
            ),
          ),
        ),

        // 2. Center Content
        Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: 24.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo - Matches Mobile Registration Style
                Container(
                  padding: EdgeInsets.only(right: 8.h),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.black, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 20,
                        offset: const Offset(
                          0,
                          5,
                        ), // Slightly reduced shadow offset for mobile
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo/xloop_logo_new.png',
                    height: 100
                        .h, // Keeping consistent or slightly adjusted if needed, but 100.h is responsive
                    fit: BoxFit.contain,
                  ),
                ),
                SizedBox(height: 60.h), // More spacing for mobile verticality
                // Main Heading - Larger Font for Mobile Impact
                Text(
                  'We are Under Maintenance',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.merriweather(
                    fontSize: 70
                        .sp, // Main headers in mobile registration were huge (~100.sp or 50.sp depending), 32 is too small
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.2,
                    height: 1.2,
                  ),
                ),
                SizedBox(height: 30.h),

                // Subheading
                Text(
                  'Our website is currently undergoing scheduled maintenance.\nWe should be back shortly.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.notoSans(
                    fontSize: 60
                        .sp, // Content text in mobile reg was ~16-18, mobile needs scale up potentially if using .sp on small device
                    color: Colors.white.withOpacity(0.95),
                    height: 1.5,
                  ),
                ),
                SizedBox(height: 80.h),

                // Contact Box
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: _launchEmail,
                    borderRadius: BorderRadius.circular(40.r),
                    child: Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 40.w,
                        vertical: 20.h,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          40.r,
                        ), // More rounded
                        border: Border.all(
                          color: Colors.white.withOpacity(0.3),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.email_outlined,
                            color: Colors.white,
                            size: 60.sp,
                          ),
                          SizedBox(height: 10.h),
                          Text(
                            'enquiries@xlooptours.com',
                            style: GoogleFonts.notoSans(
                              fontSize: 40.sp,
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Footer
        Positioned(
          bottom: 40.h,
          left: 0,
          right: 0,
          child: Text(
            'XLOOP TOURS W.L.L © ${DateTime.now().year}',
            style: GoogleFonts.notoSans(
              fontSize: 24.sp,
              color: Colors.white.withOpacity(0.6),
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
