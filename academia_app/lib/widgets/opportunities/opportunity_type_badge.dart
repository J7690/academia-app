import 'package:flutter/material.dart';

/// Badge coloré pour afficher le type d'opportunité
/// Types supportés: job (Emploi/Stage), service (Service), product (Bien)
class OpportunityTypeBadge extends StatelessWidget {
  final String type;
  final bool compact;

  const OpportunityTypeBadge({
    super.key,
    required this.type,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getTypeConfig(type);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 8 : 12,
        vertical: compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: config.color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(compact ? 8 : 12),
        border: Border.all(
          color: config.color.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: compact ? 12 : 14,
            color: config.color,
          ),
          SizedBox(width: compact ? 4 : 6),
          Text(
            config.label,
            style: TextStyle(
              fontSize: compact ? 10 : 12,
              fontWeight: FontWeight.w600,
              color: config.color,
            ),
          ),
        ],
      ),
    );
  }

  _TypeConfig _getTypeConfig(String type) {
    switch (type.toLowerCase()) {
      case 'job':
        return _TypeConfig(
          label: 'Emploi / Stage',
          color: const Color(0xFF3275D0),
          icon: Icons.work_outline,
        );
      case 'service':
        return _TypeConfig(
          label: 'Service',
          color: const Color(0xFF1B8F5A),
          icon: Icons.handshake_outlined,
        );
      case 'product':
        return _TypeConfig(
          label: 'Bien',
          color: const Color(0xFFF6A623),
          icon: Icons.shopping_bag_outlined,
        );
      default:
        return _TypeConfig(
          label: type,
          color: const Color(0xFF6B7280),
          icon: Icons.category_outlined,
        );
    }
  }
}

class _TypeConfig {
  final String label;
  final Color color;
  final IconData icon;

  _TypeConfig({
    required this.label,
    required this.color,
    required this.icon,
  });
}

/// Retourne le label d'action principal selon le type
String getOpportunityActionLabel(String type) {
  switch (type.toLowerCase()) {
    case 'job':
      return 'Postuler';
    case 'service':
      return 'Contacter';
    case 'product':
      return 'Acheter';
    default:
      return 'Voir';
  }
}

/// Retourne l'icône d'action principale selon le type
IconData getOpportunityActionIcon(String type) {
  switch (type.toLowerCase()) {
    case 'job':
      return Icons.send_outlined;
    case 'service':
      return Icons.chat_outlined;
    case 'product':
      return Icons.shopping_cart_outlined;
    default:
      return Icons.arrow_forward;
  }
}
