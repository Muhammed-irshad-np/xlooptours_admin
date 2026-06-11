import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:xloop_invoice/features/driver_evaluation/domain/entities/evaluation_entity.dart';
import 'package:xloop_invoice/features/driver_evaluation/presentation/providers/admin_evaluation_provider.dart';

class EvaluationDetailScreen extends StatefulWidget {
  final EvaluationEntity evaluation;

  const EvaluationDetailScreen({super.key, required this.evaluation});

  @override
  State<EvaluationDetailScreen> createState() => _EvaluationDetailScreenState();
}

class _EvaluationDetailScreenState extends State<EvaluationDetailScreen> {
  int _fullBodyScore = 0;
  int _shoesScore = 0;
  int _vehicleFrontScore = 0;
  int _vehicleBackScore = 0;
  int _vehicleLeftScore = 0;
  int _vehicleRightScore = 0;
  int _cabinFrontScore = 0;
  int _cabinRearScore = 0;
  bool _passed = true;
  final TextEditingController _remarksController = TextEditingController();
  bool _isInitialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      if (widget.evaluation.scores != null) {
        final details = widget.evaluation.scores!['details'] as Map<String, dynamic>?;
        if (details != null) {
          _fullBodyScore = details['full_body'] as int? ?? 0;
          _shoesScore = details['shoes'] as int? ?? 0;
          _vehicleFrontScore = details['vehicle_front'] as int? ?? 0;
          _vehicleBackScore = details['vehicle_back'] as int? ?? 0;
          _vehicleLeftScore = details['vehicle_left'] as int? ?? 0;
          _vehicleRightScore = details['vehicle_right'] as int? ?? 0;
          _cabinFrontScore = details['cabin_front'] as int? ?? 0;
          _cabinRearScore = details['cabin_rear'] as int? ?? 0;
        } else {
          // Fallback to legacy averages
          final legacyApp = (widget.evaluation.scores!['appearance'] as num? ?? 0).round();
          final legacyVeh = (widget.evaluation.scores!['vehicle'] as num? ?? 0).round();
          _fullBodyScore = legacyApp;
          _shoesScore = legacyApp;
          _vehicleFrontScore = legacyVeh;
          _vehicleBackScore = legacyVeh;
          _vehicleLeftScore = legacyVeh;
          _vehicleRightScore = legacyVeh;
          _cabinFrontScore = legacyVeh;
          _cabinRearScore = legacyVeh;
        }
        _passed = widget.evaluation.scores!['passed'] as bool? ?? true;
        _remarksController.text = widget.evaluation.scores!['remarks'] as String? ?? '';
      } else {
        _passed = true;
      }
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  void _suggestPassFail() {
    final double avg = (_fullBodyScore +
            _shoesScore +
            _vehicleFrontScore +
            _vehicleBackScore +
            _vehicleLeftScore +
            _vehicleRightScore +
            _cabinFrontScore +
            _cabinRearScore) /
        8.0;
    setState(() {
      _passed = avg >= 3.0;
    });
  }

