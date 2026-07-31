import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

/// A shimmer effect widget that provides a pulsing placeholder animation.
/// Used to show content placeholders while data is loading.
class ShimmerEffect extends StatefulWidget {
  final Widget child;

  const ShimmerEffect({super.key, required this.child});

  @override
  State<ShimmerEffect> createState() => _ShimmerEffectState();
}

class _ShimmerEffectState extends State<ShimmerEffect>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: 0.4 + (_animation.value * 0.4),
          child: widget.child,
        );
      },
    );
  }
}

/// A rounded rectangle placeholder block for shimmer loading.
class SkeletonBlock extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;

  const SkeletonBlock({
    super.key,
    required this.width,
    required this.height,
    this.borderRadius = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300],
        borderRadius: BorderRadius.circular(borderRadius),
      ),
    );
  }
}

/// Skeleton loader for a list item (employee, vehicle, customer, shop).
class SkeletonListItem extends StatelessWidget {
  const SkeletonListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Card(
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.r),
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 12.h),
          child: Row(
            children: [
              // Avatar placeholder
              CircleAvatar(
                radius: 22.r,
                backgroundColor: Colors.grey[300],
              ),
              SizedBox(width: 12.w),
              // Text lines
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SkeletonBlock(width: 140.w, height: 14.h),
                    SizedBox(height: 8.h),
                    SkeletonBlock(width: 200.w, height: 10.h),
                    SizedBox(height: 4.h),
                    SkeletonBlock(width: 120.w, height: 10.h),
                  ],
                ),
              ),
              // Trailing icon placeholders
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SkeletonBlock(width: 32.w, height: 32.h, borderRadius: 16),
                  SizedBox(width: 8.w),
                  SkeletonBlock(width: 32.w, height: 32.h, borderRadius: 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Skeleton loader for a dashboard stat card.
class SkeletonStatCard extends StatelessWidget {
  const SkeletonStatCard({super.key});

  @override
  Widget build(BuildContext context) {
    return ShimmerEffect(
      child: Container(
        padding: EdgeInsets.all(20.w),
        decoration: BoxDecoration(
          color: Colors.grey[200],
          borderRadius: BorderRadius.circular(16.r),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonBlock(width: 40.w, height: 40.h, borderRadius: 12),
            SizedBox(height: 16.h),
            SkeletonBlock(width: 80.w, height: 24.h),
            SizedBox(height: 8.h),
            SkeletonBlock(width: 100.w, height: 12.h),
          ],
        ),
      ),
    );
  }
}

/// Skeleton loader for a full list view (shows multiple list item skeletons).
class SkeletonListView extends StatelessWidget {
  final int itemCount;
  final double separatorHeight;

  const SkeletonListView({
    super.key,
    this.itemCount = 6,
    this.separatorHeight = 12,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16.w, 0, 16.w, 80.h),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: itemCount,
      separatorBuilder: (_, __) => SizedBox(height: separatorHeight.h),
      itemBuilder: (_, __) => const SkeletonListItem(),
    );
  }
}
