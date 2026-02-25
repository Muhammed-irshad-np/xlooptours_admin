import 'package:flutter/material.dart';
import 'dart:math' as math;
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xloop_invoice/features/company/domain/entities/company_entity.dart';
import 'package:xloop_invoice/features/customer/data/models/customer_model.dart';
import 'package:xloop_invoice/features/notifications/data/models/notification_model.dart';

import 'package:xloop_invoice/features/notifications/domain/entities/notification_entity.dart';
import 'package:provider/provider.dart';
import 'package:xloop_invoice/features/company/presentation/providers/company_provider.dart';
import 'package:xloop_invoice/features/customer/presentation/providers/customer_provider.dart';
import 'package:xloop_invoice/features/notifications/presentation/providers/notification_provider.dart';

import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:country_picker/country_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

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

  final ValueNotifier<bool> _isLoading = ValueNotifier(true);
  final ValueNotifier<bool> _isSubmitting = ValueNotifier(false);
  final ValueNotifier<CompanyEntity?> _company = ValueNotifier(null);
  final ValueNotifier<String?> _errorMessage = ValueNotifier(null);
  final ValueNotifier<bool> _registrationSuccess = ValueNotifier(false);
  final ValueNotifier<String> _countryCode = ValueNotifier(
    '+966',
  ); // Default to KSA
  final ValueNotifier<List<String>> _previewCaseCodes = ValueNotifier([]);
  final ValueNotifier<bool> _isArabic = ValueNotifier(false);

  final Map<String, Map<String, String>> _translations = {
    'company_not_found': {
      'en': 'Company not found. Please check the link.',
      'ar': 'الشركة غير موجودة. يرجى التحقق من الرابط.',
    },
    'invalid_link': {
      'en': 'Invalid Link: No Company ID provided.',
      'ar': 'رابط غير صالح: لم يتم توفير معرف الشركة.',
    },
    'error_loading': {
      'en': 'Error loading company details: ',
      'ar': 'خطأ في تحميل تفاصيل الشركة: ',
    },
    'success_title': {'en': 'Success!', 'ar': 'تم بنجاح!'},
    'success_message': {
      'en': 'You have successfully joined',
      'ar': 'لقد انضممت بنجاح إلى',
    },
    'motto': {'en': '"Excellence in every mile."', 'ar': '"التميز في كل ميل."'},
    'tagline': {
      'en': 'Executive Mobility for\nIndustry Leaders',
      'ar': 'تنقل تنفيذي\nلقادة الصناعة',
    },
    'company_name': {'en': 'Company Name', 'ar': 'اسم الشركة'},
    'applicant_name': {'en': 'Applicant Name', 'ar': 'اسم مقدم الطلب'},
    'full_name': {'en': 'Full Name', 'ar': 'الاسم الكامل'},
    'whatsapp_number': {'en': 'Contact Number', 'ar': 'رقم التواصل'},
    'search': {'en': 'Search', 'ar': 'بحث'},
    'start_typing': {
      'en': 'Start typing to search',
      'ar': 'ابدأ الكتابة للبحث',
    },
    'case_codes': {
      'en': 'Case Code / Project Code',
      'ar': 'رموز الحالة / رمز المشروع',
    },
    'register_now': {'en': 'REGISTER NOW', 'ar': 'سجل الآن'},
    'send_email': {'en': 'SEND EMAIL', 'ar': 'ارسل بريد الكتروني'},
    'book_ride': {'en': 'BOOK YOUR RIDE', 'ar': 'احجز رحلتك'},
    'support_247': {'en': 'SUPPORT 24x7', 'ar': 'الدعم 24x7'},
    'efficient_safe': {
      'en': 'SAFE | EFFICIENT | RELIABLE',
      'ar': 'آمن | فعال | موثوق',
    },
    'mobile_desc': {
      'en':
          '"We offer our clients one of the most extensive fleets of luxury and standard vehicles across Saudi Arabia and Bahrain. At Xloop Tours W.L.L, we are dedicated to delivering top‑quality, hassle‑free mobility solutions built on safety, comfort, reliability, and a truly premium experience."',
      'ar':
          '"نقدم لعملائنا واحدة من أوسع أساطيل المركبات الفاخرة والقياسية في المملكة العربية السعودية والبحرين. في إكس لوب تورز ذ.م.م، نحن ملتزمون بتقديم حلول تنقل عالية الجودة وخالية من المتاعب مبنية على الأمان والراحة والموثوقية وتجربة متميزة حقًا."',
    },
    'submit_application': {'en': 'SUBMIT APPLICATION', 'ar': 'تقديم الطلب'},
    'required': {'en': 'Required', 'ar': 'مطلوب'},
    'email': {'en': 'Email', 'ar': 'البريد الإلكتروني'},
    'error_registering': {
      'en': 'Error registering: ',
      'ar': 'خطأ في التسجيل: ',
    },
    'executive_mobility': {
      'en': 'Executive Mobility for\nIndustry Leaders',
      'ar': 'تنقل تنفيذي\nلقادة الصناعة',
    },
    'join_us': {
      'en': 'Join Us for premium fleet services and\nprofessional chauffeurs.',
      'ar': 'انضم إلينا للحصول على خدمات أسطول متميزة\nوسائقين محترفين.',
    },
    'powered_by': {
      'en': 'Powered by XLOOP TOURS W.L.L',
      'ar': 'مشغل بواسطة اكس لوب ت ورس ذ.ل.ل',
    },
    'call_any_time': {'en': 'CALL ANY TIME', 'ar': 'اتصل في أي وقت'},
    'customer_support': {
      'en': 'CUSTOMER SUPPORT 24x7',
      'ar': 'دعم العملاء 24/7',
    },
    'for_enquiries': {'en': 'FOR ANY ENQUIRIES', 'ar': 'لأي استفسارات'},
    'member_of': {
      'en': 'MEMBER OF THE ELITE TRAVEL NETWORK',
      'ar': 'عضو في شبكة السفر النخبة',
    },
    'header_company_name': {
      'en': 'XLOOP TOURS W.L.L',
      'ar': 'اكس لوب ت ورس ذ.ل.ل',
    },
    'success_gratitude': {
      'en':
          'Thanks for registering with XLoop Tours.\nWe are excited to have you on board.',
      'ar': 'شكراً لتسجيلك مع إكس لوب تورز.\nنحن متحمسون لانضمامك إلينا.',
    },
    'book_first_ride_btn': {'en': 'BOOK YOUR RIDE', 'ar': 'احجز رحلتك'},
  };

  String _tr(String key) {
    if (_isArabic.value) {
      return _translations[key]?['ar'] ?? key;
    }
    return _translations[key]?['en'] ?? key;
  }

  late AnimationController _mobileFormController;
  late Animation<double> _mobileFormAnimation;
  late AnimationController _waveController;
  final ValueNotifier<bool> _isMobileFormOpen = ValueNotifier(false);

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
    final text = _caseCodeController.text.toUpperCase(); // FORCE UPPERCASE
    final selection = _caseCodeController.selection;

    // Auto-hyphenation logic: Letter followed continuously by Digit
    // Regex matches a letter group followed by a digit group
    // We want to insert a hyphen between them if one doesn't exist.
    // Simple approach: Check for ([a-zA-Z])([0-9]) pattern and replace with $1-$2

    // We only want to run this if the text actually changes to avoid infinite loops if we set text.
    // However, since we are in a listener, we must be careful.

    final newText = text.replaceAllMapped(
      RegExp(
        r'([A-Z])([0-9])',
      ), // Updated to match Uppercase only since we converted
      (match) => '${match.group(1)}-${match.group(2)}',
    );

    // Check if text changed due to Uppercase OR Hyphenation
    if (newText != _caseCodeController.text) {
      // Calculate new cursor position
      // If the hyphen was inserted before the cursor, we shift right by 1.
      int newOffset = selection.baseOffset;

      // Find where the hyphen was inserted relative to cursor
      // This is a bit complex to do perfectly for multiple insertions,
      // but usually users type one char at a time.
      // If length increased by 1, and the insertion happened before cursor:
      if (newText.length > text.length && selection.isValid) {
        // Current simple heuristic: if cursor was after the letter that got hyphenated
        // We can trust the framework handles mostly, but explicitly:
        // If we are at the end, just move to end.
        if (selection.baseOffset == text.length) {
          newOffset = newText.length;
        } else {
          // For mid-text edits, crude adjustment:
          newOffset += 1;
        }
      }

      _caseCodeController.value = TextEditingValue(
        text: newText,
        selection: TextSelection.collapsed(
          offset: math.min(newOffset, newText.length),
        ),
      );
    }
  }

  void _addCaseCode() {
    final code = _caseCodeController.text.trim();
    if (code.isNotEmpty) {
      if (!_previewCaseCodes.value.contains(code)) {
        _previewCaseCodes.value.add(code);
        _caseCodeController.clear();
      } else {
        // Optionally show a message if code already exists
        _caseCodeController.clear();
      }
    }
  }

  void _removeCaseCode(String code) {
    _previewCaseCodes.value.remove(code);
  }

  Future<void> _fetchCompany() async {
    if (widget.companyId == null) {
      _isLoading.value = false;
      _errorMessage.value = 'Invalid Link: No Company ID provided.';
      return;
    }

    try {
      final company = await context.read<CompanyProvider>().getCompanyById(
        widget.companyId!,
      );
      _company.value = company;
      _isLoading.value = false;
      if (company == null) {
        _errorMessage.value = 'Company not found. Please check the link.';
      } else {
        _companyNameController.text = company.companyName;
      }
    } catch (e) {
      _isLoading.value = false;
      _errorMessage.value = 'Error loading company details: $e';
    }
  }

  Future<void> _submitForm() async {
    // Auto-save any pending case code
    _addCaseCode();

    if (!_formKey.currentState!.validate()) return;
    if (_company.value == null) return;

    _isSubmitting.value = true;

    try {
      var newCustomer = CustomerModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: _nameController.text.trim(),
        phone: '', // Placeholder, updated below
        email: null,
        companyId: _company.value!.id,
        companyName: _company.value!.companyName,
        assignedCaseCodes: [], // Will populate below
        createdAt: DateTime.now(),
      );

      // Handle Case Codes
      if (_company.value!.usesCaseCode && _previewCaseCodes.value.isNotEmpty) {
        final inputCodes = _previewCaseCodes.value;

        // 1. Assign to Customer
        newCustomer = newCustomer.copyWith(assignedCaseCodes: inputCodes);

        // 2. Update Company with NEW codes
        final currentCompanyCodes = Set<String>.from(_company.value!.caseCodes);
        bool companyUpdated = false;

        for (var code in inputCodes) {
          if (!currentCompanyCodes.contains(code)) {
            currentCompanyCodes.add(code);
            companyUpdated = true;
          }
        }

        if (companyUpdated) {
          final updatedCompany = _company.value!.copyWith(
            caseCodes: currentCompanyCodes.toList(),
          );
          await context.read<CompanyProvider>().updateCompany(updatedCompany);
          // Update local state to reflect changes immediately if needed
          _company.value = updatedCompany;
        }
      }

      // Handle Phone with Country Code
      newCustomer = newCustomer.copyWith(
        phone: '$_countryCode.value ${_phoneController.text.trim()}',
      );

      if (!mounted) return;
      await context.read<CustomerProvider>().addCustomer(newCustomer);

      // Create Notification
      final notification = NotificationModel(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        title: 'New Registration',
        message: 'New user ${newCustomer.name} has registered.',
        timestamp: DateTime.now(),
        type: NotificationType.registration,
        relatedId: newCustomer.id,
      );
      if (!mounted) return;
      await context.read<NotificationProvider>().insertNotification(
        notification,
      );

      _registrationSuccess.value = true;
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error registering: $e')));
    } finally {
      _isSubmitting.value = false;
    }
  }

  // Vibrant Brand Color (Sky Blue)
  Color get _brandColor => const Color(0xFF13b1f2);
  Color get _darkNavy => const Color(0xFF0F172A);

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([
        _isLoading,
        _isSubmitting,
        _company,
        _errorMessage,
        _registrationSuccess,
        _countryCode,
        _previewCaseCodes,
        _isArabic,
        _isMobileFormOpen,
      ]),
      builder: (context, _) {
        if (_isLoading.value) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        if (_errorMessage.value != null) {
          return Scaffold(
            backgroundColor: Colors.black,
            body: Center(
              child: Padding(
                padding: EdgeInsets.all(24.w),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.error_outline,
                      color: Colors.red[300],
                      size: 60.sp,
                    ),
                    SizedBox(height: 16.h),
                    Text(
                      _errorMessage.value!,
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

        if (_registrationSuccess.value) {
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
      },
    );
  }

  Widget _buildSuccessScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      body: LayoutBuilder(
        builder: (context, constraints) {
          // Check if we are on a mobile width (standard phone portrait)
          final bool isMobileWidth = constraints.maxWidth < 600;

          // Define responsive sizes
          // On mobile, we want things to feel "bigger" and more touch-friendly
          // Matching sizes from _buildMobileLayout (Labels ~60.sp, Input ~50.sp)
          final double horizontalMargin = isMobileWidth ? 20.w : 0;
          final double containerPadding = isMobileWidth ? 30.w : 40.w;

          final double iconSize = isMobileWidth
              ? 200.sp
              : 80.sp; // Increased for mobile
          final double headerSize = isMobileWidth
              ? 100.sp
              : 28.sp; // Increased to match mobile labels
          final double messageSize = isMobileWidth
              ? 60.sp
              : 16.sp; // Increased to match mobile text

          final BoxConstraints containerConstraints = isMobileWidth
              ? BoxConstraints(
                  maxWidth: double.infinity,
                ) // Fill width minus margin
              : BoxConstraints(maxWidth: 500.w);

          return Center(
            child: Container(
              margin: isMobileWidth
                  ? EdgeInsets.symmetric(horizontal: horizontalMargin)
                  : EdgeInsets.symmetric(horizontal: 24.w),
              padding: EdgeInsets.all(containerPadding),
              constraints: containerConstraints,
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
                  Icon(Icons.check_circle, color: _brandColor, size: iconSize),
                  SizedBox(height: 24.h),
                  Text(
                    _tr('header_company_name'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.merriweather(
                      fontSize: headerSize,
                      fontWeight: FontWeight.bold,
                      color: _darkNavy,
                    ),
                  ),
                  SizedBox(height: 16.h),
                  Text(
                    _tr('success_gratitude'),
                    textAlign: TextAlign.center,
                    style: GoogleFonts.notoSans(
                      fontSize: messageSize,
                      color: Colors.grey[600],
                      height: 1.5,
                    ),
                  ),
                  SizedBox(height: 30.h),
                  // CTA Button removed as per request
                  SizedBox(height: 10.h),
                ],
              ),
            ),
          );
        },
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
                    image: AssetImage('assets/images/bg_desktop.jpg'),
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
              // Quote Overlay
              Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 60.w),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _tr('mobile_desc'),
                        textAlign: TextAlign.center,
                        style: _isArabic.value
                            ? GoogleFonts.notoSansArabic(
                                fontSize: 18.sp,
                                color: Colors.white,
                                height: 1.6,
                                shadows: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              )
                            : GoogleFonts.merriweather(
                                fontSize: 18.sp,
                                color: Colors.white,
                                height: 1.6,
                                fontStyle: FontStyle.italic,
                                shadows: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                      ),
                    ],
                  ),
                ),
              ),

              // Footer Contact Section (Moved Back to Left, Aligned Bottom)
              Positioned(
                bottom: 70.h, // Adjusted alignment (+20 more)
                left: 0,
                right: 0,
                child: _buildDesktopFooter(isLightMode: false),
              ),
            ],
          ),
        ),

        // RIGHT SIDE: White Form
        Expanded(
          flex: 6, // Slightly wider for form
          child: Stack(
            children: [
              Container(
                color: Colors.white,
                alignment: Alignment.center,
                child: SingleChildScrollView(
                  padding: EdgeInsets.symmetric(
                    horizontal: 80.w,
                    vertical: 40.h,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 550.w),
                    child: Form(
                      key: _formKey,
                      child: Directionality(
                        textDirection: _isArabic.value
                            ? TextDirection.rtl
                            : TextDirection.ltr,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Logo (Asset Image)
                            Center(
                              child: Image.asset(
                                'assets/logo/xloop_logo.png',
                                height: 100.h,
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
                              _tr('header_company_name'),
                              textAlign: TextAlign.center,
                              style: _isArabic.value
                                  ? GoogleFonts.notoSansArabic(
                                      fontSize: 28.sp,
                                      fontWeight: FontWeight.bold,
                                      color: _darkNavy,
                                      height: 1.2,
                                    )
                                  : GoogleFonts.merriweather(
                                      fontSize: 50.sp,
                                      fontWeight: FontWeight.bold,
                                      color: _darkNavy,
                                      height: 1.2,
                                    ),
                            ),
                            SizedBox(height: 8.h),
                            Text(
                              _tr('efficient_safe'),
                              textAlign: TextAlign.center,
                              style: _isArabic.value
                                  ? GoogleFonts.notoSansArabic(
                                      fontSize: 18.sp,
                                      color: _brandColor,
                                      height: 1.2,
                                      fontWeight: FontWeight.bold,
                                    )
                                  : GoogleFonts.notoSans(
                                      fontSize: 18.sp,
                                      color: _brandColor,
                                      height: 1.2,
                                      fontWeight: FontWeight.bold,
                                      letterSpacing: 2.0,
                                    ),
                            ),
                            SizedBox(height: 15.h),
                            Text(
                              _tr('join_us'),
                              textAlign: TextAlign.center,
                              style: _isArabic.value
                                  ? GoogleFonts.notoSansArabic(
                                      fontSize: 14.sp,
                                      color: Colors.grey[500],
                                      height: 1.5,
                                    )
                                  : GoogleFonts.notoSans(
                                      fontSize: 14.sp,
                                      color: Colors.grey[500],
                                      height: 1.5,
                                    ),
                            ),
                            SizedBox(height: 25.h),

                            // Company Name Field (Read-only)
                            _buildDesktopInput(
                              controller: _companyNameController,
                              label: _tr('company_name'),
                              icon: Icons.business,
                              enabled: false,
                            ),
                            SizedBox(height: 15.h),

                            // Inputs (Outlined Style)
                            _buildDesktopInput(
                              controller: _nameController,
                              label: _tr('full_name'),
                              icon: Icons.person_outline_rounded,
                            ),
                            SizedBox(height: 15.h),
                            _buildDesktopInput(
                              controller: _phoneController,
                              label: _tr('whatsapp_number'),
                              icon: FontAwesomeIcons.whatsapp,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                              ],
                              prefixWidget: InkWell(
                                onTap: () {
                                  showCountryPicker(
                                    context: context,
                                    showPhoneCode: true,
                                    onSelect: (Country country) {
                                      _countryCode.value =
                                          '+${country.phoneCode}';
                                    },
                                    countryListTheme: CountryListThemeData(
                                      borderRadius: BorderRadius.circular(20),
                                      inputDecoration: InputDecoration(
                                        labelText: _tr('search'),
                                        labelStyle: GoogleFonts.notoSans(
                                          color: Colors.grey,
                                        ),
                                        hintText: _tr('start_typing'),
                                        hintStyle: GoogleFonts.notoSans(
                                          color: Colors.grey,
                                        ),
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
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 12.w,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        _countryCode.value,
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
                            if (_company.value != null &&
                                _company.value!.usesCaseCode)
                              Padding(
                                padding: EdgeInsets.only(top: 20.h),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildDesktopInput(
                                      controller: _caseCodeController,
                                      label: _tr('case_codes'),
                                      icon: Icons.confirmation_number_outlined,
                                      textCapitalization:
                                          TextCapitalization.characters,
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          Icons.add_circle,
                                          color: _brandColor,
                                          size: 30.sp,
                                        ),
                                        onPressed: _addCaseCode,
                                      ),
                                      validator: (v) {
                                        if (_previewCaseCodes
                                            .value
                                            .isNotEmpty) {
                                          return null;
                                        }
                                        if (v == null || v.isEmpty) {
                                          return _tr('required');
                                        }
                                        return null;
                                      },
                                    ),
                                    if (_previewCaseCodes.value.isNotEmpty) ...[
                                      SizedBox(height: 12.h),
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
                                onPressed: _isSubmitting.value
                                    ? null
                                    : _submitForm,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor:
                                      _brandColor, // Cyan Brand Color
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8.r),
                                  ),
                                  elevation: 0,
                                ),
                                child: _isSubmitting.value
                                    ? const CircularProgressIndicator(
                                        color: Colors.white,
                                      )
                                    : Text(
                                        _tr('register_now'),
                                        style: _isArabic.value
                                            ? GoogleFonts.notoSansArabic(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
                                              )
                                            : GoogleFonts.notoSans(
                                                fontSize: 14.sp,
                                                fontWeight: FontWeight.bold,
                                                letterSpacing: 1.5,
                                              ),
                                      ),
                              ),
                            ),
                            SizedBox(height: 20.h),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Language Switcher (Dropdown)
              Positioned(
                top: 20,
                right: 20,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.grey[300]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _isArabic.value ? 'ar' : 'en',
                      dropdownColor: Colors.white,
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: _darkNavy,
                        size: 20.sp,
                      ),
                      style: GoogleFonts.notoSans(
                        fontSize: 13.sp,
                        fontWeight: FontWeight.bold,
                        color: _darkNavy,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'en',
                          child: Row(
                            children: [
                              Text('En '),
                              Text('🇺🇸', style: TextStyle(fontSize: 16.sp)),
                            ],
                          ),
                        ),
                        DropdownMenuItem(
                          value: 'ar',
                          child: Row(
                            children: [
                              Text('Ar '),
                              Text('🇸🇦', style: TextStyle(fontSize: 16.sp)),
                            ],
                          ),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _isArabic.value = val == 'ar';
                        }
                      },
                    ),
                  ),
                ),
              ),
            ],
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
    Widget? suffixIcon,
    String? helperText,
    bool enabled = true,
    bool isRequired = true,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      enabled: enabled,
      inputFormatters: inputFormatters,
      textCapitalization: textCapitalization,
      style: _isArabic.value
          ? GoogleFonts.notoSansArabic(
              fontSize: 15.sp,
              color: enabled ? const Color(0xFF334155) : Colors.grey[600],
              fontWeight: FontWeight.w500,
            )
          : TextStyle(
              fontSize: 15.sp,
              color: enabled ? const Color(0xFF334155) : Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
      textAlign: _isArabic.value ? TextAlign.right : TextAlign.left,
      textDirection: _isArabic.value ? TextDirection.rtl : TextDirection.ltr,
      decoration: InputDecoration(
        labelText: label,
        labelStyle: _isArabic.value
            ? GoogleFonts.notoSansArabic(
                color: Colors.grey[400],
                fontSize: 14.sp,
              )
            : TextStyle(color: Colors.grey[400], fontSize: 14.sp),
        prefixIcon:
            prefixWidget ?? Icon(icon, color: Colors.grey[400], size: 20.sp),
        suffixIcon: suffixIcon,
        helperText: helperText,
        helperStyle: _isArabic.value
            ? GoogleFonts.notoSansArabic(fontSize: 12.sp)
            : TextStyle(fontSize: 12.sp),
        filled: true,
        fillColor: Colors.white,
        alignLabelWithHint: true,

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
      validator:
          validator ??
          (v) {
            if (!enabled) return null;
            if (isRequired && (v == null || v.isEmpty)) {
              return _tr('required');
            }
            return null;
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

          // 2. Language Switcher (Looking like a glass button)
          SafeArea(
            child: Align(
              alignment: _isArabic.value
                  ? Alignment.topLeft
                  : Alignment.topRight,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 20.h),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20.r),
                    border: Border.all(color: Colors.white.withOpacity(0.3)),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 12.w),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _isArabic.value ? 'ar' : 'en',
                      dropdownColor:
                          Colors.grey[900], // Dark background for dropdown
                      icon: Icon(
                        Icons.keyboard_arrow_down,
                        color: Colors.white,
                        size: 50.sp,
                      ),
                      style: GoogleFonts.notoSans(
                        fontSize: 50.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                      items: [
                        DropdownMenuItem(
                          value: 'en',
                          child: Row(children: [Text('🇺🇸 '), Text('En')]),
                        ),
                        DropdownMenuItem(
                          value: 'ar',
                          child: Row(children: [Text('🇸🇦 '), Text('Ar')]),
                        ),
                      ],
                      onChanged: (val) {
                        if (val != null) {
                          _isArabic.value = val == 'ar';
                        }
                      },
                    ),
                  ),
                ),
              ),
            ),
          ),

          // 3. Static Content (Logo, Name, Motto) - Pushed up when form opens
          // We use an AnimatedBuilder to slide this content up slightly or fade it if needed
          // But user said "at that time the we offer our client that ddiscrpion will go and the form will open up till the efifcien tsafe relaivel."
          // So the Tagline "EFFICIENT..." stays visible.
          SafeArea(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 60.w, vertical: 20.h),
              child: AnimatedBuilder(
                animation: _mobileFormAnimation,
                builder: (context, child) {
                  // 1. Slide Up Logic
                  // Move up by 50.h (adjusted as per request)
                  final double slideOffset = -50.h * _mobileFormAnimation.value;

                  // 2. Fade Out Logic (for Description & Footer)
                  // Fade out quickly (first 50% of animation)
                  final double opacity =
                      (1.0 - (_mobileFormAnimation.value * 3.0)).clamp(
                        0.0,
                        1.0,
                      );

                  return Transform.translate(
                    offset: Offset(0, slideOffset),
                    child: Directionality(
                      textDirection: _isArabic.value
                          ? TextDirection.rtl
                          : TextDirection.ltr,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_isMobileFormOpen.value)
                            SizedBox(height: 60.h)
                          else
                            SizedBox(height: 90.h),
                          // --- LOGO ---
                          Center(
                            child: Container(
                              padding: EdgeInsets.only(right: 8.h),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: Colors.black,
                                  width: 1.5,
                                ),
                              ),
                              child: Image.asset(
                                'assets/logo/xloop_logo_new.png',
                                height: 100.h,
                                errorBuilder: (c, o, s) => Icon(
                                  Icons.directions_car,
                                  size: 60.sp,
                                  color: _brandColor,
                                ),
                              ),
                            ),
                          ),
                          SizedBox(height: 20.h),

                          // --- COMPANY NAME ---
                          Text(
                            _tr('header_company_name'),
                            textAlign: TextAlign.center,
                            style: _isArabic.value
                                ? GoogleFonts.notoSansArabic(
                                    fontSize: 100.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                    height: 1.0,
                                  )
                                : GoogleFonts.merriweather(
                                    fontSize: 100.sp,
                                    fontWeight: FontWeight.w900,
                                    color: Colors.white,
                                    letterSpacing: 1.2,
                                    height: 1.0,
                                  ),
                          ),
                          SizedBox(height: 4.h),

                          // --- TAGLINE ---
                          Text(
                            _tr('efficient_safe'),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.notoSans(
                              fontSize: 55.sp, // Updated to 30.sp
                              fontWeight: FontWeight.bold,
                              color: _brandColor,
                              letterSpacing: 2.0,
                            ),
                          ),
                          SizedBox(height: 70.h),

                          // --- DESCRIPTION (Fades out) ---
                          Opacity(
                            opacity: opacity,
                            child: Text(
                              _tr('mobile_desc'),
                              textAlign: TextAlign.center,
                              style: _isArabic.value
                                  ? GoogleFonts.notoSansArabic(
                                      fontSize: 50.sp, // Smaller for Arabic
                                      color: Colors.white.withOpacity(0.95),
                                      height: 1.5,
                                      shadows: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.6),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    )
                                  : GoogleFonts.merriweather(
                                      fontSize: 50.sp,
                                      color: Colors.white.withOpacity(0.95),
                                      height: 1.5,
                                      fontStyle: FontStyle.italic,
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
                          SizedBox(height: 70.h),

                          // --- FOOTER (Fades out) ---
                          Opacity(
                            opacity: opacity,
                            child: Directionality(
                              textDirection: TextDirection.ltr,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  _buildFooterInfoItem(
                                    icon: FontAwesomeIcons.whatsapp,
                                    label: _tr('book_ride'),
                                    value: '+966 50 483 6105',
                                    onTap: _launchWhatsApp,
                                    color: const Color(0xFF25D366),
                                    isLarge: true,
                                  ),
                                  SizedBox(width: 25.w),
                                  _buildFooterInfoItem(
                                    icon: Icons.phone_in_talk,
                                    label: _tr('support_247'),
                                    value: '+966 50 269 1607',
                                    onTap: () => _launchPhone('+966502691607'),
                                    color: Colors.orange,
                                  ),
                                  SizedBox(width: 25.w),
                                  _buildFooterInfoItem(
                                    icon: Icons.email_outlined,
                                    label: _tr('send_email'),
                                    value: 'enquiries@xlooptours.com',
                                    onTap: () => _launchEmail(
                                      'enquiries@xlooptours.com',
                                    ),
                                    color: Colors.redAccent,
                                  ),
                                ],
                              ),
                            ),
                          ),
                          SizedBox(height: 100.h), // Space for wave sheet
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          // 2.5 Dismiss Barrier (Touch outside to close)
          if (_isMobileFormOpen.value)
            Positioned.fill(
              child: GestureDetector(
                onTap: () {
                  _isMobileFormOpen.value = false;
                  _mobileFormController.reverse();
                },
                child: Container(
                  color: Colors.transparent, // Detailed touch hit test
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
              final double minHeight = 150.h;
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
                        child: _isMobileFormOpen.value
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
          _isMobileFormOpen.value = true;
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
            _tr('register_now'),
            style: _isArabic.value
                ? GoogleFonts.notoSansArabic(
                    fontSize: 30.sp,
                    fontWeight: FontWeight.bold,
                    color: _brandColor,
                    letterSpacing: 1.2,
                  )
                : GoogleFonts.notoSans(
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
    return Padding(
      padding: EdgeInsets.fromLTRB(24.w, 10.h, 24.w, 20.h),
      child: LayoutBuilder(
        builder: (context, constraints) {
          return FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.topCenter,
            child: SizedBox(
              width: constraints.maxWidth,
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Close Button
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.close,
                            color: Colors.white,
                            size: 50.sp,
                          ),
                        ),
                        onPressed: () {
                          _isMobileFormOpen.value = false;
                          _mobileFormController.reverse();
                        },
                      ),
                    ),
                    SizedBox(height: 10.h),

                    _buildMobileInput(
                      controller: _companyNameController,
                      label: _tr('company_name'),
                      icon: Icons.business,
                      enabled: false,
                    ),
                    SizedBox(height: 10.h),
                    _buildMobileInput(
                      controller: _nameController,
                      label: _tr('full_name'),
                      icon: Icons.person_outline_rounded,
                      isRequired: true,
                    ),
                    SizedBox(height: 10.h),

                    _buildMobileInput(
                      controller: _phoneController,
                      label: _tr('whatsapp_number'),
                      icon: FontAwesomeIcons.whatsapp,
                      isRequired: true,
                      keyboardType: TextInputType.phone,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      prefixWidget: InkWell(
                        onTap: () {
                          showCountryPicker(
                            context: context,
                            showPhoneCode: true,
                            onSelect: (Country country) {
                              _countryCode.value = '+${country.phoneCode}';
                            },
                            countryListTheme: CountryListThemeData(
                              bottomSheetHeight: 0.7.sh,
                              textStyle: GoogleFonts.notoSans(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              searchTextStyle: GoogleFonts.notoSans(
                                fontSize: 16,
                                color: Colors.black87,
                              ),
                              borderRadius: const BorderRadius.only(
                                topLeft: Radius.circular(20),
                                topRight: Radius.circular(20),
                              ),
                              inputDecoration: InputDecoration(
                                labelText: _tr('search'),
                                labelStyle: GoogleFonts.notoSans(
                                  color: Colors.grey,
                                ),
                                hintText: _tr('start_typing'),
                                hintStyle: GoogleFonts.notoSans(
                                  color: Colors.grey,
                                ),
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
                                _countryCode.value,
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
                    if (_company.value != null &&
                        _company.value!.usesCaseCode) ...[
                      SizedBox(height: 10.h),
                      Padding(
                        padding: EdgeInsets.only(top: 10.h),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildMobileInput(
                              controller: _caseCodeController,
                              label: _tr('case_codes'),
                              icon: Icons.confirmation_number_outlined,
                              isRequired: true,
                              textCapitalization: TextCapitalization.characters,
                              suffixIcon: IconButton(
                                icon: Icon(
                                  Icons.add_circle,
                                  color: Colors.white,
                                  size: 80.sp,
                                ),
                                onPressed: _addCaseCode,
                              ),
                              validator: (v) {
                                if (_previewCaseCodes.value.isNotEmpty)
                                  return null;
                                if (v == null || v.isEmpty) {
                                  return _tr('required');
                                }
                                return null;
                              },
                            ),
                            if (_previewCaseCodes.value.isNotEmpty) ...[
                              SizedBox(height: 16.h),
                              _buildCaseCodeChips(),
                              SizedBox(height: 16.h),
                            ],
                          ],
                        ),
                      ),
                    ],

                    SizedBox(height: 20.h), // Reduced spacing
                    SizedBox(
                      height: 50.h,
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting.value ? null : _submitForm,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: _brandColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12.r),
                          ),
                          elevation: 0,
                        ),
                        child: _isSubmitting.value
                            ? CircularProgressIndicator(color: _brandColor)
                            : Text(
                                _tr('submit_application'),
                                style: _isArabic.value
                                    ? GoogleFonts.notoSansArabic(
                                        fontSize: 30.sp,
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      )
                                    : GoogleFonts.notoSans(
                                        fontSize: 40.sp, // Slightly reduced
                                        fontWeight: FontWeight.bold,
                                        letterSpacing: 1.5,
                                      ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMobileInput({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    TextInputType? keyboardType,
    Widget? prefixWidget,
    Widget? suffixIcon,
    String? helperText,
    bool enabled = true,
    bool isRequired = false,
    List<TextInputFormatter>? inputFormatters,
    String? Function(String?)? validator,
    TextCapitalization textCapitalization = TextCapitalization.none,
  }) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: _previewCaseCodes.value.isEmpty ? 12 : 4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RichText(
            text: TextSpan(
              text: label,
              style: _isArabic.value
                  ? GoogleFonts.notoSansArabic(
                      color: Colors.white,
                      fontSize: 45.sp, // Smaller for Arabic
                      fontWeight: FontWeight.bold,
                    )
                  : GoogleFonts.notoSans(
                      color: Colors.white,
                      fontSize: 60.sp,
                      fontWeight: FontWeight.bold,
                    ),
              children: [
                if (isRequired)
                  TextSpan(
                    text: ' *',
                    style: TextStyle(
                      color: Colors.redAccent,
                      fontSize: 60.sp,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 12.h),
          TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            enabled: enabled,
            inputFormatters: inputFormatters,
            textCapitalization: textCapitalization,
            style: GoogleFonts.notoSans(
              fontSize: 50.sp,
              color: enabled ? Colors.white : Colors.white60,
              fontWeight: FontWeight.w500,
            ),
            cursorColor: Colors.white,
            // Directionality for Input Field Text
            textDirection: _isArabic.value
                ? TextDirection.rtl
                : TextDirection.ltr,
            decoration: InputDecoration(
              prefixIcon:
                  prefixWidget ?? Icon(icon, color: Colors.white, size: 50.sp),
              suffixIcon: suffixIcon,
              helperText: helperText,
              helperStyle: GoogleFonts.notoSans(
                color: Colors.white70,
                fontSize: 50.sp,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.white30),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.white30),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.r),
                borderSide: BorderSide(color: Colors.white),
              ),
              contentPadding: EdgeInsets.symmetric(
                vertical: 16.h,
                horizontal: 16.w,
              ),
            ),
            validator:
                validator ??
                (v) {
                  if (!enabled) return null;
                  if (isRequired && (v == null || v.isEmpty)) {
                    return _tr('required');
                  }
                  return null;
                },
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _isLoading.dispose();
    _isSubmitting.dispose();
    _company.dispose();
    _errorMessage.dispose();
    _registrationSuccess.dispose();
    _countryCode.dispose();
    _previewCaseCodes.dispose();
    _isArabic.dispose();
    _isMobileFormOpen.dispose();
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
      children: _previewCaseCodes.value.map((code) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.4)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                code,
                style: GoogleFonts.notoSans(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
              const SizedBox(width: 4),
              GestureDetector(
                onTap: () => _removeCaseCode(code),
                child: const Icon(Icons.close, size: 14, color: Colors.white),
              ),
            ],
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
    bool isLarge = false,
    bool isLightMode = false,
    bool isDesktop = false,
  }) {
    final borderColor = isLightMode
        ? Colors.grey[300]!
        : (isLarge ? color.withOpacity(0.5) : Colors.white.withOpacity(0.3));
    final bgColor = isLightMode
        ? Colors.white
        : (isLarge ? color.withOpacity(0.15) : Colors.white.withOpacity(0.1));
    final textColor = isLightMode ? _darkNavy : Colors.white;
    final labelColor = isLightMode ? Colors.grey[600] : Colors.white70;
    final iconBgColor = isLightMode
        ? color.withOpacity(0.1)
        : color.withOpacity(0.2);

    // Desktop Sizing (Fixed) vs Mobile Sizing (Scaled)
    final double containerPadding = isDesktop ? 8.0 : 18.w;
    final double iconContainerPadding = isDesktop ? 6.0 : 12.w;
    final double iconSize = isDesktop ? 16.0 : 60.sp;
    final double arrowSize = isDesktop ? 12.0 : 40.sp;
    final double gapSize = isDesktop ? 6.0 : 16.w;
    final double labelSize = isDesktop ? 9.0 : 35.sp;
    final double valueSize = isDesktop ? 11.0 : 30.sp;
    final double verticalGap = isDesktop
        ? 0.0
        : 12.h; // No vertical gap in Row mode

    Widget content;
    if (isDesktop) {
      // COMPACT ROW LAYOUT FOR DESKTOP
      content = Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(iconContainerPadding),
            decoration: BoxDecoration(
              color: iconBgColor,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: iconSize),
          ),
          SizedBox(width: gapSize),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.notoSans(
                  fontSize: labelSize,
                  color: labelColor,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
              SizedBox(height: 2.0),
              Text(
                value,
                style: GoogleFonts.notoSans(
                  fontSize: valueSize,
                  color: textColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      );
    } else {
      // VERTICAL COLUMN LAYOUT FOR MOBILE
      content = Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: EdgeInsets.all(iconContainerPadding),
                decoration: BoxDecoration(
                  color: iconBgColor,
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: color, size: iconSize),
              ),
              SizedBox(width: gapSize),
              Icon(
                Icons.arrow_forward_ios,
                color: isLightMode ? Colors.grey[400] : Colors.white54,
                size: arrowSize,
              ),
            ],
          ),
          SizedBox(height: verticalGap),
          Text(
            label,
            style: GoogleFonts.notoSans(
              fontSize: labelSize,
              color: labelColor,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            value,
            style: GoogleFonts.notoSans(
              fontSize: valueSize,
              color: textColor,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16.r),
        child: Container(
          padding: EdgeInsets.all(containerPadding),
          decoration: BoxDecoration(
            color: bgColor,
            borderRadius: BorderRadius.circular(16.r),
            border: Border.all(color: borderColor),
          ),
          child: content,
        ),
      ),
    );
  }

  Widget _buildDesktopFooter({bool isLightMode = false}) {
    // Web Standard Sizing: Constrain width and center
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: 600.w),
        padding: EdgeInsets.symmetric(horizontal: 20.w),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildFooterInfoItem(
              icon: FontAwesomeIcons.whatsapp,
              label: _tr('book_ride'),
              value: '+966 50 483 6105',
              onTap: _launchWhatsApp,
              color: const Color(0xFF25D366),
              isLightMode: isLightMode,
              isLarge: true,
              isDesktop: true,
            ),
            SizedBox(width: 12.w),
            _buildFooterInfoItem(
              icon: Icons.phone_in_talk,
              label: _tr('support_247'),
              value: '+966 50 269 1607',
              onTap: () => _launchPhone('+966502691607'),
              color: Colors.orange,
              isLightMode: isLightMode,
              isDesktop: true,
            ),
            SizedBox(width: 12.w),
            _buildFooterInfoItem(
              icon: Icons.email_outlined,
              label: _tr('send_email'),
              value: 'enquiries@xlooptours.com',
              onTap: () => _launchEmail('enquiries@xlooptours.com'),
              color: Colors.redAccent,
              isLightMode: isLightMode,
              isDesktop: true,
            ),
          ],
        ),
      ),
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