  Widget _buildMediaGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Appearance Photos',
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 12.h),
        _buildMediaGrid(const ['full_body', 'shoes']),
        SizedBox(height: 24.h),
        const Divider(),
        SizedBox(height: 24.h),
        Text(
          'Vehicle Condition Photos',
          style: GoogleFonts.inter(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 12.h),
        _buildMediaGrid(const [
          'vehicle_front',
          'vehicle_back',
          'vehicle_left',
          'vehicle_right',
          'cabin_front',
          'cabin_rear',
        ]),
      ],
    );
  }

  Widget _buildScoringForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Scoring & Assessment',
          style: GoogleFonts.inter(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 24.h),
        Text(
          'DRIVER APPEARANCE DETAILS',
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: const Color(0xFF64748B),
          ),
        ),
        SizedBox(height: 16.h),
        _buildStarScoringSection(
          title: 'Full Body Uniform',
          subtitle: 'Grooming and uniform correctness.',
          score: _fullBodyScore,
          onChanged: (val) {
            setState(() {
              _fullBodyScore = val;
              _suggestPassFail();
            });
          },
        ),
        SizedBox(height: 18.h),
        _buildStarScoringSection(
          title: 'Shoes Condition',
          subtitle: 'Shoes cleanliness and uniform compliance.',
          score: _shoesScore,
          onChanged: (val) {
            setState(() {
              _shoesScore = val;
              _suggestPassFail();
            });
          },
        ),
        SizedBox(height: 24.h),
        const Divider(),
        SizedBox(height: 24.h),
        Text(
          'VEHICLE CONDITION DETAILS',
          style: GoogleFonts.inter(
            fontSize: 11.sp,
            fontWeight: FontWeight.bold,
            letterSpacing: 1.0,
            color: const Color(0xFF64748B),
          ),
        ),
        SizedBox(height: 16.h),
        _buildStarScoringSection(
          title: 'Vehicle Front',
          subtitle: 'Front bumper, grille, and headlights.',
          score: _vehicleFrontScore,
          onChanged: (val) {
            setState(() {
              _vehicleFrontScore = val;
              _suggestPassFail();
            });
          },
        ),
        SizedBox(height: 18.h),
        _buildStarScoringSection(
          title: 'Vehicle Back',
          subtitle: 'Rear bumper, taillights, and trunk.',
          score: _vehicleBackScore,
          onChanged: (val) {
            setState(() {
              _vehicleBackScore = val;
              _suggestPassFail();
            });
          },
        ),
        SizedBox(height: 18.h),
        _buildStarScoringSection(
          title: 'Vehicle Left',
          subtitle: 'Driver side panels, doors, and tires.',
          score: _vehicleLeftScore,
          onChanged: (val) {
            setState(() {
              _vehicleLeftScore = val;
              _suggestPassFail();
            });
          },
        ),
        SizedBox(height: 18.h),
        _buildStarScoringSection(
          title: 'Vehicle Right',
          subtitle: 'Passenger side panels, doors, and tires.',
          score: _vehicleRightScore,
          onChanged: (val) {
            setState(() {
              _vehicleRightScore = val;
              _suggestPassFail();
            });
          },
        ),
        SizedBox(height: 18.h),
        _buildStarScoringSection(
          title: 'Front Cabin Interior',
          subtitle: 'Dashboard, steering wheel, and front seats neatness.',
          score: _cabinFrontScore,
          onChanged: (val) {
            setState(() {
              _cabinFrontScore = val;
              _suggestPassFail();
            });
          },
        ),
        SizedBox(height: 18.h),
        _buildStarScoringSection(
          title: 'Rear Cabin Interior',
          subtitle: 'Rear seats, floor mats, and passenger cabin cleanliness.',
          score: _cabinRearScore,
          onChanged: (val) {
            setState(() {
              _cabinRearScore = val;
              _suggestPassFail();
            });
          },
        ),
        SizedBox(height: 24.h),
        const Divider(),
        SizedBox(height: 24.h),
        Text(
          'Evaluation Result',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 8.h),
        Row(
          children: [
            Text(
              'Result Status:',
              style: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF64748B)),
            ),
            const Spacer(),
            ChoiceChip(
              label: Text('Pass', style: TextStyle(fontWeight: FontWeight.bold, color: _passed ? Colors.green[800] : Colors.grey[800])),
              selected: _passed,
              selectedColor: Colors.green[50],
              onSelected: (selected) {
                setState(() {
                  _passed = true;
                });
              },
            ),
            SizedBox(width: 12.w),
            ChoiceChip(
              label: Text('Fail', style: TextStyle(fontWeight: FontWeight.bold, color: !_passed ? Colors.red[800] : Colors.grey[800])),
              selected: !_passed,
              selectedColor: Colors.red[50],
              onSelected: (selected) {
                setState(() {
                  _passed = false;
                });
              },
            ),
          ],
        ),
        SizedBox(height: 24.h),
        Text(
          'Remarks',
          style: GoogleFonts.inter(
            fontSize: 16.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF0F172A),
          ),
        ),
        SizedBox(height: 8.h),
        TextField(
          controller: _remarksController,
          maxLines: 4,
          style: GoogleFonts.inter(fontSize: 14.sp),
          decoration: InputDecoration(
            hintText: 'Enter notes, areas of improvement, or reasons for failure…',
            hintStyle: GoogleFonts.inter(fontSize: 14.sp, color: const Color(0xFF94A3B8)),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8.r),
              borderSide: const BorderSide(color: Color(0xFF13B1F2)),
            ),
          ),
        ),
        SizedBox(height: 32.h),
        Consumer<AdminEvaluationProvider>(
          builder: (context, provider, child) {
            return SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: provider.isLoading
                    ? null
                    : () async {
                        final double appAvg = (_fullBodyScore + _shoesScore) / 2.0;
                        final double vehAvg = (_vehicleFrontScore +
                                _vehicleBackScore +
                                _vehicleLeftScore +
                                _vehicleRightScore +
                                _cabinFrontScore +
                                _cabinRearScore) /
                            6.0;
                        final Map<String, dynamic> scoresData = {
                          'appearance': appAvg,
                          'vehicle': vehAvg,
                          'passed': _passed,
                          'remarks': _remarksController.text,
                          'details': {
                            'full_body': _fullBodyScore,
                            'shoes': _shoesScore,
                            'vehicle_front': _vehicleFrontScore,
                            'vehicle_back': _vehicleBackScore,
                            'vehicle_left': _vehicleLeftScore,
                            'vehicle_right': _vehicleRightScore,
                            'cabin_front': _cabinFrontScore,
                            'cabin_rear': _cabinRearScore,
                          }
                        };
                        final success = await provider.submitScore(
                          widget.evaluation.id,
                          scoresData,
                        );
                        if (success && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Evaluation submitted successfully!')),
                          );
                          Navigator.pop(context);
                        }
                      },
                style: ElevatedButton.styleFrom(
                  backgroundColor: _passed ? const Color(0xFF10B981) : const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: EdgeInsets.symmetric(vertical: 16.h),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  elevation: 0,
                ),
                child: provider.isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Submit Evaluation as ${_passed ? "Passed" : "Failed"}',
                        style: GoogleFonts.inter(fontSize: 16.sp, fontWeight: FontWeight.bold),
                      ),
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool isDesktop = MediaQuery.of(context).size.width > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          'Score Driver Submission',
          style: GoogleFonts.inter(
            fontSize: 20.sp,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF1E293B),
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: isDesktop
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 5,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24.r),
                    child: _buildMediaGallery(),
                  ),
                ),
                VerticalDivider(width: 1.w, color: const Color(0xFFE2E8F0)),
                SizedBox(
                  width: 450.w,
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(24.r),
                    child: _buildScoringForm(),
                  ),
                ),
              ],
            )
          : SingleChildScrollView(
              padding: EdgeInsets.all(24.r),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildMediaGallery(),
                  SizedBox(height: 32.h),
                  const Divider(),
                  SizedBox(height: 32.h),
                  _buildScoringForm(),
                ],
              ),
            ),
    );
  }

  Widget _buildMediaGrid(List<String> keys) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16.w,
        mainAxisSpacing: 16.h,
        childAspectRatio: 1.1,
      ),
      itemCount: keys.length,
      itemBuilder: (context, index) {
        final key = keys[index];
        final mediaItem = widget.evaluation.media[key];
        final label = _getPhotoLabel(key);

        if (mediaItem == null) {
          return Container(
            decoration: BoxDecoration(
              color: const Color(0xFFF1F5F9),
              borderRadius: BorderRadius.circular(12.r),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported, color: const Color(0xFF94A3B8), size: 32.r),
                  SizedBox(height: 8.h),
                  Text(
                    label,
                    style: TextStyle(color: const Color(0xFF94A3B8), fontSize: 12.sp, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Missing photo',
                    style: TextStyle(color: const Color(0xFFCBD5E1), fontSize: 10.sp),
                  ),
                ],
              ),
            ),
          );
        }

        final url = mediaItem['url'] as String;
        final timestampStr = mediaItem['timestamp'] as String?;
        final timeDisplay = timestampStr != null 
            ? DateFormat('hh:mm a, dd MMM yyyy').format(DateTime.parse(timestampStr))
            : 'No timestamp';

        return Card(
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12.r),
            side: BorderSide(color: const Color(0xFFE2E8F0), width: 1.w),
          ),
          elevation: 0,
          child: Stack(
            fit: StackFit.expand,
            children: [
              CachedNetworkImage(
                imageUrl: url,
                fit: BoxFit.cover,
                placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                errorWidget: (context, url, error) => const Icon(Icons.error),
              ),
              // Gradient bottom overlay
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.8),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12.sp,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        timeDisplay,
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 10.sp,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Positioned.fill(
                child: Material(
                  color: Colors.transparent,
                  child: Tooltip(
                    message: 'View fullscreen image',
                    child: InkWell(
                      onTap: () => _showFullscreenImage(context, url, label, timeDisplay),
                    ),
                  ),
                ),
              )
            ],
          ),
        );
      },
    );
  }

  void _showFullscreenImage(BuildContext context, String url, String label, String timeDisplay) {
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: EdgeInsets.all(40.r),
          child: Stack(
            alignment: Alignment.center,
            children: [
              InteractiveViewer(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(16.r),
                  child: CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.contain,
                    placeholder: (context, url) => const Center(child: CircularProgressIndicator()),
                    errorWidget: (context, url, error) => const Icon(Icons.error, color: Colors.white),
                  ),
                ),
              ),
              Positioned(
                top: 16.h,
                right: 16.w,
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white, size: 30),
                  tooltip: 'Close preview',
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Positioned(
                bottom: 24.h,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 24.w, vertical: 12.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(100.r),
                  ),
                  child: Text(
                    '$label - $timeDisplay',
                    style: TextStyle(color: Colors.white, fontSize: 14.sp, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStarScoringSection({
    required String title,
    required String subtitle,
    required int score,
    required ValueChanged<int> onChanged,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(16.r),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12.r),
        border: Border.all(color: const Color(0xFFE2E8F0), width: 1.w),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: const Color(0xFF1E293B),
            ),
          ),
          SizedBox(height: 4.h),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12.sp,
              color: const Color(0xFF64748B),
            ),
          ),
          SizedBox(height: 12.h),
          Row(
            children: List.generate(5, (index) {
              final starIndex = index + 1;
              return IconButton(
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
                icon: Icon(
                  starIndex <= score ? Icons.star_rounded : Icons.star_border_rounded,
                  color: starIndex <= score ? const Color(0xFFFBBF24) : const Color(0xFFCBD5E1),
                  size: 32.r,
                ),
                tooltip: '$starIndex Star${starIndex == 1 ? "" : "s"}',
                onPressed: () => onChanged(starIndex),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _getPhotoLabel(String key) {
    switch (key) {
      case 'full_body':
        return 'Full Body Uniform';
      case 'shoes':
        return 'Shoes Condition';
      case 'vehicle_front':
        return 'Vehicle Front';
      case 'vehicle_back':
        return 'Vehicle Back';
      case 'vehicle_left':
        return 'Vehicle Left';
      case 'vehicle_right':
        return 'Vehicle Right';
      case 'cabin_front':
        return 'Front Cabin Interior';
      case 'cabin_rear':
        return 'Rear Cabin Interior';
      default:
        return key;
    }
  }
}