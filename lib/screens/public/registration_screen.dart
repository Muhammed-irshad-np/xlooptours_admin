import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xloop_invoice/models/company_model.dart';
import 'package:xloop_invoice/models/customer_model.dart';
import 'package:xloop_invoice/services/database_service.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:country_picker/country_picker.dart';
import 'package:url_launcher/url_launcher.dart';

class RegistrationScreen extends StatefulWidget {
  final String? companyId;

  const RegistrationScreen({super.key, this.companyId});

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with TickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _caseCodeController = TextEditingController();
  final _companyNameController = TextEditingController();

  bool _isLoading = true;
  bool _isSubmitting = false;
  CompanyModel? _company;
  String? _errorMessage;
  bool _registrationSuccess = false;
  String _countryCode = '+966'; // Default to KSA
  List<String> _previewCaseCodes = [];

  late AnimationController _mobileFormController;
  late Animation<double> _mobileFormAnimation;
  late AnimationController _waveController;
  bool _isMobileFormOpen = false;

  @override
  void initState() {
    super.initState();
    _fetchCompany();

    _caseCodeController.addListener(_updateCaseCodePreview);

    _mobileFormController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _mobileFormAnimation = CurvedAnimation(
      parent: _mobileFormController,
      curve: Curves.easeInOutCubic,
    );

    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  void _updateCaseCodePreview() {
    final text = _caseCodeController.text;
    if (text.isEmpty) {
      if (_previewCaseCodes.isNotEmpty) {
        setState(() {
          _previewCaseCodes = [];
        });
      }
      return;
    }

    final codes = text
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    setState(() {
      _previewCaseCodes = codes;
    });
  }

  Future<void> _fetchCompany() async {
    if (widget.companyId == null) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Invalid Link: No Company ID provided.';
      });
      return;
    }

    try {
      final company = await DatabaseService.instance.getCompanyById(
        widget.companyId!,
      );
      setState(() {
        _company = company;
        _isLoading = false;
        if (company == null) {
          _errorMessage = 'Company not found. Please check the link.';
        } else {
          _companyNameController.text = company.companyName;
        }
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error loading company details: $e';
      });
    }
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;
    if (_company == null) return;

    setState(() => _isSubmitting = true);

    try {
      var newCustomer = CustomerModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        phone: '', // Placeholder, updated below
        companyId: _company!.id,
        companyName: _company!.companyName,
        assignedCaseCodes: [], // Will populate below
        createdAt: DateTime.now(),
      );

      // Handle Case Codes
      if (_company!.usesCaseCode && _caseCodeController.text.isNotEmpty) {
        // Split by comma and clean
        final inputCodes = _caseCodeController.text
            .split(',')
            .map((e) => e.trim())
            .where((e) => e.isNotEmpty)
            .toList();

        // 1. Assign to Customer
        newCustomer = newCustomer.copyWith(assignedCaseCodes: inputCodes);

        // 2. Update Company with NEW codes
        final currentCompanyCodes = Set<String>.from(_company!.caseCodes);
        bool companyUpdated = false;

        for (var code in inputCodes) {
          if (!currentCompanyCodes.contains(code)) {
            currentCompanyCodes.add(code);
            companyUpdated = true;
          }
        }

        if (companyUpdated) {
          final updatedCompany = _company!.copyWith(
            caseCodes: currentCompanyCodes.toList(),
          );
          await DatabaseService.instance.updateCompany(updatedCompany);
          // Update local state to reflect changes immediately if needed
          _company = updatedCompany;
        }
      }

      // Handle Phone with Country Code
      newCustomer = newCustomer.copyWith(
        phone: '$_countryCode ${_phoneController.text.trim()}',
      );

      await DatabaseService.instance.insertCustomer(newCustomer);

      setState(() {
        _registrationSuccess = true;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error registering: $e')));
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  // Vibrant Brand Color (Sky Blue)
  Color get _brandColor => const Color(0xFF13b1f2);
  Color get _darkNavy => const Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    if (_errorMessage != null) {
      return Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(24.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error_outline, color: Colors.red[300], size: 60.sp),
                SizedBox(height: 16.h),
                Text(
                  _errorMessage!,
                  style: GoogleFonts.merriweather(
                    color: _darkNavy,
                    fontSize: 18.sp,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_registrationSuccess) {
      return _buildSuccessScreen();
    }

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

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Container(
          margin: EdgeInsets.symmetric(horizontal: 24.w),
          padding: EdgeInsets.all(40.w),
          constraints: BoxConstraints(maxWidth: 500.w),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 30,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: _brandColor, size: 80.sp),
              SizedBox(height: 24.h),
              Text(
                'Success!',
                style: GoogleFonts.merriweather(
                  fontSize: 28.sp,
                  fontWeight: FontWeight.bold,
                  color: _darkNavy,
                ),
              ),
              SizedBox(height: 16.h),
              Text(
                'You have successfully joined ${_company?.companyName}.',
                textAlign: TextAlign.center,
                style: GoogleFonts.notoSansArabic(
                  fontSize: 16.sp,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _launchPhone(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _launchEmail(String email) async {
    final Uri launchUri = Uri(scheme: 'mailto', path: email);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _launchWhatsApp() async {
    final Uri launchUri = Uri.parse("https://wa.me/966504836105");
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri, mode: LaunchMode.externalApplication);
    }
  }

  // ==========================================
  // DESKTOP LAYOUT (Split Screen)
  // ==========================================
  Widget _buildDesktopLayout() {
    return Row(
      children: [
        // LEFT SIDE: Image/Branding
        Expanded(
          flex: 5,
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Image Placeholder - Chauffeur with Car
              Container(
                decoration: const BoxDecoration(
                  color: Colors.black, // Fallback dark
                  image: DecorationImage(
                    // Chauffeur opening car door
                    image: AssetImage('assets/images/registration_new.jpg'),
                    fit: BoxFit.cover,
                  ),
                ),
                // Dark Overlay for text readability
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.3),
                        Colors.black.withOpacity(0.7),
                      ],
                    ),
                  ),
                ),
              ),
              // Quote Overlay
              Positioned(
                bottom: 60.h,
                left: 60.w,
                right: 60.w,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '"Excellence in every mile."',
                      style: GoogleFonts.playfairDisplay(
                        // Or Merriweather italic
                        fontSize: 32.sp,
                        color: Colors.white,
                        fontStyle: FontStyle.italic,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // RIGHT SIDE: White Form
        Expanded(
          flex: 6, // Slightly wider for form
          child: Container(
            color: Colors.white,
            alignment: Alignment.center,
            child: SingleChildScrollView(
              padding: EdgeInsets.symmetric(horizontal: 80.w, vertical: 40.h),
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: 550.w),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Logo (Asset Image)
                      Center(
                        child: Image.asset(
                          'assets/logo/xloop_logo.png',
                          height: 80.h,
                          errorBuilder: (c, o, s) => Column(
                            children: [
                              Icon(
                                Icons.directions_car,
                                size: 50.sp,
                                color: _brandColor,
                              ),
                              Text(
                                'XLOOP',
                                style: GoogleFonts.merriweather(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      SizedBox(height: 40.h),

                      // Headers
                      Text(
                        'XLOOP TOURS W.L.L',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.merriweather(
                          fontSize: 28.sp,
                          fontWeight: FontWeight.bold,
                          color: _darkNavy,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 8.h),
                      Text(
                        'Executive Mobility for\nIndustry Leaders',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.merriweather(
                          fontSize: 18.sp,
                          color: Colors.grey[600],
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 24.h),
                      Text(
                        'Join Us for premium fleet services and\nprofessional chauffeurs.',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.notoSans(
                          fontSize: 14.sp,
                          color: Colors.grey[500],
                          height: 1.5,
                        ),
                      ),
                      SizedBox(height: 50.h),

                      // Company Name Field (Read-only)
                      _buildDesktopInput(
                        controller: _companyNameController,
                        label: 'Company Name',
                        icon: Icons.business,
                        enabled: false,
                      ),
                      SizedBox(height: 20.h),

                      // Inputs (Outlined Style)
                      _buildDesktopInput(
                        controller: _nameController,
                        label: 'Applicant Name',
                        icon: Icons.person_outline_rounded,
                      ),
                      SizedBox(height: 20.h),
                      _buildDesktopInput(
                        controller: _phoneController,
                        label: 'WhatsApp Number',
                        icon: FontAwesomeIcons.whatsapp,
                        keyboardType: TextInputType.phone,
                        prefixWidget: InkWell(
                          onTap: () {
                            showCountryPicker(
                              context: context,
                              showPhoneCode: true,
                              onSelect: (Country country) {
                                setState(() {
                                  _countryCode = '+${country.phoneCode}';
                                });
                              },
                              countryListTheme: CountryListThemeData(
                                borderRadius: BorderRadius.circular(20),
                                inputDecoration: InputDecoration(
                                  labelText: 'Search',
                                  hintText: 'Start typing to search',
                                  prefixIcon: const Icon(Icons.search),
                                  border: OutlineInputBorder(
                                    borderSide: BorderSide(
                                      color: const Color(
                                        0xFF8C98A8,
                                      ).withOpacity(0.2),
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                          child: Container(
                            padding: EdgeInsets.symmetric(horizontal: 12.w),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _countryCode,
                                  style: TextStyle(
                                    fontSize: 15.sp,
                                    color: const Color(0xFF334155),
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(width: 4.w),
                                Icon(
                                  Icons.arrow_drop_down,
                                  color: Colors.grey[600],
                                  size: 18.sp,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (_company!.usesCaseCode)
                        Padding(
                          padding: EdgeInsets.only(top: 20.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _buildDesktopInput(
                                controller: _caseCodeController,
                                label: _company!.caseCodeLabel ?? 'Case Codes',
                                icon: Icons.confirmation_number_outlined,
                                helperText:
                                    'Separate multiple codes with commas',
                              ),
                              if (_previewCaseCodes.isNotEmpty) ...[
                                SizedBox(height: 8.h),
                                _buildCaseCodeChips(),
                              ],
                            ],
                          ),
                        ),

                      SizedBox(height: 40.h),

                      // Button (Cyan Background)
                      SizedBox(
                        height: 56.h,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitForm,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _brandColor, // Cyan Brand Color
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            elevation: 0,
                          ),
                          child: _isSubmitting
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : Text(
                                  'REGISTER NOW',
                                  style: GoogleFonts.notoSans(
                                    fontSize: 14.sp,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 1.5,
                                  ),
                                ),
                        ),
                      ),

                      SizedBox(height: 60.h),

                      // Footer
                      Column(
                        children: [
                          Icon(
                            Icons.shield_outlined,
                            color: Colors.grey[300],
                            size: 30.sp,
                          ),
                          SizedBox(height: 12.h),
                          Text(
                            'MEMBER OF THE ELITE TRAVEL NETWORK',
                            style: GoogleFonts.merriweather(
                              fontSize: 10.sp,
                              letterSpacing: 1.5,
                              color: Colors.grey[400],
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 40.h),
                          _buildContactFooter(isDark: false),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    Widget? prefixWidget,
    String? helperText,
    bool enabled = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      style: TextStyle(
        fontSize: 15.sp,
        color: enabled ? const Color(0xFF334155) : Colors.grey[600],
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey[400], fontSize: 14.sp),
        prefixIcon:
            prefixWidget ?? Icon(icon, color: Colors.grey[400], size: 20.sp),
        helperText: helperText,
        filled: true,
        fillColor: Colors.white,

        // Outline Border Style for Desktop
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(color: Colors.grey[200]!, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.r),
          borderSide: BorderSide(
            color: _brandColor,
            width: 1.5,
          ), // Highlight with Brand Color
        ),
        contentPadding: EdgeInsets.symmetric(vertical: 20.h, horizontal: 20.w),
      ),
      validator: (v) {
        if (!enabled) return null;
        return v!.isEmpty ? 'Required' : null;
      },
    );
  }

  // ==========================================
  // MOBILE LAYOUT (Landing + Bottom Sheet Form)
  // ==========================================
  Widget _buildMobileLayout() {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false,

      body: Stack(
        fit: StackFit.expand,
        children: [
          // 0. Full Screen Background Image
          Image.asset('assets/images/registration_new.jpg', fit: BoxFit.cover),

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

          // 2. Static Content (Logo, Name, Motto) - Pushed up when form opens
          // We use an AnimatedBuilder to slide this content up slightly or fade it if needed
          // But user said "at that time the we offer our client that ddiscrpion will go and the form will open up till the efifcien tsafe relaivel."
          // So the Tagline "EFFICIENT..." stays visible.
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 60.w, vertical: 20.h),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: 10.h),
                  // --- LOGO ---
                  Center(
                    child: Image.asset(
                      'assets/logo/xloop_logo.png',
                      height: 70.h,
                      errorBuilder: (c, o, s) => Icon(
                        Icons.directions_car,
                        size: 60.sp,
                        color: _brandColor,
                      ),
                    ),
                  ),
                  SizedBox(height: 16.h),

                  // --- COMPANY NAME ---
                  Text(
                    'XLOOP TOURS W.L.L',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.merriweather(
                      fontSize: 100.sp, // Updated to 100.sp as requested
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      letterSpacing: 1.2,
                      height: 1.0, // Reduced line height to keep it tighter
                    ),
                  ),
                  SizedBox(height: 4.h),

                  // --- TAGLINE ---
                  Text(
                    'EFFICIENT | SAFE | RELIABLE',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSans(
                      fontSize: 60.sp, // Updated to 30.sp
                      fontWeight: FontWeight.w600,
                      color: _brandColor,
                      letterSpacing: 2.0,
                    ),
                  ),
                  SizedBox(height: 24.h),

                  // --- DESCRIPTION (Fades out) ---
                  AnimatedBuilder(
                    animation: _mobileFormAnimation,
                    builder: (context, child) {
                      return Opacity(
                        opacity: (1.0 - _mobileFormAnimation.value).clamp(
                          0.0,
                          1.0,
                        ),
                        child: child,
                      );
                    },
                    child: Text(
                      'We offer our clients one of the most extensive fleets of luxury and regular vehicles in Saudi Arabia. At Xloop Tours W.L.L, we are committed to customer satisfaction and are dedicated to providing top quality, hassle-free mobility solutions.',
                      textAlign: TextAlign.left,
                      style: GoogleFonts.merriweather(
                        fontSize: 60.sp, //  Updated to 24.sp
                        color: Colors.white.withOpacity(0.95),
                        height: 1.4,

                        shadows: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.6),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  const Spacer(),
                  Text(
                    'Powered by XLOOP TOURS W.L.L',
                    style: GoogleFonts.merriweather(
                      fontSize: 30.sp,
                      color: Colors.white70,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 10.h),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        _buildFooterInfoItem(
                          icon: FontAwesomeIcons.whatsapp,
                          label: 'BOOK A RIDE',
                          value: '+966 50 483 6105',
                          onTap: _launchWhatsApp,
                          color: const Color(0xFF25D366),
                        ),
                        _buildFooterDivider(),
                        _buildFooterInfoItem(
                          icon: Icons.phone_in_talk,
                          label: 'CALL ANY TIME',
                          value: '+966 50 483 6105',
                          onTap: () => _launchPhone('+966504836105'),
                          color: Colors.blue,
                        ),
                        _buildFooterDivider(),
                        _buildFooterInfoItem(
                          icon: Icons.support_agent,
                          label: 'SUPPORT 24x7',
                          value: '+966 50 269 1607',
                          onTap: () => _launchPhone('+966502691607'),
                          color: Colors.orange,
                        ),
                        _buildFooterDivider(),
                        _buildFooterInfoItem(
                          icon: Icons.email_outlined,
                          label: 'SEND EMAIL',
                          value: 'enquiries@xlooptours.com',
                          onTap: () => _launchEmail('enquiries@xlooptours.com'),
                          color: Colors.redAccent,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 140.h), // Space for wave sheet
                ],
              ),
            ),
          ),

          // 3. Animated Wave Form Sheet
          AnimatedBuilder(
            animation: Listenable.merge([
              _mobileFormAnimation,
              _waveController,
            ]),
            builder: (context, child) {
              final double minHeight = 120.h;
              final double maxHeight = 0.75.sh;
              final double currentHeight =
                  minHeight +
                  (maxHeight - minHeight) * _mobileFormAnimation.value;

              // Calculate constant fade height in pixels (e.g. 80px) converted to relative stop
              // 80 pixels covers the wave amplitude (~40px) + some blend area
              final double fadePixels = 80.0;
              final double fadeStop = (fadePixels / currentHeight).clamp(
                0.0,
                1.0,
              );

              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: currentHeight,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Back Wave (Decorative) - White opacity
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: ClipPath(
                        clipper: AnimatedWaveClipper(
                          progress: _waveController.value,
                          offset: 0.5, // Phase shift
                        ),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.15),
                              ],
                              stops: [0.0, fadeStop],
                            ),
                          ),
                        ),
                      ),
                    ),
                    // Front Wave (Main Container)
                    ClipPath(
                      clipper: AnimatedWaveClipper(
                        progress: _waveController.value,
                        offset: 0.0,
                      ),
                      child: Container(
                        padding: EdgeInsets.only(top: 50.h),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [_brandColor.withOpacity(0.0), _brandColor],
                            stops: [0.0, fadeStop],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.2),
                              blurRadius: 20,
                              offset: const Offset(0, -5),
                            ),
                          ],
                        ),
                        child: _isMobileFormOpen
                            ? _buildMobileFormContent()
                            : _buildRegisterButton(),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildRegisterButton() {
    return Center(
      child: GestureDetector(
        onTap: () {
          setState(() {
            _isMobileFormOpen = true;
          });
          _mobileFormController.forward();
        },
        child: Container(
          margin: EdgeInsets.only(top: 5.h, bottom: 5.h),
          padding: EdgeInsets.symmetric(horizontal: 40.w, vertical: 16.h),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30.r),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Text(
            'REGISTER NOW',
            style: GoogleFonts.notoSans(
              fontSize: 40.sp, // Updated to 20.sp for better proportion
              fontWeight: FontWeight.bold,
              color: _brandColor,
              letterSpacing: 1.2,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileFormContent() {
    return Column(
      children: [
        // Close / Header Row
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 24.w),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Registration',
                style: GoogleFonts.merriweather(
                  fontSize: 20.sp,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () {
                  FocusScope.of(context).unfocus(); // Hide keyboard
                  _mobileFormController.reverse().then((_) {
                    setState(() {
                      _isMobileFormOpen = false;
                    });
                  });
                },
              ),
            ],
          ),
        ),
        Divider(height: 1, color: Colors.white.withOpacity(0.2)),

        // Expanded Scrollable Form
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 40.h),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildMobileInput(
                    controller: _companyNameController,
                    label: 'Company Name',
                    icon: Icons.business,
                    enabled: false,
                  ),
                  _buildMobileInput(
                    controller: _nameController,
                    label: 'Applicant Name',
                    icon: Icons.person_outline_rounded,
                  ),
                  _buildMobileInput(
                    controller: _phoneController,
                    label: 'WhatsApp Number',
                    icon: FontAwesomeIcons.whatsapp,
                    keyboardType: TextInputType.phone,
                    prefixWidget: InkWell(
                      onTap: () {
                        showCountryPicker(
                          context: context,
                          showPhoneCode: true,
                          onSelect: (Country country) {
                            setState(() {
                              _countryCode = '+${country.phoneCode}';
                            });
                          },
                          countryListTheme: CountryListThemeData(
                            bottomSheetHeight: 0.7.sh,
                            borderRadius: const BorderRadius.only(
                              topLeft: Radius.circular(20),
                              topRight: Radius.circular(20),
                            ),
                            inputDecoration: InputDecoration(
                              labelText: 'Search',
                              hintText: 'Start typing to search',
                              prefixIcon: const Icon(Icons.search),
                              border: OutlineInputBorder(
                                borderSide: BorderSide(
                                  color: const Color(
                                    0xFF8C98A8,
                                  ).withOpacity(0.2),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.only(right: 8.0),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              _countryCode,
                              style: const TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.white54,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  if (_company != null && _company!.usesCaseCode)
                    Padding(
                      padding: EdgeInsets.only(top: 20.h),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildMobileInput(
                            controller: _caseCodeController,
                            label: _company!.caseCodeLabel ?? 'Case Codes',
                            icon: Icons.confirmation_number_outlined,
                            helperText: 'Separate multiple codes with commas',
                          ),
                          if (_previewCaseCodes.isNotEmpty) ...[
                            SizedBox(height: 8.h),
                            _buildCaseCodeChips(),
                          ],
                        ],
                      ),
                    ),
                  SizedBox(height: 30.h),
                  SizedBox(
                    height: 50.h,
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submitForm,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: _brandColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12.r),
                        ),
                        elevation: 0,
                      ),
                      child: _isSubmitting
                          ? CircularProgressIndicator(color: _brandColor)
                          : Text(
                              'SUBMIT APPLICATION',
                              style: GoogleFonts.notoSans(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.bold,
                                letterSpacing: 1.5,
                              ),
                            ),
                    ),
                  ),

                  SizedBox(height: 100.h),
                  Column(
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        color: Colors.white.withOpacity(0.6),
                        size: 24,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'SECURE REGISTRATION',
                        style: GoogleFonts.merriweather(
                          fontSize: 10,
                          letterSpacing: 1.5,
                          color: Colors.white.withOpacity(0.7),
                          fontWeight: FontWeight.bold,
                        ),
                      ),

                      const SizedBox(height: 40),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    Widget? prefixWidget,
    String? helperText,
    bool enabled = true,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: _previewCaseCodes.isEmpty ? 24 : 8),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        enabled: enabled,
        style: TextStyle(
          fontSize: 16, // Standard input size
          color: enabled ? Colors.white : Colors.white60,
          fontWeight: FontWeight.w500,
        ),
        cursorColor: Colors.white,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.white70, fontSize: 14),
          prefixIcon:
              prefixWidget ?? Icon(icon, color: Colors.white70, size: 24),
          helperText: helperText,
          helperStyle: TextStyle(color: Colors.white60),

          border: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white30),
          ),
          enabledBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white30),
          ),
          focusedBorder: UnderlineInputBorder(
            borderSide: BorderSide(color: Colors.white),
          ),
          contentPadding: const EdgeInsets.symmetric(vertical: 12),
        ),
        validator: (v) {
          if (!enabled) return null;
          return v!.isEmpty ? 'Required' : null;
        },
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _caseCodeController.dispose();
    _companyNameController.dispose();
    _mobileFormController.dispose();
    _waveController.dispose();

    super.dispose();
  }

  Widget _buildCaseCodeChips() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: _previewCaseCodes.map((code) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: Text(
            code,
            style: GoogleFonts.notoSans(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFooterInfoItem({
    required IconData icon,
    required String label,
    required String value,
    required VoidCallback onTap,
    required Color color,
  }) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 16.w),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(8.w),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8.r),
              ),
              child: Icon(icon, color: color, size: 24.sp),
            ),
            SizedBox(width: 12.w),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.notoSans(
                    fontSize: 30.sp,
                    color: Colors.white70,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  value,
                  style: GoogleFonts.notoSans(
                    fontSize: 30.sp,
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooterDivider() {
    return Container(height: 30.h, width: 1, color: Colors.white24);
  }

  Widget _buildContactFooter({required bool isDark}) {
    final textColor = isDark ? Colors.white70 : _darkNavy;
    final iconColor = isDark ? _brandColor : _brandColor;

    Widget buildRow(
      IconData icon,
      String label,
      String value,
      VoidCallback onTap,
    ) {
      return InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 16.sp, color: iconColor),
              SizedBox(width: 8.w),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.notoSans(
                      fontSize: 10.sp,
                      color: textColor.withOpacity(0.6),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.notoSans(
                      fontSize: 12.sp,
                      color: textColor,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Text(
          'Powered by XLOOP TOURS W.L.L',
          style: GoogleFonts.merriweather(
            fontSize: 12.sp,
            color: textColor,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 16.h),
        buildRow(
          Icons.call,
          'CALL ANY TIME',
          '+966504836105',
          () => _launchPhone('+966504836105'),
        ),
        buildRow(
          Icons.support_agent,
          'CUSTOMER SUPPORT 24x7',
          '+966502691607',
          () => _launchPhone('+966502691607'),
        ),
        buildRow(
          Icons.email,
          'FOR ANY ENQUIRIES',
          'enquiries@xlooptours.com',
          () => _launchEmail('enquiries@xlooptours.com'),
        ),
      ],
    );
  }
}

class AnimatedWaveClipper extends CustomClipper<Path> {
  final double progress;
  final double offset;

  AnimatedWaveClipper({required this.progress, this.offset = 0.0});

  @override
  Path getClip(Size size) {
    var path = Path();
    path.moveTo(0, size.height);
    path.lineTo(0, size.height); // Bottom Left corner logic check

    final double amplitude = 12.0;
    final double yOffset = 30.0; // Base height from top

    for (double x = 0; x <= size.width; x++) {
      // Calculate y
      // Wave moving right -> subtract time
      double xAngle = (x / size.width) * 2 * math.pi;
      double timeAngle = (progress + offset) * 2 * math.pi;

      // y = amplitude * sin(xAngle - timeAngle) + yOffset
      double y = amplitude * math.sin(xAngle - timeAngle) + yOffset;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    path.lineTo(size.width, size.height);
    path.lineTo(0, size.height);
    path.close();

    return path;
  }

  @override
  bool shouldReclip(covariant AnimatedWaveClipper oldClipper) {
    return oldClipper.progress != progress;
  }
}
