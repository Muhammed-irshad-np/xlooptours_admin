import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:intl/intl.dart';

import '../features/feedback/domain/entities/feedback_entity.dart';
import '../features/feedback/presentation/providers/feedback_provider.dart';
import '../widgets/responsive_layout.dart';

class FeedbackHistoryScreen extends StatefulWidget {
  const FeedbackHistoryScreen({super.key});

  @override
  State<FeedbackHistoryScreen> createState() => _FeedbackHistoryScreenState();
}

class _FeedbackHistoryScreenState extends State<FeedbackHistoryScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _onlyIncidents = false;

  // Design Tokens consistent with dashboard_screen.dart
  static const Color _bgPage = Color(0xFFF4F6FB);
  static const Color _bgCard = Colors.white;
  static const Color _brand = Color(0xFF4F46E5);
  static const Color _danger = Color(0xFFDC2626);
  static const Color _dangerBg = Color(0xFFFFF1F2);
  static const Color _dangerBorder = Color(0xFFFFCDD2);
  static const Color _warning = Color(0xFFD97706);
  static const Color _textPrimary = Color(0xFF111827);
  static const Color _textSecondary = Color(0xFF6B7280);
  static const Color _textMuted = Color(0xFF9CA3AF);
  static const Color _border = Color(0xFFE5E7EB);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<FeedbackProvider>().fetchLatestFeedbacks(limit: 100);
    });
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  double _calculateAverageRating(FeedbackEntity f) {
    return (f.safetyRating +
            f.professionalismRating +
            f.communicationRating +
            f.punctualityRating +
            f.vehicleConditionRating) /
        5.0;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgPage,
      appBar: _buildAppBar(),
      body: Consumer<FeedbackProvider>(
        builder: (context, provider, _) {
          if (provider.isLoadingFeedbacks) {
            return const Center(
              child: CircularProgressIndicator(color: _brand),
            );
          }

          final feedbacks = provider.latestFeedbacks;

          if (feedbacks.isEmpty) {
            return _buildEmptyState();
          }

          // Compute analytics
          final totalCount = feedbacks.length;
          final incidentCount = feedbacks
              .where((f) => f.incidentReported)
              .length;
          double overallSum = 0;
          for (var f in feedbacks) {
            overallSum += _calculateAverageRating(f);
          }
          final averageRating = totalCount > 0 ? overallSum / totalCount : 0.0;

          // Filter feedbacks
          final filteredFeedbacks = feedbacks.where((f) {
            final matchesQuery =
                f.clientName.toLowerCase().contains(_searchQuery) ||
                f.driverName.toLowerCase().contains(_searchQuery) ||
                (f.areasOfExcellence?.toLowerCase().contains(_searchQuery) ??
                    false) ||
                (f.areasOfImprovement?.toLowerCase().contains(_searchQuery) ??
                    false);
            final matchesIncident = !_onlyIncidents || f.incidentReported;
            return matchesQuery && matchesIncident;
          }).toList();

          return SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(24.w, 28.h, 24.w, 40.h),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildAnalyticsCards(
                  total: totalCount,
                  average: averageRating,
                  incidents: incidentCount,
                ),
                SizedBox(height: 32.h),
                _buildSearchAndFilters(),
                SizedBox(height: 20.h),
                _buildFeedbackList(filteredFeedbacks),
              ],
            ),
          );
        },
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      backgroundColor: Colors.white,
      elevation: 0,
      centerTitle: false,
      title: Row(
        children: [
          Container(
            width: 36.w,
            height: 36.w,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Color(0xFF6366F1), Color(0xFF4F46E5)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(
              Icons.rate_review_rounded,
              color: Colors.white,
              size: 20.sp,
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            'Customer Feedbacks',
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w700,
              fontSize: 22.sp,
              color: _textPrimary,
              letterSpacing: -0.3,
            ),
          ),
        ],
      ),
      bottom: PreferredSize(
        preferredSize: Size.fromHeight(1.h),
        child: Container(height: 1.h, color: _border),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(24.w),
            decoration: BoxDecoration(
              color: _brand.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.rate_review_outlined, size: 48.sp, color: _brand),
          ),
          SizedBox(height: 20.h),
          Text(
            'No feedback received yet',
            style: GoogleFonts.inter(
              fontSize: 18.sp,
              fontWeight: FontWeight.bold,
              color: _textPrimary,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            'Generate custom links from the customer registry to share with clients.',
            style: GoogleFonts.inter(fontSize: 14.sp, color: _textSecondary),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsCards({
    required int total,
    required double average,
    required int incidents,
  }) {
    final cards = [
      _AnalyticsItem(
        label: 'Total Feedback',
        value: total.toString(),
        icon: Icons.chat_bubble_outline_rounded,
        color: _brand,
      ),
      _AnalyticsItem(
        label: 'Average Score',
        value: '${average.toStringAsFixed(1)} / 5.0',
        icon: Icons.star_border_rounded,
        color: _warning,
        isStars: true,
        starsVal: average,
      ),
      _AnalyticsItem(
        label: 'Incidents Flagged',
        value: incidents.toString(),
        icon: Icons.warning_amber_rounded,
        color: _danger,
        isWarning: incidents > 0,
      ),
    ];

    return ResponsiveLayout(
      mobile: Column(
        children: cards
            .map(
              (c) => Padding(
                padding: EdgeInsets.only(bottom: 16.h),
                child: _AnalyticsCard(item: c),
              ),
            )
            .toList(),
      ),
      tablet: Wrap(
        spacing: 16.w,
        runSpacing: 16.h,
        children: cards
            .map(
              (c) => SizedBox(
                width: 240.w,
                child: _AnalyticsCard(item: c),
              ),
            )
            .toList(),
      ),
      desktop: Row(
        children:
            cards
                .expand(
                  (c) => [
                    Expanded(child: _AnalyticsCard(item: c)),
                    SizedBox(width: 20.w),
                  ],
                )
                .toList()
              ..removeLast(),
      ),
    );
  }

  Widget _buildSearchAndFilters() {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: _bgCard,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(color: _border),
      ),
      child: Row(
        children: [
          // Search Field
          Expanded(
            child: Container(
              height: 48.h,
              decoration: BoxDecoration(
                color: _bgPage,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(color: _border),
              ),
              padding: EdgeInsets.symmetric(horizontal: 14.w),
              child: Row(
                children: [
                  Icon(Icons.search_rounded, color: _textMuted, size: 20.sp),
                  SizedBox(width: 10.w),
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: 'Search by customer, driver, comments...',
                        hintStyle: GoogleFonts.inter(
                          color: _textMuted,
                          fontSize: 14.sp,
                        ),
                        border: InputBorder.none,
                        isDense: true,
                      ),
                      style: GoogleFonts.inter(
                        color: _textPrimary,
                        fontSize: 14.sp,
                      ),
                    ),
                  ),
                  if (_searchQuery.isNotEmpty)
                    IconButton(
                      icon: Icon(
                        Icons.clear_rounded,
                        size: 18.sp,
                        color: _textMuted,
                      ),
                      onPressed: () => _searchController.clear(),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ),
          ),
          SizedBox(width: 16.w),
          // Incident Filter Toggle
          InkWell(
            onTap: () {
              setState(() {
                _onlyIncidents = !_onlyIncidents;
              });
            },
            borderRadius: BorderRadius.circular(10.r),
            child: Container(
              height: 48.h,
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              decoration: BoxDecoration(
                color: _onlyIncidents ? _dangerBg : Colors.transparent,
                borderRadius: BorderRadius.circular(10.r),
                border: Border.all(
                  color: _onlyIncidents ? _dangerBorder : _border,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    _onlyIncidents
                        ? Icons.warning_rounded
                        : Icons.warning_amber_rounded,
                    color: _onlyIncidents ? _danger : _textSecondary,
                    size: 18.sp,
                  ),
                  SizedBox(width: 8.w),
                  Text(
                    'Incidents Only',
                    style: GoogleFonts.inter(
                      fontSize: 13.sp,
                      fontWeight: _onlyIncidents
                          ? FontWeight.bold
                          : FontWeight.w500,
                      color: _onlyIncidents ? _danger : _textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeedbackList(List<FeedbackEntity> filteredFeedbacks) {
    if (filteredFeedbacks.isEmpty) {
      return Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(vertical: 48.h),
        decoration: BoxDecoration(
          color: _bgCard,
          borderRadius: BorderRadius.circular(16.r),
          border: Border.all(color: _border),
        ),
        child: Column(
          children: [
            Icon(Icons.search_off_rounded, color: _textMuted, size: 40.sp),
            SizedBox(height: 12.h),
            Text(
              'No matches found',
              style: GoogleFonts.inter(
                fontSize: 15.sp,
                fontWeight: FontWeight.bold,
                color: _textSecondary,
              ),
            ),
            SizedBox(height: 4.h),
            Text(
              'Try clearing your search query or toggling filters.',
              style: GoogleFonts.inter(color: _textMuted, fontSize: 13.sp),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: filteredFeedbacks.length,
      separatorBuilder: (_, __) => SizedBox(height: 16.h),
      itemBuilder: (context, index) {
        return _FeedbackTile(
          feedback: filteredFeedbacks[index],
          avgRating: _calculateAverageRating(filteredFeedbacks[index]),
        );
      },
    );
  }
}

class _AnalyticsItem {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final bool isStars;
  final double starsVal;
  final bool isWarning;

  const _AnalyticsItem({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.isStars = false,
    this.starsVal = 0,
    this.isWarning = false,
  });
}

class _AnalyticsCard extends StatelessWidget {
  final _AnalyticsItem item;

  const _AnalyticsCard({required this.item});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: item.isWarning
              ? Colors.red.withOpacity(0.3)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0A000000),
            blurRadius: 16,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12.w),
            decoration: BoxDecoration(
              color: item.color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, color: item.color, size: 24.sp),
          ),
          SizedBox(width: 16.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  item.label,
                  style: GoogleFonts.inter(
                    fontSize: 13.sp,
                    color: const Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 4.h),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      item.value,
                      style: GoogleFonts.inter(
                        fontSize: 20.sp,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF111827),
                      ),
                    ),
                    if (item.isStars && item.starsVal > 0) ...[
                      SizedBox(width: 8.w),
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: List.generate(5, (index) {
                          final isActive = index < item.starsVal.round();
                          return Icon(
                            isActive ? Icons.star : Icons.star_border,
                            color: isActive
                                ? Colors.amber[600]
                                : Colors.grey[300],
                            size: 14.sp,
                          );
                        }),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FeedbackTile extends StatefulWidget {
  final FeedbackEntity feedback;
  final double avgRating;

  const _FeedbackTile({required this.feedback, required this.avgRating});

  @override
  State<_FeedbackTile> createState() => _FeedbackTileState();
}

class _FeedbackTileState extends State<_FeedbackTile> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.feedback;
    final hasDetails =
        f.areasOfExcellence != null || f.areasOfImprovement != null;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16.r),
        border: Border.all(
          color: f.incidentReported
              ? const Color(0xFFDC2626).withOpacity(0.3)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x06000000),
            blurRadius: 10,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card Details
          Padding(
            padding: EdgeInsets.all(20.w),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Client initial Avatar
                CircleAvatar(
                  radius: 22.r,
                  backgroundColor: f.incidentReported
                      ? const Color(0xFFFFF1F2)
                      : const Color(0xFFF0FDF4),
                  child: Text(
                    f.clientName.isNotEmpty
                        ? f.clientName[0].toUpperCase()
                        : '?',
                    style: TextStyle(
                      color: f.incidentReported
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF16A34A),
                      fontWeight: FontWeight.bold,
                      fontSize: 16.sp,
                    ),
                  ),
                ),
                SizedBox(width: 16.w),
                // Client name and metadata
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  f.clientName,
                                  style: GoogleFonts.inter(
                                    fontSize: 15.sp,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFF111827),
                                  ),
                                ),
                                if (f.submitterName != null &&
                                    f.submitterName!.isNotEmpty) ...[
                                  SizedBox(height: 2.h),
                                  Text(
                                    'Client: ${f.submitterName}',
                                    style: GoogleFonts.inter(
                                      fontSize: 12.sp,
                                      fontWeight: FontWeight.w600,
                                      color: const Color(0xFF4F46E5),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          if (f.incidentReported) ...[
                            SizedBox(width: 8.w),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: 10.w,
                                vertical: 4.h,
                              ),
                              decoration: BoxDecoration(
                                color: const Color(0xFFFFF1F2),
                                borderRadius: BorderRadius.circular(12.r),
                                border: Border.all(
                                  color: const Color(0xFFFFCDD2),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.warning_amber_rounded,
                                    color: const Color(0xFFDC2626),
                                    size: 12.sp,
                                  ),
                                  SizedBox(width: 4.w),
                                  Text(
                                    'Incident Reported',
                                    style: GoogleFonts.inter(
                                      fontSize: 11.sp,
                                      fontWeight: FontWeight.w700,
                                      color: const Color(0xFFDC2626),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                      SizedBox(height: 6.h),
                      // Meta details: Driver, Trip Date, Created Time
                      Wrap(
                        spacing: 16.w,
                        runSpacing: 6.h,
                        children: [
                          _buildMetaChip(
                            icon: Icons.person_outline_rounded,
                            label: 'Driver: ${f.driverName}',
                          ),
                          _buildMetaChip(
                            icon: Icons.calendar_today_outlined,
                            label:
                                'Trip: ${DateFormat('dd-MM-yyyy').format(f.dateOfTrip)}',
                          ),
                          _buildMetaChip(
                            icon: Icons.access_time_rounded,
                            label: timeago.format(f.createdAt),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                SizedBox(width: 16.w),
                // Rating visual block
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: Colors.amber[600],
                          size: 20.sp,
                        ),
                        SizedBox(width: 4.w),
                        Text(
                          widget.avgRating.toStringAsFixed(1),
                          style: GoogleFonts.inter(
                            fontSize: 16.sp,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF111827),
                          ),
                        ),
                        Text(
                          ' / 5',
                          style: GoogleFonts.inter(
                            fontSize: 12.sp,
                            color: const Color(0xFF9CA3AF),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 6.h),
                    // Dropdown Toggle
                    IconButton(
                      icon: Icon(
                        _isExpanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: const Color(0xFF6B7280),
                      ),
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Collapsible sub-ratings & comments
          if (_isExpanded) ...[
            Container(height: 1.h, color: const Color(0xFFF3F4F6)),
            Padding(
              padding: EdgeInsets.all(20.w),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (f.incidentReported) ...[
                    Container(
                      padding: EdgeInsets.all(16.w),
                      margin: EdgeInsets.only(bottom: 20.h),
                      decoration: BoxDecoration(
                        color: _FeedbackHistoryScreenState._dangerBg,
                        border: Border.all(
                          color: _FeedbackHistoryScreenState._dangerBorder,
                        ),
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: _FeedbackHistoryScreenState._danger,
                                size: 18.sp,
                              ),
                              SizedBox(width: 8.w),
                              Text(
                                'Reported Incident Details',
                                style: GoogleFonts.inter(
                                  color: _FeedbackHistoryScreenState._danger,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13.sp,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 8.h),
                          Text(
                            f.incidentDescription ?? 'No details provided.',
                            style: GoogleFonts.inter(
                              color: const Color(0xFF991B1B),
                              fontSize: 13.sp,
                              height: 1.5,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  // Individual Ratings Grid
                  Text(
                    'SERVICE RATINGS BREAKDOWN',
                    style: GoogleFonts.inter(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.0,
                      color: const Color(0xFF6B7280),
                    ),
                  ),
                  SizedBox(height: 12.h),
                  ResponsiveLayout(
                    mobile: Column(
                      children: [
                        _buildBreakdownTile('Safety', f.safetyRating),
                        _buildBreakdownTile(
                          'Professionalism',
                          f.professionalismRating,
                        ),
                        _buildBreakdownTile(
                          'Communication',
                          f.communicationRating,
                        ),
                        _buildBreakdownTile('Punctuality', f.punctualityRating),
                        _buildBreakdownTile(
                          'Vehicle Cleanliness',
                          f.vehicleConditionRating,
                        ),
                      ],
                    ),
                    desktop: Row(
                      children: [
                        Expanded(
                          child: Column(
                            children: [
                              _buildBreakdownTile('Safety', f.safetyRating),
                              _buildBreakdownTile(
                                'Professionalism',
                                f.professionalismRating,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 32.w),
                        Expanded(
                          child: Column(
                            children: [
                              _buildBreakdownTile(
                                'Communication',
                                f.communicationRating,
                              ),
                              _buildBreakdownTile(
                                'Punctuality',
                                f.punctualityRating,
                              ),
                            ],
                          ),
                        ),
                        SizedBox(width: 32.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              _buildBreakdownTile(
                                'Vehicle Cleanliness',
                                f.vehicleConditionRating,
                              ),
                              const SizedBox(),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Open Ended Feedback
                  if (hasDetails) ...[
                    SizedBox(height: 20.h),
                    const Divider(),
                    SizedBox(height: 16.h),
                    if (f.areasOfExcellence != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.star,
                            color: const Color(0xFF16A34A),
                            size: 16.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Areas of Excellence',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF16A34A),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  f.areasOfExcellence!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    height: 1.5,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (f.areasOfImprovement != null) SizedBox(height: 16.h),
                    ],
                    if (f.areasOfImprovement != null) ...[
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.warning_amber_rounded,
                            color: const Color(0xFFDC2626),
                            size: 16.sp,
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Areas of Improvement',
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFFDC2626),
                                  ),
                                ),
                                SizedBox(height: 4.h),
                                Text(
                                  f.areasOfImprovement!,
                                  style: GoogleFonts.inter(
                                    fontSize: 13.sp,
                                    height: 1.5,
                                    color: const Color(0xFF4B5563),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetaChip({required IconData icon, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: const Color(0xFF9CA3AF), size: 14.sp),
        SizedBox(width: 6.w),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12.sp,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF6B7280),
          ),
        ),
      ],
    );
  }

  Widget _buildBreakdownTile(String label, int val) {
    return Padding(
      padding: EdgeInsets.only(bottom: 10.h),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13.sp,
                color: const Color(0xFF4B5563),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            flex: 3,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: val / 5.0,
                    backgroundColor: const Color(0xFFF3F4F6),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      val >= 4
                          ? const Color(0xFF16A34A)
                          : (val >= 3
                                ? const Color(0xFFD97706)
                                : const Color(0xFFDC2626)),
                    ),
                    minHeight: 6.h,
                    borderRadius: BorderRadius.circular(3.r),
                  ),
                ),
                SizedBox(width: 12.w),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(5, (idx) {
                    return Icon(
                      idx < val
                          ? Icons.star_rounded
                          : Icons.star_outline_rounded,
                      color: idx < val ? Colors.amber[600] : Colors.grey[300],
                      size: 14.sp,
                    );
                  }),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
