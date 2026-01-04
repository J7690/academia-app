import 'package:flutter/material.dart';

/// Skeleton loader pour les cards d'opportunités (effet shimmer)
class OpportunitySkeletonLoader extends StatefulWidget {
  final int count;

  const OpportunitySkeletonLoader({
    super.key,
    this.count = 3,
  });

  @override
  State<OpportunitySkeletonLoader> createState() => _OpportunitySkeletonLoaderState();
}

class _OpportunitySkeletonLoaderState extends State<OpportunitySkeletonLoader>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
        return Column(
          children: List.generate(
            widget.count,
            (index) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _SkeletonCard(shimmerValue: _animation.value),
            ),
          ),
        );
      },
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  final double shimmerValue;

  const _SkeletonCard({required this.shimmerValue});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: const Color(0x0D000000),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header: Avatar + Nom + Date
            Row(
              children: [
                _ShimmerBox(
                  width: 40,
                  height: 40,
                  borderRadius: 20,
                  shimmerValue: shimmerValue,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _ShimmerBox(
                        width: 120,
                        height: 14,
                        shimmerValue: shimmerValue,
                      ),
                      const SizedBox(height: 4),
                      _ShimmerBox(
                        width: 80,
                        height: 10,
                        shimmerValue: shimmerValue,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Titre
            _ShimmerBox(
              width: double.infinity,
              height: 18,
              shimmerValue: shimmerValue,
            ),
            const SizedBox(height: 8),

            // Description
            _ShimmerBox(
              width: double.infinity,
              height: 14,
              shimmerValue: shimmerValue,
            ),
            const SizedBox(height: 4),
            _ShimmerBox(
              width: 200,
              height: 14,
              shimmerValue: shimmerValue,
            ),
            const SizedBox(height: 12),

            // Badges
            Row(
              children: [
                _ShimmerBox(
                  width: 80,
                  height: 24,
                  borderRadius: 12,
                  shimmerValue: shimmerValue,
                ),
                const SizedBox(width: 8),
                _ShimmerBox(
                  width: 60,
                  height: 24,
                  borderRadius: 12,
                  shimmerValue: shimmerValue,
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Reactions bar
            Row(
              children: [
                _ShimmerBox(
                  width: 32,
                  height: 32,
                  borderRadius: 16,
                  shimmerValue: shimmerValue,
                ),
                const SizedBox(width: 8),
                _ShimmerBox(
                  width: 32,
                  height: 32,
                  borderRadius: 16,
                  shimmerValue: shimmerValue,
                ),
                const SizedBox(width: 16),
                _ShimmerBox(
                  width: 50,
                  height: 24,
                  borderRadius: 12,
                  shimmerValue: shimmerValue,
                ),
                const Spacer(),
                _ShimmerBox(
                  width: 90,
                  height: 36,
                  borderRadius: 12,
                  shimmerValue: shimmerValue,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double borderRadius;
  final double shimmerValue;

  const _ShimmerBox({
    required this.width,
    required this.height,
    this.borderRadius = 4,
    required this.shimmerValue,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        gradient: LinearGradient(
          begin: Alignment(shimmerValue - 1, 0),
          end: Alignment(shimmerValue + 1, 0),
          colors: const [
            Color(0xFFE5E7EB),
            Color(0xFFF3F4F6),
            Color(0xFFE5E7EB),
          ],
        ),
      ),
    );
  }
}

/// Single skeleton card pour utilisation individuelle
class OpportunitySingleSkeleton extends StatefulWidget {
  const OpportunitySingleSkeleton({super.key});

  @override
  State<OpportunitySingleSkeleton> createState() => _OpportunitySingleSkeletonState();
}

class _OpportunitySingleSkeletonState extends State<OpportunitySingleSkeleton>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
    _animation = Tween<double>(begin: -2, end: 2).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
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
        return _SkeletonCard(shimmerValue: _animation.value);
      },
    );
  }
}
