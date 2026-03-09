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
        color: config.color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
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
            config.label.toUpperCase(),
            style: TextStyle(
              fontSize: compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: config.color,
              letterSpacing: 0.5,
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
          color: const Color(0xFF2196F3),
          icon: Icons.work_outline,
        );
      case 'service':
        return _TypeConfig(
          label: 'Service',
          color: const Color(0xFF66BB6A),
          icon: Icons.handshake_outlined,
        );
      case 'product':
        return _TypeConfig(
          label: 'Bien',
          color: const Color(0xFFFFB74D),
          icon: Icons.shopping_bag_outlined,
        );
      default:
        return _TypeConfig(
          label: type,
          color: const Color(0xFF9E9E9E),
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
