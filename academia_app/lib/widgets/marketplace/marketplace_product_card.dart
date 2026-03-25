import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';

import 'alibaba_marketplace_tokens.dart';
import 'marketplace_media_carousel.dart';
import 'marketplace_seller_badge.dart';

/// Card produit style Amazon — carousel photos, rating, prix, MOQ, badge vendeur.
class MarketplaceProductCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final VoidCallback? onBookmark;
  final bool compact;

  const MarketplaceProductCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onAddToCart,
    this.onBookmark,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = listing['title']?.toString() ?? '';
    final coverUrl = listing['cover_url']?.toString();
    final priceFrom = listing['price_from'];
    final priceTo = listing['price_to'];
    final currency = listing['currency']?.toString() ?? 'XOF';
    final minOrderQty = listing['min_order_qty'];
    final leadTimeDays = listing['lead_time_days'];
    final isReadyToShip = listing['is_ready_to_ship'] == true;
    final ratingAvg = (listing['rating_avg'] is num)
        ? (listing['rating_avg'] as num).toDouble()
        : 0.0;
    final ratingCount = listing['rating_count'] as int? ?? 0;
    final salesCount = listing['sales_count'] as int? ?? 0;
    final isBookmarked = listing['is_bookmarked'] == true;
    final merchantName = listing['merchant_name']?.toString() ??
        listing['organization_name']?.toString();
    final merchantVerified = listing['merchant_is_verified'] == true;
    final verificationLevel =
        listing['merchant_verification_level']?.toString() ?? 'none';

    // Collect media URLs for carousel
    final mediaUrls = <String>[];
    final mediaList = listing['media'];
    if (mediaList is List) {
      for (final m in mediaList) {
        if (m is Map) {
          final ext = m['external_url']?.toString();
          final path = m['storage_path']?.toString();
          final bucket = m['storage_bucket']?.toString();
          if (ext != null && ext.isNotEmpty) {
            mediaUrls.add(ext);
          } else if (path != null && bucket != null) {
            mediaUrls.add(
                'https://thevdfcwlcqzdoybfvgs.supabase.co/storage/v1/object/public/$bucket/$path');
          }
        }
      }
    }

    final cardRadius = BorderRadius.circular(AlibabaMarketplaceTokens.radiusCard);
    final imageH = compact ? 140.0 : 180.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: cardRadius,
          border: Border.all(color: AlibabaMarketplaceTokens.divider),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image carousel
            Stack(
              children: [
                MarketplaceMediaCarousel(
                  coverUrl: coverUrl,
                  imageUrls: mediaUrls,
                  height: imageH,
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(AlibabaMarketplaceTokens.radiusCard),
                    topRight: Radius.circular(AlibabaMarketplaceTokens.radiusCard),
                  ),
                ),
                // Bookmark button
                if (onBookmark != null)
                  Positioned(
                    top: 6,
                    right: 6,
                    child: GestureDetector(
                      onTap: onBookmark,
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.9),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          isBookmarked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          size: 16,
                          color: isBookmarked
                              ? const Color(0xFFEF4444)
                              : const Color(0xFF9CA3AF),
                        ),
                      ),
                    ),
                  ),
                // Ready to ship badge
                if (isReadyToShip)
                  Positioned(
                    top: 6,
                    left: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF10B981),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: const Text(
                        'Prêt',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            // Content
            Padding(
              padding: EdgeInsets.all(compact ? 8 : 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: compact ? 12 : 13,
                      fontWeight: FontWeight.w600,
                      color: AlibabaMarketplaceTokens.textPrimary,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  // Rating
                  if (ratingCount > 0)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          RatingBarIndicator(
                            rating: ratingAvg,
                            itemBuilder: (_, __) => const Icon(
                                Icons.star, color: Color(0xFFF59E0B)),
                            itemCount: 5,
                            itemSize: compact ? 12 : 14,
                            unratedColor: const Color(0xFFE5E7EB),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            '($ratingCount)',
                            style: TextStyle(
                              fontSize: compact ? 10 : 11,
                              color: AlibabaMarketplaceTokens.textMeta,
                            ),
                          ),
                          if (salesCount > 0) ...[
                            const SizedBox(width: 6),
                            Text(
                              '$salesCount vendus',
                              style: TextStyle(
                                fontSize: compact ? 10 : 11,
                                color: AlibabaMarketplaceTokens.textMeta,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  // Price
                  _buildPrice(priceFrom, priceTo, currency, compact),
                  const SizedBox(height: 4),
                  // Meta row: MOQ + lead time
                  _buildMeta(minOrderQty, leadTimeDays, compact),
                  // Seller badge
                  if (merchantName != null && merchantName.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    MarketplaceSellerBadge(
                      name: merchantName,
                      isVerified: merchantVerified,
                      verificationLevel: verificationLevel,
                      compact: true,
                    ),
                  ],
                  // Add to cart button
                  if (onAddToCart != null && !compact) ...[
                    const SizedBox(height: 8),
                    SizedBox(
                      width: double.infinity,
                      height: 32,
                      child: ElevatedButton.icon(
                        onPressed: onAddToCart,
                        icon: const Icon(Icons.shopping_cart_outlined, size: 14),
                        label: const Text('Ajouter',
                            style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              AlibabaMarketplaceTokens.primaryOrange,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static Widget _buildPrice(
      dynamic priceFrom, dynamic priceTo, String currency, bool compact) {
    if (priceFrom == null && priceTo == null) {
      return Text(
        'Prix sur demande',
        style: TextStyle(
          fontSize: compact ? 11 : 12,
          fontWeight: FontWeight.w500,
          color: AlibabaMarketplaceTokens.textMeta,
          fontStyle: FontStyle.italic,
        ),
      );
    }

    final from = priceFrom is num ? priceFrom : null;
    final to = priceTo is num ? priceTo : null;

    String text;
    if (from != null && to != null && from != to) {
      text = '${_formatNum(from)} - ${_formatNum(to)} $currency';
    } else if (from != null) {
      text = '${_formatNum(from)} $currency';
    } else {
      text = '${_formatNum(to!)} $currency';
    }

    return Text(
      text,
      style: TextStyle(
        fontSize: compact ? 14 : 16,
        fontWeight: FontWeight.w900,
        color: AlibabaMarketplaceTokens.price,
        height: 1.1,
      ),
    );
  }

  static String _formatNum(num n) {
    if (n is int || n == n.roundToDouble()) {
      return n.toInt().toString().replaceAllMapped(
          RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
    }
    return n.toStringAsFixed(0).replaceAllMapped(
        RegExp(r'(\d)(?=(\d{3})+(?!\d))'), (m) => '${m[1]} ');
  }

  static Widget _buildMeta(dynamic moq, dynamic leadDays, bool compact) {
    final parts = <String>[];
    if (moq != null && moq is int && moq > 0) {
      parts.add('MOQ: $moq');
    }
    if (leadDays != null && leadDays is int && leadDays > 0) {
      parts.add('$leadDays j.');
    }

    if (parts.isEmpty) return const SizedBox.shrink();

    return Text(
      parts.join(' · '),
      style: TextStyle(
        fontSize: compact ? 10 : 11,
        color: AlibabaMarketplaceTokens.textMeta,
        fontWeight: FontWeight.w500,
      ),
    );
  }
}
