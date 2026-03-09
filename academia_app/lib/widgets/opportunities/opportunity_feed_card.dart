import 'package:flutter/material.dart';
import 'opportunity_type_badge.dart';
import 'opportunity_reactions_bar.dart';

/// Card d'opportunité — style Warm Professional 2025
class OpportunityFeedCard extends StatelessWidget {
  final Map<String, dynamic> opportunity;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onLove;
  final VoidCallback? onComment;
  final VoidCallback? onAction;
  final Future<bool> Function()? onActionAsync;
  final GlobalKey? cartIconKey;
  final VoidCallback? onBookmark;
  final EdgeInsetsGeometry margin;
  final bool compact;

  const OpportunityFeedCard({
    super.key,
    required this.opportunity,
    this.onTap,
    this.onLike,
    this.onLove,
    this.onComment,
    this.onAction,
    this.onActionAsync,
    this.cartIconKey,
    this.onBookmark,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final title = opportunity['title']?.toString() ?? '';
    final shortDescription = opportunity['short_description']?.toString() ?? '';
    final type = opportunity['type']?.toString() ?? 'job';
    final organizationName = opportunity['organization_name']?.toString() ?? '';
    final organizationLogoUrl = opportunity['organization_logo_url']?.toString();
    final city = opportunity['city']?.toString() ?? '';
    final country = opportunity['country']?.toString() ?? '';
    final isRemotePossible = opportunity['is_remote_possible'] == true;
    final isFeatured = opportunity['is_featured'] == true;
    final price = opportunity['price'];
    final merchantId = opportunity['merchant_id']?.toString();
    final merchantIsVerified = opportunity['merchant_is_verified'] == true;
    final priceFrom = opportunity['price_from'];
    final priceTo = opportunity['price_to'];
    final currency = opportunity['currency']?.toString();
    final minOrderQty = opportunity['min_order_qty'];
    final leadTimeDays = opportunity['lead_time_days'];
    final isReadyToShip = opportunity['is_ready_to_ship'] == true;
    final reactionsCount = opportunity['reactions_count'] as int? ?? 0;
    final commentsCount = opportunity['comments_count'] as int? ?? 0;
    final myReaction = opportunity['my_reaction']?.toString();
    final createdAt = opportunity['created_at']?.toString();
    final isNew = _isNew(createdAt);
    final isBookmarked = opportunity['is_bookmarked'] == true;
    final coverUrl = opportunity['cover_url']?.toString();
    final listingId = opportunity['id']?.toString();

    final isMarketplaceListing = merchantId != null && merchantId.isNotEmpty;
    final actionType = isMarketplaceListing ? 'product' : type;

    final location = [city, country].where((s) => s.isNotEmpty).join(', ');
    final timeAgo = _formatTimeAgo(createdAt);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFAFAFA), Color(0xFFF5F5F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isFeatured
              ? const Color(0xFF7E57C2).withOpacity(0.3)
              : const Color(0xFFE0E0E0),
          width: isFeatured ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2196F3).withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (coverUrl != null && coverUrl.trim().isNotEmpty)
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(20),
                    topRight: Radius.circular(20),
                  ),
                  child: AspectRatio(
                    aspectRatio: 16 / 9,
                    child: (listingId != null && listingId.trim().isNotEmpty)
                        ? Hero(
                            tag: 'marketplace_listing_cover_${listingId.trim()}',
                            child: Image.network(
                              coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Container(
                                  color: const Color(0xFFF5F5F5),
                                  child: const Center(
                                    child:
                                        Icon(Icons.image_not_supported_outlined),
                                  ),
                                );
                              },
                              loadingBuilder: (context, child, progress) {
                                if (progress == null) return child;
                                return Container(
                                  color: const Color(0xFFF5F5F5),
                                  child: const Center(
                                    child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          )
                        : Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                color: const Color(0xFFF5F5F5),
                                child: const Center(
                                  child:
                                      Icon(Icons.image_not_supported_outlined),
                                ),
                              );
                            },
                            loadingBuilder: (context, child, progress) {
                              if (progress == null) return child;
                              return Container(
                                color: const Color(0xFFF5F5F5),
                                child: const Center(
                                  child: SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ),
              // Featured accent bar
              if (isFeatured)
                Container(
                  height: 4,
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF4338CA), Color(0xFFF97316)],
                    ),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                ),
              Padding(
                padding: compact
                    ? const EdgeInsets.all(14)
                    : const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header: Logo + Org + Time
                    _buildHeader(
                      organizationName: organizationName,
                      organizationLogoUrl: organizationLogoUrl,
                      timeAgo: timeAgo,
                      isFeatured: isFeatured,
                      isNew: isNew,
                      isBookmarked: isBookmarked,
                    ),
                    const SizedBox(height: 14),

                    // Titre
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1E1B4B),
                        height: 1.3,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),

