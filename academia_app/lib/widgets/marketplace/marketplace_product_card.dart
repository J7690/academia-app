import 'package:flutter/material.dart';

import 'alibaba_marketplace_tokens.dart';
import 'alibaba_press_scale.dart';
import 'marketplace_media_carousel.dart';
import 'marketplace_motion.dart';
import 'marketplace_seller_badge.dart';
import '../report_content_sheet.dart';

/// Carte produit Academia Market : image immersive, actions en verre dépoli,
/// prix mis en avant et ajout au panier animé.
class MarketplaceProductCard extends StatelessWidget {
  final Map<String, dynamic> listing;
  final VoidCallback? onTap;
  final VoidCallback? onAddToCart;
  final Future<bool> Function()? onAddToCartAsync;
  final VoidCallback? onBookmark;
  final bool compact;
  final String? heroTag;

  const MarketplaceProductCard({
    super.key,
    required this.listing,
    this.onTap,
    this.onAddToCart,
    this.onAddToCartAsync,
    this.onBookmark,
    this.compact = false,
    this.heroTag,
  });

  static List<String> mediaUrlsOf(Map<String, dynamic> listing) {
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
    return mediaUrls;
  }

  void _report(BuildContext context) {
    final listingId = listing['id']?.toString();
    if (listingId == null) return;
    ReportContentSheet.show(
      context,
      contentType: 'listing',
      contentId: listingId,
      targetUserId: listing['merchant_id']?.toString(),
      contentPreview: listing['title']?.toString(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title = listing['title']?.toString() ?? '';
    final coverUrl = listing['cover_url']?.toString();
    final currency = AlibabaMarketplaceTokens.currencyLabel(listing['currency']?.toString());
    final isReadyToShip = listing['is_ready_to_ship'] == true;
    final ratingAvg = (listing['rating_avg'] is num)
        ? (listing['rating_avg'] as num).toDouble()
        : 0.0;
    final ratingCount = (listing['rating_count'] as num?)?.toInt() ?? 0;
    final salesCount = (listing['sales_count'] as num?)?.toInt() ?? 0;
    final isBookmarked = listing['is_bookmarked'] == true;
    final merchantName = listing['merchant_name']?.toString() ??
        listing['organization_name']?.toString();
    final merchantVerified = listing['merchant_is_verified'] == true;
    final verificationLevel =
        listing['merchant_verification_level']?.toString() ?? 'none';

    final radius = AlibabaMarketplaceTokens.radiusCard;
    final cardRadius = BorderRadius.circular(radius);
    final imageH = compact ? 150.0 : 200.0;
    final canAdd = onAddToCartAsync != null || onAddToCart != null;

    Future<bool> add() async {
      if (onAddToCartAsync != null) return onAddToCartAsync!();
      onAddToCart?.call();
      return true;
    }

    Widget image = MarketplaceMediaCarousel(
      coverUrl: coverUrl,
      imageUrls: mediaUrlsOf(listing),
      height: imageH,
      borderRadius: BorderRadius.vertical(top: Radius.circular(radius)),
    );
    if (heroTag != null) {
      image = Hero(tag: heroTag!, child: image);
    }

    return AlibabaPressScale(
      onTap: onTap,
      pressedScale: 0.975,
      borderRadius: cardRadius,
      child: GestureDetector(
        onLongPress: () => _report(context),
        child: Container(
          decoration: BoxDecoration(
            color: AlibabaMarketplaceTokens.surface,
            borderRadius: cardRadius,
            boxShadow: AlibabaMarketplaceTokens.shadowSoft,
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: imageH,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    image,
                    const IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(gradient: AlibabaMarketplaceTokens.imageScrim),
                      ),
                    ),
                    if (isReadyToShip)
                      const Positioned(
                        top: 10,
                        left: 10,
                        child: _Pill(
                          icon: Icons.bolt_rounded,
                          label: 'Prêt',
                          color: AlibabaMarketplaceTokens.success,
                        ),
                      ),
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Column(
                        children: [
                          if (onBookmark != null)
                            MarketplaceFavoriteButton(
                              isFavorite: isBookmarked,
                              onTap: onBookmark,
                              size: compact ? 32 : 36,
                            ),
                          const SizedBox(height: 6),
                          MarketplaceGlassButton(
                            size: compact ? 28 : 32,
                            tooltip: 'Signaler',
                            onTap: () => _report(context),
                            child: const Icon(Icons.outlined_flag_rounded,
                                size: 15, color: AlibabaMarketplaceTokens.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (ratingCount > 0)
                      Positioned(
                        left: 10,
                        bottom: 10,
                        child: IgnorePointer(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.star_rounded, size: 14, color: AlibabaMarketplaceTokens.star),
                                const SizedBox(width: 3),
                                Text(
                                  '${ratingAvg.toStringAsFixed(1)} ($ratingCount)',
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: EdgeInsets.fromLTRB(12, 10, 12, compact ? 12 : 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AlibabaMarketplaceTokens.productTitle.copyWith(
                        fontSize: compact ? 13 : 14.5,
                      ),
                    ),
                    if (merchantName != null && merchantName.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.storefront_rounded, size: 13, color: AlibabaMarketplaceTokens.textMeta),
                          const SizedBox(width: 4),
                          Flexible(
                            child: Text(
                              merchantName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AlibabaMarketplaceTokens.productMeta.copyWith(
                                color: AlibabaMarketplaceTokens.textSecondary,
                              ),
                            ),
                          ),
                          if (merchantVerified || verificationLevel != 'none') ...[
                            const SizedBox(width: 4),
                            MarketplaceSellerBadge(
                              name: merchantName,
                              isVerified: merchantVerified,
                              verificationLevel: verificationLevel,
                              compact: true,
                            ),
                          ],
                        ],
                      ),
                    ],
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _Price(
                                from: listing['price_from'],
                                to: listing['price_to'],
                                currency: currency,
                                compact: compact,
                              ),
                              _Meta(
                                moq: listing['min_order_qty'],
                                leadDays: listing['lead_time_days'],
                                sales: salesCount,
                              ),
                            ],
                          ),
                        ),
                        if (canAdd && compact) ...[
                          const SizedBox(width: 8),
                          MarketplaceAddToCartButton(onAdd: add, compact: true),
                        ],
                      ],
                    ),
                    if (canAdd && !compact) ...[
                      const SizedBox(height: 12),
                      MarketplaceAddToCartButton(onAdd: add, label: 'Ajouter au panier'),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Pill({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        boxShadow: AlibabaMarketplaceTokens.shadowColored(color),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: Colors.white),
          ),
        ],
      ),
    );
  }
}

