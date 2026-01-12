import 'package:flutter/material.dart';
import 'opportunity_type_badge.dart';
import 'opportunity_reactions_bar.dart';

/// Card d'opportunité pour le feed social (style Facebook/LinkedIn)
class OpportunityFeedCard extends StatelessWidget {
  final Map<String, dynamic> opportunity;
  final VoidCallback? onTap;
  final VoidCallback? onLike;
  final VoidCallback? onLove;
  final VoidCallback? onComment;
  final VoidCallback? onAction;
  final VoidCallback? onBookmark;

  const OpportunityFeedCard({
    super.key,
    required this.opportunity,
    this.onTap,
    this.onLike,
    this.onLove,
    this.onComment,
    this.onAction,
    this.onBookmark,
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
    final reactionsCount = opportunity['reactions_count'] as int? ?? 0;
    final commentsCount = opportunity['comments_count'] as int? ?? 0;
    final myReaction = opportunity['my_reaction']?.toString();
    final createdAt = opportunity['created_at']?.toString();
    final isNew = _isNew(createdAt);
    final isBookmarked = opportunity['is_bookmarked'] == true;

    final location = [city, country].where((s) => s.isNotEmpty).join(', ');
    final timeAgo = _formatTimeAgo(createdAt);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
        border: isFeatured
            ? Border.all(color: const Color(0x80F6A623), width: 2)
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
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
                const SizedBox(height: 12),

                // Titre
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF0A2540),
                    height: 1.3,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Description courte
                Text(
                  shortDescription,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    height: 1.4,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 12),

                // Badges: Type + Location + Remote + Price
                _buildBadges(
                  type: type,
                  location: location,
                  isRemotePossible: isRemotePossible,
                  price: price,
                ),
                const SizedBox(height: 16),

                // Divider
                const Divider(height: 1, color: Color(0xFFE5E7EB)),
                const SizedBox(height: 12),

                // Reactions bar
                OpportunityReactionsBar(
                  reactionsCount: reactionsCount,
                  commentsCount: commentsCount,
                  myReaction: myReaction,
                  opportunityType: type,
                  onLike: onLike,
                  onLove: onLove,
                  onComment: onComment,
                  onAction: onAction,
                ),
              ],
            ),
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
    return Row(
      children: [
        // Logo ou avatar
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFF3F4F6),
            borderRadius: BorderRadius.circular(12),
            image: organizationLogoUrl != null && organizationLogoUrl.isNotEmpty
                ? DecorationImage(
                    image: NetworkImage(organizationLogoUrl),
                    fit: BoxFit.cover,
                  )
                : null,
          ),
          child: organizationLogoUrl == null || organizationLogoUrl.isEmpty
              ? Center(
                  child: Text(
                    organizationName.isNotEmpty
                        ? organizationName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                )
              : null,
        ),
        const SizedBox(width: 12),

        // Nom + Time
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                organizationName,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF0A2540),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 2),
              Text(
                timeAgo,
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFF9CA3AF),
                ),
              ),
            ],
          ),
        ),

        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Bouton favoris
            InkWell(
              onTap: onBookmark,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Icon(
                  isBookmarked ? Icons.bookmark : Icons.bookmark_border,
                  size: 20,
                  color: isBookmarked
                      ? const Color(0xFF3275D0)
                      : const Color(0xFF9CA3AF),
                ),
              ),
            ),
            if (isNew || isFeatured) const SizedBox(width: 6),
            if (isNew)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x1A10B981),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text(
                  'Nouveau',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF10B981),
                  ),
                ),
              ),
            if (isNew && isFeatured) const SizedBox(width: 6),
            if (isFeatured)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0x1AF6A623),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star,
                      size: 12,
                      color: Color(0xFFF6A623),
                    ),
                    SizedBox(width: 4),
                    Text(
                      'À la une',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFF6A623),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildBadges({
    required String type,
    required String location,
    required bool isRemotePossible,
    dynamic price,
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
            color: Color(0xFF1B8F5A),
          ),

        // Price
        if (price != null && price != 0)
          _InfoBadge(
            icon: Icons.attach_money,
            text: _formatPrice(price),
            color: const Color(0xFFF6A623),
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
}

class _InfoBadge extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InfoBadge({
    required this.icon,
    required this.text,
    this.color = const Color(0xFF6B7280),
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
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
