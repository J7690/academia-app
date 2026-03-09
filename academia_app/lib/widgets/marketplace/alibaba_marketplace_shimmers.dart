import 'package:flutter/material.dart';

import 'marketplace_shimmer.dart';

class AlibabaRailShimmer extends StatelessWidget {
  final int itemCount;

  const AlibabaRailShimmer({
    super.key,
    this.itemCount = 6,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 240,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: itemCount,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          return const SizedBox(
            width: 170,
            child: Column(
              children: [
                MarketplaceShimmerBox(width: double.infinity, height: 170),
                SizedBox(height: 10),
                MarketplaceShimmerBox(width: double.infinity, height: 12, radius: 8),
                SizedBox(height: 8),
                MarketplaceShimmerBox(width: 120, height: 12, radius: 8),
              ],
            ),
          );
        },
      ),
    );
  }
}

class AlibabaGridShimmer extends StatelessWidget {
  final int itemCount;

  const AlibabaGridShimmer({
    super.key,
    this.itemCount = 8,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const gap = 12.0;
        final maxW = constraints.maxWidth;
        final columns = maxW < 360 ? 1 : 2;
        final cardW = columns == 1 ? maxW : (maxW - gap) / 2.0;

        return Wrap(
          spacing: gap,
          runSpacing: gap,
          children: [
            for (var i = 0; i < itemCount; i++)
              SizedBox(
                width: cardW,
                child: const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MarketplaceShimmerBox(width: double.infinity, height: 140),
                    SizedBox(height: 10),
                    MarketplaceShimmerBox(width: double.infinity, height: 12, radius: 8),
                    SizedBox(height: 8),
                    MarketplaceShimmerBox(width: 140, height: 12, radius: 8),
                    SizedBox(height: 8),
                    MarketplaceShimmerBox(width: 90, height: 12, radius: 8),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