class _Price extends StatelessWidget {
  final dynamic from;
  final dynamic to;
  final String currency;
  final bool compact;

  const _Price({required this.from, required this.to, required this.currency, required this.compact});

  @override
  Widget build(BuildContext context) {
    final f = from is num ? from as num : null;
    final t = to is num ? to as num : null;
    if (f == null && t == null) {
      return const Text(
        'Prix sur demande',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: AlibabaMarketplaceTokens.brand,
        ),
      );
    }

    final String main;
    if (f != null && t != null && f != t) {
      main = '${AlibabaMarketplaceTokens.formatPrice(f)} – ${AlibabaMarketplaceTokens.formatPrice(t)}';
    } else {
      main = AlibabaMarketplaceTokens.formatPrice((f ?? t)!);
    }

    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: main,
            style: AlibabaMarketplaceTokens.priceStyle.copyWith(fontSize: compact ? 16 : 19),
          ),
          TextSpan(
            text: ' $currency',
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: AlibabaMarketplaceTokens.textSecondary,
            ),
          ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _Meta extends StatelessWidget {
  final dynamic moq;
  final dynamic leadDays;
  final int sales;

  const _Meta({required this.moq, required this.leadDays, required this.sales});

  @override
  Widget build(BuildContext context) {
    final parts = <String>[];
    if (sales > 0) parts.add('$sales vendu${sales > 1 ? 's' : ''}');
    if (moq is num && moq > 1) parts.add('Min. $moq');
    if (leadDays is num && leadDays > 0) parts.add('$leadDays j');
    if (parts.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 3),
      child: Text(
        parts.join(' · '),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: AlibabaMarketplaceTokens.productMeta,
      ),
    );
  }
}
