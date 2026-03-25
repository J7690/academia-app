import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/sponsorship_service.dart';

/// Carte de sponsorship
class SponsorshipCard extends StatelessWidget {
  final Sponsorship sponsorship;
  
  const SponsorshipCard({
    Key? key,
    required this.sponsorship,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sponsorship.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _getTypeName(sponsorship.type),
                      style: const TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(sponsorship.status),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _getStatusText(sponsorship.status),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Description
          Text(
            sponsorship.description,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          
          const SizedBox(height: 12),
          
          // Compensation
          Row(
            children: [
              Icon(
                _getCompensationIcon(sponsorship.compensationType),
                color: const Color(0xFF00D4FF),
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${sponsorship.compensationAmount.toStringAsFixed(2)} ${sponsorship.compensationCurrency}',
                style: const TextStyle(
                  color: Color(0xFF00D4FF),
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Text(
                _getCompensationTypeName(sponsorship.compensationType),
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Dates
          Row(
            children: [
              Icon(
                Icons.date_range,
                color: Colors.white54,
                size: 16,
              ),
              const SizedBox(width: 8),
              Text(
                '${_formatDate(sponsorship.startDate)} - ${sponsorship.endDate != null ? _formatDate(sponsorship.endDate!) : 'Indéfini'}',
                style: const TextStyle(
                  color: Colors.white54,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Actions
          if (sponsorship.status == SponsorshipStatus.pending)
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _acceptSponsorship(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00D4FF),
                      foregroundColor: Colors.black,
                    ),
                    child: const Text('Accepter'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => _rejectSponsorship(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red.withOpacity(0.2),
                      foregroundColor: Colors.red,
                    ),
                    child: const Text('Refuser'),
                  ),
                ),
              ],
            )
          else if (sponsorship.status == SponsorshipStatus.active)
            ElevatedButton(
              onPressed: () => _viewDetails(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white.withOpacity(0.1),
                foregroundColor: Colors.white,
              ),
              child: const Text('Voir les détails'),
            ),
        ],
      ),
    );
  }
  
  String _getTypeName(SponsorshipType type) {
    switch (type) {
      case SponsorshipType.battle:
        return 'Battle';
      case SponsorshipType.postLive:
        return 'Post-Live';
      case SponsorshipType.clip:
        return 'Clip';
      case SponsorshipType.general:
        return 'Général';
    }
  }
  
  Color _getStatusColor(SponsorshipStatus status) {
    switch (status) {
      case SponsorshipStatus.pending:
        return Colors.orange;
      case SponsorshipStatus.active:
        return Colors.green;
      case SponsorshipStatus.completed:
        return Colors.blue;
      case SponsorshipStatus.cancelled:
        return Colors.red;
    }
  }
  
  String _getStatusText(SponsorshipStatus status) {
    switch (status) {
      case SponsorshipStatus.pending:
        return 'En attente';
      case SponsorshipStatus.active:
        return 'Actif';
      case SponsorshipStatus.completed:
        return 'Terminé';
      case SponsorshipStatus.cancelled:
        return 'Annulé';
    }
  }
  
  IconData _getCompensationIcon(CompensationType type) {
    switch (type) {
      case CompensationType.fixed:
        return Icons.attach_money;
      case CompensationType.cpm:
        return Icons.visibility;
      case CompensationType.cpc:
        return Icons.touch_app;
      case CompensationType.revenueShare:
        return Icons.pie_chart;
    }
  }
  
  String _getCompensationTypeName(CompensationType type) {
    switch (type) {
      case CompensationType.fixed:
        return 'Fixe';
      case CompensationType.cpm:
        return 'CPM';
      case CompensationType.cpc:
        return 'CPC';
      case CompensationType.revenueShare:
        return 'Revenue Share';
    }
  }
  
  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
  
  void _acceptSponsorship(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'Accepter le sponsorship',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir accepter ce sponsorship ?',
          style: TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Color(0xFF00D4FF)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implémenter l'acceptation
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sponsorship accepté !'),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.black,
            ),
            child: const Text('Accepter'),
          ),
        ],
      ),
    );
  }
  
  void _rejectSponsorship(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: const Text(
          'Refuser le sponsorship',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Êtes-vous sûr de vouloir refuser ce sponsorship ?',
          style: TextStyle(color: Colors.white54),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Annuler',
              style: TextStyle(color: Color(0xFF00D4FF)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              // Implémenter le refus
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Sponsorship refusé'),
                  backgroundColor: Colors.orange,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }
  
  void _viewDetails(BuildContext context) {
    // Implémenter la vue des détails
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Détails du sponsorship bientôt disponibles !'),
        backgroundColor: Color(0xFF00D4FF),
      ),
    );
  }
}
