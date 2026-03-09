import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

class MarketplaceShimmerBox extends StatelessWidget {
  final double width;
  final double height;
  final double radius;

  const MarketplaceShimmerBox({
    super.key,
    required this.width,
    required this.height,
    this.radius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: const Color(0xFFE5E7EB),
      highlightColor: const Color(0xFFF3F4F6),
      child: Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      ),
    );
  }
}

class MarketplaceShimmerListItem extends StatelessWidget {
  const MarketplaceShimmerListItem({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      padding: const EdgeInsets.all(12),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MarketplaceShimmerBox(width: double.infinity, height: 14, radius: 8),
          SizedBox(height: 10),
          MarketplaceShimmerBox(width: 180, height: 12, radius: 8),
          SizedBox(height: 14),
          Row(
            children: [
              MarketplaceShimmerBox(width: 90, height: 12, radius: 8),
              Spacer(),
              MarketplaceShimmerBox(width: 90, height: 12, radius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class MarketplaceShimmerList extends StatelessWidget {
  final int itemCount;

  const MarketplaceShimmerList({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(12),
      itemCount: itemCount,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (_, __) => const MarketplaceShimmerListItem(),
    );
  }
}
