import 'package:flutter/material.dart';

/// Badge vendeur avec niveau de vérification (none, verified, gold, platinum).
class MarketplaceSellerBadge extends StatelessWidget {
  final String? name;
  final String? logoUrl;
  final bool isVerified;
  final String verificationLevel;
  final double? ratingAvg;
  final bool compact;
  final VoidCallback? onTap;

  const MarketplaceSellerBadge({
    super.key,
    this.name,
    this.logoUrl,
    this.isVerified = false,
    this.verificationLevel = 'none',
    this.ratingAvg,
    this.compact = true,
    this.onTap,
  });

  Color get _badgeColor {
    switch (verificationLevel) {
      case 'platinum':
        return const Color(0xFF6366F1);
      case 'gold':
        return const Color(0xFFF59E0B);
      case 'verified':
        return const Color(0xFF10B981);
      default:
        return const Color(0xFF9CA3AF);
    }
  }

  String get _badgeLabel {
    switch (verificationLevel) {
      case 'platinum':
        return 'Platinum';
      case 'gold':
        return 'Gold';
      case 'verified':
        return 'Vérifié';
      default:
        return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    if (compact) return _buildCompact();
    return _buildFull();
  }

  Widget _buildCompact() {
    if (!isVerified && verificationLevel == 'none') {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: _badgeColor.withOpacity(0.12),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified, size: 12, color: _badgeColor),
            const SizedBox(width: 3),
            Text(
              _badgeLabel,
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: _badgeColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFull() {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: const Color(0xFFE5E7EB)),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              clipBehavior: Clip.antiAlias,
              child: logoUrl != null && logoUrl!.isNotEmpty
                  ? Image.network(logoUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const Icon(
                          Icons.storefront, color: Color(0xFF9CA3AF)))
                  : const Icon(Icons.storefront, color: Color(0xFF9CA3AF)),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name ?? 'Vendeur',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF111827),
                          ),
                        ),
                      ),
                      if (isVerified) ...[
                        const SizedBox(width: 4),
                        Icon(Icons.verified, size: 16, color: _badgeColor),
                      ],
                    ],
                  ),
                  if (ratingAvg != null)
                    Row(
                      children: [
                        const Icon(Icons.star, size: 14,
                            color: Color(0xFFF59E0B)),
                        const SizedBox(width: 2),
                        Text(
                          ratingAvg!.toStringAsFixed(1),
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Color(0xFF9CA3AF)),
          ],
        ),
      ),
    );
  }
}