                    // Description courte
                    if (shortDescription.isNotEmpty)
                      Text(
                        shortDescription,
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF64748B),
                          height: 1.5,
                        ),
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (shortDescription.isNotEmpty)
                      const SizedBox(height: 12),

                    // Badges: Type + Location + Remote + Price
                    _buildBadges(
                      type: type,
                      location: location,
                      isRemotePossible: isRemotePossible,
                      price: price,
                      merchantIsVerified: merchantIsVerified,
                      priceFrom: priceFrom,
                      priceTo: priceTo,
                      currency: currency,
                      minOrderQty: minOrderQty,
                      leadTimeDays: leadTimeDays,
                      isReadyToShip: isReadyToShip,
                    ),
                    const SizedBox(height: 16),

                    // Divider
                    const Divider(height: 1, color: Color(0xFFF1F0EB)),
                    const SizedBox(height: 12),

                    // Reactions bar
                    OpportunityReactionsBar(
                      reactionsCount: reactionsCount,
                      commentsCount: commentsCount,
                      myReaction: myReaction,
                      opportunityType: actionType,
                      onLike: onLike,
                      onLove: onLove,
                      onComment: onComment,
                      onAction: onAction,
                      onActionAsync: onActionAsync,
                      cartIconKey: cartIconKey,
                      compact: compact,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader({
    required String organizationName,
    String? organizationLogoUrl,
    required String timeAgo,
    required bool isFeatured,
    required bool isNew,
    required bool isBookmarked,
  }) {
    final hasLogo = organizationLogoUrl != null && organizationLogoUrl.isNotEmpty;
    return Row(
      children: [
        // Logo circulaire avec bordure gradient
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [Color(0xFF4338CA), Color(0xFF6366F1)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4338CA).withOpacity(0.2),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(2),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFF8F7FF),
              image: hasLogo
                  ? DecorationImage(
                      image: NetworkImage(organizationLogoUrl),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: !hasLogo
                ? Center(
                    child: Text(
                      organizationName.isNotEmpty
                          ? organizationName[0].toUpperCase()
                          : '?',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF4338CA),
                      ),
                    ),
                  )
                : null,
          ),
        ),
        const SizedBox(width: 12),

        // Nom + Time sur une ligne
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                organizationName,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF64748B),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                timeAgo,
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ),
        ),

        Flexible(
          child: Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                // Bouton favoris
                _AnimatedBookmarkButton(
                  isBookmarked: isBookmarked,
                  onTap: onBookmark,
                ),
                if (isNew)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFF059669).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Text(
                      'NOUVEAU',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF059669),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                if (isFeatured)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Color.fromRGBO(249, 115, 22, 0.15),
                          Color.fromRGBO(249, 115, 22, 0.05),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome,
                          size: 12,
                          color: Color(0xFFF97316),
                        ),
                        SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'À LA UNE',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFFF97316),
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBadges({
    required String type,
    required String location,
    required bool isRemotePossible,
    dynamic price,
    required bool merchantIsVerified,
    dynamic priceFrom,
    dynamic priceTo,
    String? currency,
    dynamic minOrderQty,
    dynamic leadTimeDays,
    required bool isReadyToShip,
  }) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        // Type badge
        OpportunityTypeBadge(type: type, compact: true),

        // Location
        if (location.isNotEmpty)
          _InfoBadge(
            icon: Icons.location_on_outlined,
            text: location,
          ),

        // Remote
        if (isRemotePossible)
          const _InfoBadge(
            icon: Icons.wifi,
            text: 'Télétravail',
            color: Color(0xFF059669),
          ),

        if (merchantIsVerified)
          const _InfoBadge(
            icon: Icons.verified,
            text: 'Vendeur vérifié',
            color: Color(0xFF1EA75C),
          ),

        if (isReadyToShip)
          const _InfoBadge(
            icon: Icons.local_shipping_outlined,
            text: 'Prêt à expédier',
            color: Color(0xFF059669),
          ),

        if (minOrderQty != null)
          _InfoBadge(
            icon: Icons.inventory_2_outlined,
            text: 'MOQ ${minOrderQty.toString()}',
          ),

        if (leadTimeDays != null)
          _InfoBadge(
            icon: Icons.timelapse,
            text: 'Délai ${leadTimeDays.toString()}j',
          ),

        // Price
        if (price != null && price != 0)
          _InfoBadge(
            icon: Icons.attach_money,
            text: _formatPrice(price),
            color: const Color(0xFFF97316),
          ),

        if ((priceFrom != null && priceFrom != 0) ||
            (priceTo != null && priceTo != 0))
          _InfoBadge(
            icon: Icons.payments_outlined,
            text: _formatPriceRange(
              priceFrom: priceFrom,
              priceTo: priceTo,
              currency: currency,
            ),
            color: const Color(0xFFF97316),
          ),
      ],
    );
  }

  bool _isNew(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return false;

    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      return diff.inDays < 7;
    } catch (_) {
      return false;
    }
  }

  String _formatTimeAgo(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return '';

    try {
      final date = DateTime.parse(dateStr);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'À l\'instant';
      if (diff.inMinutes < 60) return 'Il y a ${diff.inMinutes} min';
      if (diff.inHours < 24) return 'Il y a ${diff.inHours}h';
      if (diff.inDays < 7) return 'Il y a ${diff.inDays}j';
      if (diff.inDays < 30) return 'Il y a ${(diff.inDays / 7).floor()} sem';
      if (diff.inDays < 365) return 'Il y a ${(diff.inDays / 30).floor()} mois';
      return 'Il y a ${(diff.inDays / 365).floor()} an(s)';
    } catch (_) {
      return '';
    }
  }

  String _formatPrice(dynamic price) {
    if (price == null) return '';
    if (price is num) {
      if (price >= 1000000) {
        return '${(price / 1000000).toStringAsFixed(1)}M FCFA';
      }
      if (price >= 1000) {
        return '${(price / 1000).toStringAsFixed(0)}K FCFA';
      }
      return '${price.toStringAsFixed(0)} FCFA';
    }
    return price.toString();
  }

  String _formatPriceRange({
    required dynamic priceFrom,
    required dynamic priceTo,
    String? currency,
  }) {
    String suffix = '';
    final cur = (currency ?? '').trim();
    if (cur.isNotEmpty) {
      suffix = ' $cur';
    } else {
      suffix = ' FCFA';
    }

    String fmt(dynamic v) {
      if (v is num) {
        return v.toStringAsFixed(0);
      }
      return v?.toString() ?? '';
    }

    final a = fmt(priceFrom);
    final b = fmt(priceTo);

    if (a.isNotEmpty && b.isNotEmpty) {
      return '$a - $b$suffix';
    }
    if (a.isNotEmpty) {
      return 'À partir de $a$suffix';
    }
    if (b.isNotEmpty) {
      return 'Jusqu\'à $b$suffix';
    }
    return '';
  }
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.text,
    this.color = const Color(0xFF64748B),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }
}

