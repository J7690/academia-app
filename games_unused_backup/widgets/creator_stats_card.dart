import 'package:flutter/material.dart';
import '../services/tiktok_creator_fund_service.dart';

/// Carte des statistiques créateur
class CreatorStatsCard extends StatelessWidget {
  final CreatorStats stats;
  
  const CreatorStatsCard({
    Key? key,
    required this.stats,
  }) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.trending_up,
                color: stats.isEligible ? Colors.green : Colors.orange,
              ),
              const SizedBox(width: 8),
              Text(
                stats.isEligible ? 'Éligible' : 'Non éligible',
                style: TextStyle(
                  color: stats.isEligible ? Colors.green : Colors.orange,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _getFundLevelColor(stats.fundLevel),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  stats.fundLevel.toString().split('.').last.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Métriques principales
          Row(
            children: [
              _buildMetricItem('Vues', '${_formatNumber(stats.totalViews)}'),
              const SizedBox(width: 16),
              _buildMetricItem('Likes', '${_formatNumber(stats.totalLikes)}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricItem('Shares', '${_formatNumber(stats.totalShares)}'),
              const SizedBox(width: 16),
              _buildMetricItem('Vidéos', '${stats.totalVideos}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildMetricItem('Feeds', '${stats.totalFeeds}'),
              const SizedBox(width: 16),
              _buildMetricItem('Engagement', '${stats.engagementRate.toStringAsFixed(1)}%'),
            ],
          ),
          
          const SizedBox(height: 16),
          const Divider(color: Colors.white24),
          const SizedBox(height: 16),
          
          // Revenus
          Row(
            children: [
              _buildRevenueItem('Mensuel', '${stats.monthlyRevenue.toStringAsFixed(2)}$'),
              const SizedBox(width: 16),
              _buildRevenueItem('Total', '${stats.totalRevenue.toStringAsFixed(2)}$'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: const TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
  
  Color _getFundLevelColor(CreatorFundLevel level) {
    switch (level) {
      case CreatorFundLevel.bronze:
        return Colors.brown;
      case CreatorFundLevel.silver:
        return Colors.grey;
      case CreatorFundLevel.gold:
        return Colors.amber;
      case CreatorFundLevel.platinum:
        return const Color(0xFFE5E4E2);
    }
  }
  
  String _formatNumber(int number) {
    if (number >= 1000000) {
      return '${(number / 1000000).toStringAsFixed(1)}M';
    } else if (number >= 1000) {
      return '${(number / 1000).toStringAsFixed(1)}K';
    } else {
      return number.toString();
    }
  }
}
