import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import '../providers/vault_provider.dart';
import '../../../../widgets/responsive_layout.dart';
import '../../../../core/widgets/modern_app_bar.dart';
import '../../../../core/widgets/modern_tab_bar.dart';
import 'vat_filing_dialog.dart';
import '../../domain/entities/vault_data.dart';
import 'package:cross_file/cross_file.dart';
import 'package:file_picker/file_picker.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../screens/document_viewer_screen.dart';
import '../../../../core/utils/share_helper.dart';

class VaultScreen extends StatefulWidget {
  const VaultScreen({super.key});

  @override
  State<VaultScreen> createState() => _VaultScreenState();
}

class _VaultScreenState extends State<VaultScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<VaultProvider>().loadVaultData();
      context.read<VaultProvider>().loadVatFilings();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC), // Slate 50
      appBar: ModernAppBar(
        title: 'Xloop Secure Vault',
        actions: [
          Semantics(
            label: 'Security Status: Your data is protected by bank-grade encryption',
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    const Color(0xFF10B981).withOpacity(0.15),
                    const Color(0xFF059669).withOpacity(0.05),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20.r),
                border: Border.all(color: const Color(0xFF10B981).withOpacity(0.3)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_outline, color: const Color(0xFF059669), size: 14.sp),
                  SizedBox(width: 6.w),
                  Text(
                    'SECURED',
                    style: GoogleFonts.plusJakartaSans(
                      color: const Color(0xFF059669),
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1.0,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16.w),
        ],
        bottom: ModernTabBar(
          controller: _tabController,
          tabs: [
            Tab(
              child: Semantics(
                label: 'Details tab',
                child: const Text('Details'),
              ),
            ),
            Tab(
              child: Semantics(
                label: 'VAT filings tab',
                child: const Text('VAT Filings'),
              ),
            ),
            Tab(
              child: Semantics(
                label: 'Alert settings tab',
                child: const Text('Alert Settings'),
              ),
            ),
          ],
        ),
      ),
      body: Consumer<VaultProvider>(
        builder: (context, provider, child) {
          if (provider.isLoading && provider.vaultData == null) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: Color(0xFF0F172A)),
                  SizedBox(height: 16),
                  Text('Loading Secure Vault…'),
                ],
              ),
            );
          }

          if (provider.errorMessage != null && provider.vaultData == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, color: Colors.red, size: 48.r),
                  SizedBox(height: 16.h),
                  Text(
                    'Failed to load vault data',
                    style: GoogleFonts.plusJakartaSans(fontSize: 18.sp, fontWeight: FontWeight.bold),
                  ),
                  TextButton(
                    onPressed: () => provider.loadVaultData(),
                    child: const Text('Try Again'),
                  ),
                ],
              ),
            );
          }

          return TabBarView(
            controller: _tabController,
            children: [
              _buildCompanyDetailsTab(provider),
              _buildVatFilingsTab(provider),
              _buildAlertSettingsTab(provider),
            ],
          );
        },
      ),
    );
  }

  Widget _buildCompanyDetailsTab(VaultProvider provider) {
    final data = provider.vaultData;
    if (data == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.r),
      child: ResponsiveLayout(
        mobile: Column(
          children: [
            _buildVaultSection(
              title: 'Commercial License',
              icon: Icons.business_center_outlined,
              accentColor: const Color(0xFF0F172A),
              child: _buildLicenseContent(data.license, provider),
            ),
            SizedBox(height: 24.h),
            _buildVaultSection(
              title: 'VAT Certificate',
              icon: Icons.receipt_long_outlined,
              accentColor: const Color(0xFF0F172A),
              child: _buildVatCertContent(data.vatCertificate, provider),
            ),
          ],
        ),
        desktop: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: _buildVaultSection(
                title: 'Commercial License',
                icon: Icons.business_center_outlined,
                accentColor: const Color(0xFF0F172A),
                child: _buildLicenseContent(data.license, provider),
              ),
            ),
            SizedBox(width: 24.w),
            Expanded(
              child: _buildVaultSection(
                title: 'VAT Certificate',
                icon: Icons.receipt_long_outlined,
                accentColor: const Color(0xFF0F172A),
                child: _buildVatCertContent(data.vatCertificate, provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVaultSection({
    required String title,
    required IconData icon,
    required Color accentColor,
    required Widget child,
  }) {
    return StateWithHover(
      builder: (context, isHovered) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.r),
            boxShadow: [
              BoxShadow(
                color: isHovered ? Colors.black.withOpacity(0.06) : Colors.black.withOpacity(0.03),
                blurRadius: isHovered ? 15 : 10,
                offset: Offset(0, isHovered ? 6 : 4),
              ),
            ],
            border: Border.all(
              color: isHovered ? accentColor.withOpacity(0.3) : const Color(0xFFE2E8F0),
              width: isHovered ? 1.5 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.all(20.r),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8.r),
                      decoration: BoxDecoration(
                        color: accentColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8.r),
                      ),
                      child: Icon(icon, color: accentColor, size: 20.sp),
                    ),
                    SizedBox(width: 12.w),
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 16.sp,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF1E293B),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1, color: Color(0xFFE2E8F0)),
              Padding(
                padding: EdgeInsets.all(20.r),
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLicenseContent(CommercialLicense license, VaultProvider provider) {
    return Column(
      children: [
        _buildInfoRow(
          'Issue Date',
          license.issueDate != null ? DateFormat('dd MMM yyyy').format(license.issueDate!) : 'Not set',
          icon: Icons.calendar_today_outlined,
          semanticsLabel: 'License issue date',
          onEdit: () => _pickDate(license.issueDate, (d) => _updateLicense(provider, issueDate: d)),
        ),
        _buildInfoRow(
          'Expiry Date',
          license.expiryDate != null ? DateFormat('dd MMM yyyy').format(license.expiryDate!) : 'Not set',
          icon: Icons.event_available_outlined,
          semanticsLabel: 'License expiry date',
          trailing: _buildExpiryBadge(license.expiryDate, license.alertDays),
          onEdit: () => _pickDate(license.expiryDate, (d) => _updateLicense(provider, expiryDate: d)),
        ),
        _buildInfoRow(
          'Registration No.',
          license.registrationNo.isEmpty ? 'Not set' : license.registrationNo,
          icon: Icons.tag_outlined,
          semanticsLabel: 'Commercial registration number',
          onEdit: () => _editText('Registration No.', license.registrationNo, (v) => _updateLicense(provider, registrationNo: v)),
        ),
        SizedBox(height: 8.h),
        _buildDocumentSection(
          'Commercial License Document',
          license.document,
          (doc) => _updateLicense(provider, document: doc),
          () => _updateLicense(provider, document: null),
          provider,
          'license',
        ),
      ],
    );
  }

  Widget _buildVatCertContent(VatCertificate cert, VaultProvider provider) {
    return Column(
      children: [
        _buildInfoRow(
          'Issue Date',
          cert.issueDate != null ? DateFormat('dd MMM yyyy').format(cert.issueDate!) : 'Not set',
          icon: Icons.calendar_today_outlined,
          semanticsLabel: 'VAT certificate issue date',
          onEdit: () => _pickDate(cert.issueDate, (d) => _updateVatCert(provider, issueDate: d)),
        ),
        _buildInfoRow(
          'VAT Account No.',
          cert.vatAccountNo.isEmpty ? 'Not set' : cert.vatAccountNo,
          icon: Icons.badge_outlined,
          semanticsLabel: 'VAT account number',
          onEdit: () => _editText('VAT Account No.', cert.vatAccountNo, (v) => _updateVatCert(provider, vatAccountNo: v)),
        ),
        SizedBox(height: 8.h),
        _buildDocumentSection(
          'VAT Certificate Document',
          cert.document,
          (doc) => _updateVatCert(provider, document: doc),
          () => _updateVatCert(provider, document: null),
          provider,
          'vat_cert',
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value, {required IconData icon, String? semanticsLabel, Widget? trailing, VoidCallback? onEdit}) {
    return Padding(
      padding: EdgeInsets.only(bottom: 16.h),
      child: Semantics(
        label: semanticsLabel != null ? '$semanticsLabel: $value' : '$label: $value',
        child: Row(
          children: [
            ExcludeSemantics(
              child: Container(
                padding: EdgeInsets.all(8.r),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8.r),
                ),
                child: Icon(icon, size: 16.sp, color: const Color(0xFF64748B)),
              ),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.sp,
                      color: const Color(0xFF64748B),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14.sp,
                      color: const Color(0xFF1E293B),
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (trailing != null) ...[
              trailing,
              SizedBox(width: 8.w),
            ],
            if (onEdit != null)
              Semantics(
                button: true,
                label: 'Edit $label',
                child: IconButton(
                  icon: Icon(Icons.edit_outlined, size: 18.sp, color: const Color(0xFF94A3B8)),
                  onPressed: onEdit,
                  tooltip: 'Edit $label',
                  splashRadius: 20.r,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDocumentSection(String label, VaultDocument? doc, Function(VaultDocument) onUpload, VoidCallback onDelete, VaultProvider provider, String folderName) {
    final bool hasDoc = doc != null && doc.url.isNotEmpty;
    return StateWithHover(
      builder: (context, isHovered) {
        return Semantics(
          label: '$label section. ${hasDoc ? 'Document is available: ${doc.name}' : 'No document uploaded'}',
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.all(12.r),
            decoration: BoxDecoration(
              color: isHovered ? const Color(0xFFE2E8F0) : const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12.r),
              border: Border.all(color: isHovered ? const Color(0xFFCBD5E1) : const Color(0xFFE2E8F0)),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Container(
                    padding: EdgeInsets.all(8.r),
                    decoration: BoxDecoration(
                      color: hasDoc ? const Color(0xFF2563EB).withOpacity(0.1) : Colors.white,
                      borderRadius: BorderRadius.circular(8.r),
                    ),
                    child: Icon(
                      hasDoc ? Icons.description_outlined : Icons.upload_file_outlined, 
                      color: hasDoc ? const Color(0xFF2563EB) : const Color(0xFF64748B),
                      size: 20.sp,
                    ),
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Text(
                    hasDoc ? doc.name : 'Upload Document',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                      color: hasDoc ? const Color(0xFF1E293B) : const Color(0xFF64748B),
                    ),
                  ),
                ),
                if (hasDoc) ...[
                  Semantics(
                    button: true,
                    label: 'View $label',
                    child: IconButton(
                      icon: Icon(Icons.visibility_outlined, size: 20.sp, color: const Color(0xFF2563EB)),
                      onPressed: () => _viewDocument(doc.url, doc.name),
                      tooltip: 'View Document',
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Share $label',
                    child: IconButton(
                      icon: Icon(Icons.share_outlined, size: 20.sp, color: const Color(0xFF13b1f2)),
                      onPressed: () {
                        ShareHelper.shareDocument(
                          context,
                          url: doc.url,
                          title: doc.name,
                        );
                      },
                      tooltip: 'Share Document',
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Download $label',
                    child: IconButton(
                      icon: Icon(Icons.download_outlined, size: 20.sp, color: const Color(0xFF10B981)),
                      onPressed: () => _downloadFile(doc.url),
                      tooltip: 'Download Document',
                    ),
                  ),
                  Semantics(
                    button: true,
                    label: 'Delete $label',
                    child: IconButton(
                      icon: Icon(Icons.delete_outline, size: 20.sp, color: const Color(0xFFF43F5E)),
                      onPressed: onDelete,
                      tooltip: 'Delete Document',
                    ),
                  ),
                ],
                Semantics(
                  button: true,
                  label: hasDoc ? 'Replace $label' : 'Upload $label',
                  child: IconButton(
                    icon: Icon(hasDoc ? Icons.refresh_outlined : Icons.add_circle_outline, 
                               size: 20.sp, 
                               color: const Color(0xFF2563EB)),
                    onPressed: () => _uploadDocument(onUpload, provider, folderName),
                    tooltip: hasDoc ? 'Replace Document' : 'Upload Document',
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildExpiryBadge(DateTime? expiryDate, int alertDays) {
    if (expiryDate == null) return const SizedBox.shrink();

    final now = DateTime.now();
    final difference = expiryDate.difference(now).inDays;
    
    Color baseColor;
    String label;
    IconData icon;

    if (difference < 0) {
      baseColor = const Color(0xFFF43F5E); // Rose
      label = 'Expired';
      icon = Icons.error_outline;
    } else if (difference <= alertDays) {
      baseColor = const Color(0xFFF59E0B); // Amber
      label = 'Expiring in $difference d'; // Using 'd' for space
      icon = Icons.warning_amber_rounded;
    } else {
      baseColor = const Color(0xFF10B981); // Emerald
      label = 'Active';
      icon = Icons.check_circle_outline;
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 4.h),
      decoration: BoxDecoration(
        color: baseColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6.r),
        border: Border.all(color: baseColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: baseColor, size: 12.sp),
          SizedBox(width: 4.w),
          Text(
            label,
            style: GoogleFonts.plusJakartaSans(
              color: baseColor,
              fontSize: 10.sp,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildVatFilingsTab(VaultProvider provider) {
    if (provider.vatFilings.isEmpty && !provider.isLoading) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.receipt_long_outlined, size: 64.r, color: const Color(0xFFCBD5E1)),
            SizedBox(height: 16.h),
            Text(
              'No VAT filings recorded',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 18.sp,
                color: const Color(0xFF64748B),
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 8.h),
            ElevatedButton.icon(
              onPressed: () => _showAddFilingDialog(context),
              icon: const Icon(Icons.add),
              label: const Text('Add First Filing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.r)),
              ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        ListView(
          padding: EdgeInsets.all(24.r),
          children: [
            _buildVatSummary(provider),
            SizedBox(height: 24.h),
            ...provider.vatFilings.map((filing) {
              return Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16.r),
                    border: Border.all(color: const Color(0xFFE2E8F0)),
                  ),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.symmetric(horizontal: 20.w, vertical: 8.h),
                    iconColor: const Color(0xFF0F172A),
                    title: Text(
                      'Filing: ${DateFormat('dd MMM yyyy').format(filing.date)}',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.bold,
                        fontSize: 15.sp,
                      ),
                    ),
                    subtitle: Padding(
                      padding: EdgeInsets.only(top: 4.h),
                      child: Row(
                        children: [
                          Text(
                            '${filing.currency} ${NumberFormat('#,##0.00').format(filing.amount)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF2563EB),
                              fontWeight: FontWeight.w700,
                              fontSize: 13.sp,
                            ),
                          ),
                          SizedBox(width: 8.w),
                          Container(width: 4.w, height: 4.h, decoration: const BoxDecoration(color: Color(0xFF94A3B8), shape: BoxShape.circle)),
                          if (filing.billNumber.isNotEmpty) ...[
                            SizedBox(width: 8.w),
                            Text(
                              'Bill: ${filing.billNumber}',
                              style: GoogleFonts.plusJakartaSans(
                                color: const Color(0xFF64748B),
                                fontSize: 12.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            SizedBox(width: 8.w),
                            Container(width: 4.w, height: 4.h, decoration: const BoxDecoration(color: Color(0xFF94A3B8), shape: BoxShape.circle)),
                          ],
                          SizedBox(width: 8.w),
                          Text(
                            '${DateFormat('dd/MM/yy').format(filing.fromDate)} - ${DateFormat('dd/MM/yy').format(filing.toDate)}',
                            style: GoogleFonts.plusJakartaSans(
                              color: const Color(0xFF64748B),
                              fontSize: 12.sp,
                            ),
                          ),
                        ],
                      ),
                    ),
                    children: [
                      Container(
                        padding: EdgeInsets.all(20.r),
                        decoration: const BoxDecoration(
                          color: Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.vertical(bottom: Radius.circular(16)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Documents (${filing.documents.length})',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13.sp,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                Row(
                                  children: [
                                    Semantics(
                                      button: true,
                                      label: 'Edit VAT filing',
                                      child: IconButton(
                                        icon: Icon(Icons.edit_outlined, color: const Color(0xFF64748B), size: 20.sp),
                                        onPressed: () => _showAddFilingDialog(context, filing: filing),
                                      ),
                                    ),
                                    Semantics(
                                      button: true,
                                      label: 'Delete VAT filing',
                                      child: IconButton(
                                        icon: Icon(Icons.delete_outline, color: const Color(0xFFF43F5E), size: 20.sp),
                                        onPressed: () => _confirmDeleteVatFiling(context, provider, filing),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            SizedBox(height: 12.h),
                            if (filing.documents.isEmpty)
                              Text('No documents uploaded.', style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 12.sp))
                            else
                              Wrap(
                                spacing: 8.w,
                                runSpacing: 8.h,
                                  children: filing.documents.map((doc) {
                                    return Container(
                                      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 6.h),
                                      decoration: BoxDecoration(
                                        color: Colors.white,
                                        borderRadius: BorderRadius.circular(8.r),
                                        border: Border.all(color: const Color(0xFFE2E8F0)),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.file_present_outlined, size: 16.sp, color: const Color(0xFF2563EB)),
                                          SizedBox(width: 8.w),
                                          Flexible(
                                            child: ConstrainedBox(
                                              constraints: BoxConstraints(maxWidth: 120.w),
                                              child: Text(
                                                doc.name,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 12.sp,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF1E293B),
                                                ),
                                              ),
                                            ),
                                          ),
                                          SizedBox(width: 4.w),
                                          IconButton(
                                            icon: Icon(Icons.visibility_outlined, size: 16.sp, color: const Color(0xFF64748B)),
                                            onPressed: () => _viewDocument(doc.url, doc.name),
                                            constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
                                            padding: EdgeInsets.zero,
                                            tooltip: 'View',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.share_outlined, size: 16.sp, color: const Color(0xFFF59E0B)),
                                            onPressed: () => ShareHelper.shareDocument(context, url: doc.url, title: doc.name),
                                            constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
                                            padding: EdgeInsets.zero,
                                            tooltip: 'Share',
                                          ),
                                          IconButton(
                                            icon: Icon(Icons.download_outlined, size: 16.sp, color: const Color(0xFF10B981)),
                                            onPressed: () => _downloadFile(doc.url),
                                            constraints: BoxConstraints(minWidth: 32.w, minHeight: 32.h),
                                            padding: EdgeInsets.zero,
                                            tooltip: 'Download',
                                          ),
                                        ],
                                      ),
                                    );
                                  }).toList(),
                              )
                          ],
                        ),
                      )
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
        Positioned(
          bottom: 24.h,
          right: 24.w,
          child: Semantics(
            label: 'Add new VAT filing',
            button: true,
            child: FloatingActionButton.extended(
              heroTag: 'add_vat_filing_new',
              onPressed: () => _showAddFilingDialog(context),
              backgroundColor: const Color(0xFF0F172A),
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text('New Filing', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600)),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildVatSummary(VaultProvider provider) {
    if (provider.vatFilings.isEmpty) return const SizedBox.shrink();

    final totalAmount = provider.vatFilings.fold<double>(0, (sum, item) => sum + item.amount);
    final lastFiling = provider.vatFilings.first;

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -20,
            top: -20,
            child: Icon(
              Icons.account_balance_outlined,
              size: 150.sp,
              color: Colors.white.withOpacity(0.03),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(24.r),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total VAT Filed',
                    'SAR ${NumberFormat('#,##0.00').format(totalAmount)}',
                    Icons.account_balance_wallet_outlined,
                  ),
                ),
                Container(
                  width: 1,
                  height: 48.h,
                  color: Colors.white.withOpacity(0.1),
                  margin: EdgeInsets.symmetric(horizontal: 24.w),
                ),
                Expanded(
                  child: _buildSummaryItem(
                    'Recent Filing',
                    DateFormat('dd MMM yyyy').format(lastFiling.date),
                    Icons.history_rounded,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value, IconData icon) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(4.r),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Icon(icon, color: Colors.white70, size: 12.sp),
            ),
            SizedBox(width: 8.w),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white70,
                fontSize: 10.sp,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.5,
              ),
            ),
          ],
        ),
        SizedBox(height: 8.h),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 18.sp,
            fontWeight: FontWeight.w800,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ],
    );
  }

  Widget _buildAlertSettingsTab(VaultProvider provider) {
    final data = provider.vaultData;
    if (data == null) return const SizedBox.shrink();

    return SingleChildScrollView(
      padding: EdgeInsets.all(24.r),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(
            'Expiry Alert Configurations',
            'Configure how many days in advance you want to receive notifications for company documents.',
          ),
          SizedBox(height: 32.h),
          _buildAlertSettingCard(
            title: 'Commercial License Alert',
            subtitle: 'Recommended: 30 Days',
            currentValue: data.license.alertDays,
            icon: Icons.business_center_outlined,
            color: const Color(0xFF3B82F6),
            onTap: () => _editText(
              'Alert Days',
              data.license.alertDays.toString(),
              (v) {
                final days = int.tryParse(v);
                if (days != null) _updateLicense(provider, alertDays: days);
              },
              keyboardType: TextInputType.number,
            ),
          ),
          SizedBox(height: 16.h),
          _buildAlertSettingCard(
            title: 'VAT Certificate Alert',
            subtitle: 'Recommended: 15 Days',
            currentValue: data.vatCertificate.alertDays,
            icon: Icons.receipt_long_outlined,
            color: const Color(0xFF10B981),
            onTap: () => _editText(
              'Alert Days',
              data.vatCertificate.alertDays.toString(),
              (v) {
                final days = int.tryParse(v);
                if (days != null) _updateVatCert(provider, alertDays: days);
              },
              keyboardType: TextInputType.number,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 8.h),
        Text(
          subtitle,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 13.sp,
            color: const Color(0xFF64748B),
            height: 1.5,
          ),
        ),
      ],
    );
  }

  Widget _buildAlertSettingCard({
    required String title,
    required String subtitle,
    required int currentValue,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return StateWithHover(
      builder: (context, isHovered) {
        return Semantics(
          button: true,
          label: 'Configure $title. Current threshold is $currentValue days.',
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(16.r),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.all(20.r),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16.r),
                border: Border.all(color: isHovered ? color.withOpacity(0.5) : const Color(0xFFE2E8F0)),
                boxShadow: [
                  BoxShadow(
                    color: isHovered ? color.withOpacity(0.05) : Colors.black.withOpacity(0.01),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: Container(
                      padding: EdgeInsets.all(12.r),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(icon, color: color, size: 24.sp),
                    ),
                  ),
                  SizedBox(width: 16.w),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15.sp,
                            fontWeight: FontWeight.bold,
                            color: const Color(0xFF1E293B),
                          ),
                        ),
                        Text(
                          subtitle,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.sp,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    child: Row(
                      children: [
                        Text(
                          '$currentValue',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF0F172A),
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          'Days',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.sp,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Icon(Icons.chevron_right, color: const Color(0xFF94A3B8), size: 20.sp),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // --- Helper Methods ---

  Future<void> _pickDate(DateTime? initialDate, Function(DateTime) onUpdate) async {
    final newDate = await showDatePicker(
      context: context,
      initialDate: initialDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF0F172A),
              onPrimary: Colors.white,
              onSurface: Color(0xFF1E293B),
            ),
          ),
          child: child!,
        );
      },
    );
    if (newDate != null) onUpdate(newDate);
  }

  Future<void> _editText(String label, String value, Function(String) onUpdate, {TextInputType? keyboardType}) async {
    final controller = TextEditingController(text: value);
    final result = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
          title: Text('Edit $label', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
          content: TextField(
            controller: controller,
            keyboardType: keyboardType,
            autofocus: true,
            decoration: InputDecoration(
              filled: true,
              fillColor: const Color(0xFFF1F5F9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12.r), borderSide: BorderSide.none),
              hintText: 'Enter $label…',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: TextStyle(color: const Color(0xFF64748B))),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, controller.text),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
              ),
              child: const Text('Save Changes'),
            ),
          ],
        );
      },
    );
    if (result != null) onUpdate(result);
  }

  void _viewDocument(String url, String title) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DocumentViewerScreen(
          attachmentUrl: url,
          title: title,
        ),
      ),
    );
  }

  Future<void> _downloadFile(String url) async {
    final uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not download file')),
        );
      }
    }
  }

  Future<void> _uploadDocument(Function(VaultDocument) onUpload, VaultProvider provider, String folderName) async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        withData: false, // avoid loading full bytes into memory before we need
      );
      if (result != null && result.files.isNotEmpty && result.files.single.path != null) {
        final pf = result.files.single;
        final xFile = XFile(pf.path!);

        // Size check using XFile.length()
        final fileSize = await xFile.length();
        if (fileSize > 5 * 1024 * 1024) { // 5MB limit
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('File size must be less than 5MB')),
            );
          }
          return;
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Uploading document...')),
          );
        }

        final uploadedDoc = await provider.uploadDocument(xFile, folderName);
        if (uploadedDoc != null) {
          onUpload(uploadedDoc);
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('✅ Upload successful')),
            );
          }
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).hideCurrentSnackBar();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(provider.errorMessage ?? 'Upload failed')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _updateLicense(VaultProvider provider, {DateTime? issueDate, DateTime? expiryDate, String? registrationNo, VaultDocument? document, int? alertDays}) async {
    final currentData = provider.vaultData!;
    final newLicense = CommercialLicense(
      issueDate: issueDate ?? currentData.license.issueDate,
      expiryDate: expiryDate ?? currentData.license.expiryDate,
      registrationNo: registrationNo ?? currentData.license.registrationNo,
      document: document ?? currentData.license.document,
      alertDays: alertDays ?? currentData.license.alertDays,
    );
    final newData = VaultData(license: newLicense, vatCertificate: currentData.vatCertificate);
    await provider.updateVaultData(newData);
  }

  Future<void> _updateVatCert(VaultProvider provider, {DateTime? issueDate, String? vatAccountNo, VaultDocument? document, int? alertDays}) async {
    final currentData = provider.vaultData!;
    final newCert = VatCertificate(
      issueDate: issueDate ?? currentData.vatCertificate.issueDate,
      vatAccountNo: vatAccountNo ?? currentData.vatCertificate.vatAccountNo,
      document: document ?? currentData.vatCertificate.document,
      alertDays: alertDays ?? currentData.vatCertificate.alertDays,
    );
    final newData = VaultData(license: currentData.license, vatCertificate: newCert);
    await provider.updateVaultData(newData);
  }

  void _showAddFilingDialog(BuildContext context, {VatFiling? filing}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => VatFilingDialog(filing: filing),
    );
  }

  void _confirmDeleteVatFiling(BuildContext context, VaultProvider provider, VatFiling filing) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.r)),
        title: Text('Delete VAT Filing', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to delete this record? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF43F5E), 
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.r)),
            ),
            onPressed: () async {
              final success = await provider.deleteVatFiling(filing.id);
              if (mounted) {
                Navigator.pop(context);
                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('VAT filing deleted successfully')),
                  );
                }
              }
            },
            child: const Text('Delete Permanently'),
          ),
        ],
      ),
    );
  }
}

class StateWithHover extends StatefulWidget {
  final Widget Function(BuildContext context, bool isHovered) builder;
  const StateWithHover({super.key, required this.builder});

  @override
  State<StateWithHover> createState() => _StateWithHoverState();
}

class _StateWithHoverState extends State<StateWithHover> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: widget.builder(context, _isHovered),
    );
  }
}