/// Animated bookmark button with rotation + crossfade
class _AnimatedBookmarkButton extends StatefulWidget {
  final bool isBookmarked;
  final VoidCallback? onTap;

  const _AnimatedBookmarkButton({
    required this.isBookmarked,
    this.onTap,
  });

  @override
  State<_AnimatedBookmarkButton> createState() => _AnimatedBookmarkButtonState();
}

class _AnimatedBookmarkButtonState extends State<_AnimatedBookmarkButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _rotation;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _rotation = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 0.0, end: -0.08), weight: 40),
      TweenSequenceItem(tween: Tween(begin: -0.08, end: 0.0), weight: 60),
    ]).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void didUpdateWidget(covariant _AnimatedBookmarkButton old) {
    super.didUpdateWidget(old);
    if (old.isBookmarked != widget.isBookmarked) {
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: widget.onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: RotationTransition(
          turns: _rotation,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            transitionBuilder: (child, anim) =>
                FadeTransition(opacity: anim, child: child),
            child: Icon(
              widget.isBookmarked ? Icons.bookmark : Icons.bookmark_border,
              key: ValueKey(widget.isBookmarked),
              size: 22,
              color: widget.isBookmarked
                  ? const Color(0xFF4338CA)
                  : const Color(0xFF94A3B8),
            ),
          ),
        ),
      ),
    );
  }
}
