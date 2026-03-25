import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart';

/// Carousel photo/vidéo pour une card ou un détail produit marketplace.
/// Affiche les médias en swipe horizontal avec un indicator dots.
class MarketplaceMediaCarousel extends StatefulWidget {
  final List<String> imageUrls;
  final String? coverUrl;
  final double height;
  final BorderRadius? borderRadius;
  final bool showIndicator;
  final VoidCallback? onTap;

  const MarketplaceMediaCarousel({
    super.key,
    this.imageUrls = const [],
    this.coverUrl,
    this.height = 180,
    this.borderRadius,
    this.showIndicator = true,
    this.onTap,
  });

  @override
  State<MarketplaceMediaCarousel> createState() =>
      _MarketplaceMediaCarouselState();
}

class _MarketplaceMediaCarouselState extends State<MarketplaceMediaCarousel> {
  final PageController _controller = PageController();

  List<String> get _allUrls {
    final urls = <String>[];
    if (widget.coverUrl != null && widget.coverUrl!.isNotEmpty) {
      urls.add(widget.coverUrl!);
    }
    for (final u in widget.imageUrls) {
      if (u.isNotEmpty && !urls.contains(u)) {
        urls.add(u);
      }
    }
    return urls;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final urls = _allUrls;

    if (urls.isEmpty) {
      return _buildPlaceholder();
    }

    if (urls.length == 1) {
      return GestureDetector(
        onTap: widget.onTap,
        child: _buildImage(urls.first),
      );
    }

    return GestureDetector(
      onTap: widget.onTap,
      child: SizedBox(
        height: widget.height,
        child: Stack(
          children: [
            PageView.builder(
              controller: _controller,
              itemCount: urls.length,
              itemBuilder: (context, index) => _buildImage(urls[index]),
            ),
            if (widget.showIndicator && urls.length > 1)
              Positioned(
                bottom: 8,
                left: 0,
                right: 0,
                child: Center(
                  child: SmoothPageIndicator(
                    controller: _controller,
                    count: urls.length,
                    effect: const ExpandingDotsEffect(
                      dotWidth: 6,
                      dotHeight: 6,
                      activeDotColor: Colors.white,
                      dotColor: Colors.white54,
                      expansionFactor: 2.5,
                      spacing: 4,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildImage(String url) {
    return ClipRRect(
      borderRadius: widget.borderRadius ?? BorderRadius.zero,
      child: CachedNetworkImage(
        imageUrl: url,
        height: widget.height,
        width: double.infinity,
        fit: BoxFit.cover,
        placeholder: (_, __) => Container(
          color: const Color(0xFFF5F5F5),
          child: const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ),
        ),
        errorWidget: (_, __, ___) => Container(
          color: const Color(0xFFF5F5F5),
          child: const Icon(Icons.image_not_supported_outlined,
              color: Color(0xFFBDBDBD), size: 32),
        ),
      ),
    );
  }

  Widget _buildPlaceholder() {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        height: widget.height,
        decoration: BoxDecoration(
          color: const Color(0xFFF5F5F5),
          borderRadius: widget.borderRadius,
        ),
        child: const Center(
          child: Icon(Icons.shopping_bag_outlined,
              color: Color(0xFFBDBDBD), size: 40),
        ),
      ),
    );
  }
}
