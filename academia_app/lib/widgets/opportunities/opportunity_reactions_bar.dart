import 'package:flutter/material.dart';

/// Barre de réactions pour une opportunité (like, love, commentaires, action)
class OpportunityReactionsBar extends StatelessWidget {
  final int reactionsCount;
  final int commentsCount;
  final String? myReaction;
  final String opportunityType;
  final VoidCallback? onLike;
  final VoidCallback? onLove;
  final VoidCallback? onComment;
  final VoidCallback? onAction;
  final bool compact;

  const OpportunityReactionsBar({
    super.key,
    required this.reactionsCount,
    required this.commentsCount,
    this.myReaction,
    required this.opportunityType,
    this.onLike,
    this.onLove,
    this.onComment,
    this.onAction,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isLiked = myReaction == 'like';
    final isLoved = myReaction == 'love';

    return Row(
      children: [
        // Bouton Like
        _ReactionButton(
          icon: Icons.thumb_up,
          isActive: isLiked,
          activeColor: const Color(0xFF3275D0),
          onTap: onLike,
          compact: compact,
        ),
        SizedBox(width: compact ? 4 : 8),

        // Bouton Love
        _ReactionButton(
          icon: Icons.favorite,
          isActive: isLoved,
          activeColor: const Color(0xFFE53935),
          onTap: onLove,
          compact: compact,
        ),
        SizedBox(width: compact ? 8 : 12),

        // Compteur réactions
        if (reactionsCount > 0) ...[
          Text(
            '$reactionsCount',
            style: TextStyle(
              fontSize: compact ? 11 : 13,
              color: const Color(0xFF6B7280),
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(width: compact ? 12 : 16),
        ],

        // Bouton Commentaires
        _CommentButton(
          count: commentsCount,
          onTap: onComment,
          compact: compact,
        ),

        const Spacer(),

        // Bouton Action principal
        _ActionButton(
          type: opportunityType,
          onTap: onAction,
          compact: compact,
        ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  final IconData icon;
  final bool isActive;
  final Color activeColor;
  final VoidCallback? onTap;
  final bool compact;

  const _ReactionButton({
    required this.icon,
    required this.isActive,
    required this.activeColor,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.all(compact ? 6 : 8),
        child: Icon(
          isActive ? icon : _getOutlinedIcon(icon),
          size: compact ? 18 : 22,
          color: isActive ? activeColor : const Color(0xFF9CA3AF),
        ),
      ),
    );
  }

  IconData _getOutlinedIcon(IconData icon) {
    if (icon == Icons.thumb_up) return Icons.thumb_up_outlined;
    if (icon == Icons.favorite) return Icons.favorite_border;
    return icon;
  }
}

class _CommentButton extends StatelessWidget {
  final int count;
  final VoidCallback? onTap;
  final bool compact;

  const _CommentButton({
    required this.count,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 6 : 8,
          vertical: compact ? 6 : 8,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: compact ? 16 : 20,
              color: const Color(0xFF6B7280),
            ),
            if (count > 0) ...[
              const SizedBox(width: 4),
              Text(
                '$count',
                style: TextStyle(
                  fontSize: compact ? 11 : 13,
                  color: const Color(0xFF6B7280),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String type;
  final VoidCallback? onTap;
  final bool compact;

  const _ActionButton({
    required this.type,
    this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getActionConfig(type);

    return ElevatedButton.icon(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: config.color,
        foregroundColor: Colors.white,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 12 : 16,
          vertical: compact ? 8 : 10,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(compact ? 8 : 12),
        ),
        elevation: 0,
      ),
      icon: Icon(config.icon, size: compact ? 14 : 16),
      label: Text(
        config.label,
        style: TextStyle(
          fontSize: compact ? 11 : 13,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  _ActionConfig _getActionConfig(String type) {
    switch (type.toLowerCase()) {
      case 'job':
        return _ActionConfig(
          label: 'Postuler',
          color: const Color(0xFF3275D0),
          icon: Icons.send,
        );
      case 'service':
        return _ActionConfig(
          label: 'Contacter',
          color: const Color(0xFF1B8F5A),
          icon: Icons.chat,
        );
      case 'product':
        return _ActionConfig(
          label: 'Acheter',
          color: const Color(0xFFF6A623),
          icon: Icons.shopping_cart,
        );
      default:
        return _ActionConfig(
          label: 'Voir',
          color: const Color(0xFF6B7280),
          icon: Icons.arrow_forward,
        );
    }
  }
}

class _ActionConfig {
  final String label;
  final Color color;
  final IconData icon;

  _ActionConfig({
    required this.label,
    required this.color,
    required this.icon,
  });
}
