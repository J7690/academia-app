import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'alibaba_marketplace_tokens.dart';
import 'alibaba_press_scale.dart';

class AlibabaProductTile extends StatelessWidget {
  final String title;
  final String? imageUrl;
  final String? priceText;
  final String? metaLeft;
  final String? metaRight;
  final Widget? topRight;
  final VoidCallback? onTap;
  final bool compact;
  final double imageAspectRatio;

  const AlibabaProductTile({
    super.key,
    required this.title,
    this.imageUrl,
    this.priceText,
    this.metaLeft,
    this.metaRight,
    this.topRight,
    this.onTap,
    this.compact = false,
    this.imageAspectRatio = 1,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(AlibabaMarketplaceTokens.radiusCard);
    final pad = compact ? 8.0 : 10.0;

    return AlibabaPressScale(
      onTap: onTap,
      borderRadius: borderRadius,
      child: Container(
        decoration: BoxDecoration(
          color: AlibabaMarketplaceTokens.surface,
          borderRadius: borderRadius,
          border: Border.all(color: AlibabaMarketplaceTokens.divider),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                AspectRatio(
                  aspectRatio: imageAspectRatio,
                  child: _TileImage(url: imageUrl),
                ),
                if (topRight != null)
                  Positioned(
                    right: 8,
                    top: 8,
                    child: topRight!,
                  ),
              ],
            ),
            Padding(
              padding: EdgeInsets.all(pad),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: compact ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: compact
                        ? AlibabaMarketplaceTokens.productTitle.copyWith(
                            fontSize: 12,
                          )
                        : AlibabaMarketplaceTokens.productTitle,
                  ),
                  if ((priceText ?? '').trim().isNotEmpty) ...[
                    SizedBox(height: compact ? 4 : 6),
                    Text(
                      priceText!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: compact
                          ? AlibabaMarketplaceTokens.priceStyle.copyWith(
                              fontSize: 15,
                            )
                          : AlibabaMarketplaceTokens.priceStyle,
                    ),
                  ],
                  if ((metaLeft ?? '').trim().isNotEmpty ||
                      (metaRight ?? '').trim().isNotEmpty) ...[
                    SizedBox(height: compact ? 4 : 6),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            (metaLeft ?? '').trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AlibabaMarketplaceTokens.productMeta,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if ((metaRight ?? '').trim().isNotEmpty)
                          Text(
                            (metaRight ?? '').trim(),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AlibabaMarketplaceTokens.productMeta,
                          ),
                      ],
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
}

class _TileImage extends StatelessWidget {
  final String? url;

  const _TileImage({required this.url});

  @override
  Widget build(BuildContext context) {
    final u = (url ?? '').trim();
    if (u.isEmpty) {
      return Container(
        color: const Color(0xFFF3F4F6),
        child: const Center(
          child: Icon(
            Icons.image_outlined,
            color: Color(0xFF9CA3AF),
            size: 40,
          ),
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: u,
      fit: BoxFit.cover,
      placeholder: (context, _) {
        return Container(
          color: const Color(0xFFF3F4F6),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        );
      },
      errorWidget: (context, _, __) {
        return Container(
          color: const Color(0xFFF3F4F6),
          child: const Center(
            child: Icon(
              Icons.broken_image_outlined,
              color: Color(0xFF9CA3AF),
              size: 40,
            ),
          ),
        );
      },
    );
  }
}
