import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/tiktok_creator_fund_service.dart';
import '../services/sponsorship_service.dart';
import '../widgets/revenue_chart.dart';
import '../widgets/sponsorship_card.dart';
import '../widgets/creator_stats_card.dart';

/// Écran de monétisation pour les créateurs
class MonetizationScreen extends StatefulWidget {
  const MonetizationScreen({Key? key}) : super(key: key);
  
  @override
  _MonetizationScreenState createState() => _MonetizationScreenState();
}

class _MonetizationScreenState extends State<MonetizationScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  CreatorFundProfile? _creatorProfile;
  CreatorStats? _creatorStats;
  List<Sponsorship> _sponsorships = [];
  List<BrandPartnership> _availableBrands = [];
  List<RevenueRecord> _revenueHistory = [];
  SponsorshipStats? _sponsorshipStats;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initializeData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      // Charger les données en parallèle
      final results = await Future.wait([
        TikTokCreatorFundService.getCreatorFundProfile(userId),
        TikTokCreatorFundService.getDetailedStats(userId),
        SponsorshipService.getUserSponsorships(),
        SponsorshipService.getAvailableBrands(),
        TikTokCreatorFundService.getPayoutHistory(userId),
        SponsorshipService.getSponsorshipStats(userId),
      ]);
      
      setState(() {
        _creatorProfile = results[0] as CreatorFundProfile?;
        _creatorStats = results[1] as CreatorStats?;
        _sponsorships = results[2] as List<Sponsorship>;
        _availableBrands = results[3] as List<BrandPartnership>;
        _revenueHistory = results[4] as List<RevenueRecord>;
        _sponsorshipStats = results[5] as SponsorshipStats?;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur initialisation: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text(
          'Monétisation',
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00D4FF),
          labelColor: const Color(0xFF00D4FF),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Creator Fund'),
            Tab(text: 'Sponsorships'),
            Tab(text: 'Revenus'),
            Tab(text: 'Analytics'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildCreatorFundTab(),
                _buildSponsorshipsTab(),
                _buildRevenueTab(),
                _buildAnalyticsTab(),
              ],
            ),
    );
  }
  
  Widget _buildCreatorFundTab() {
    if (_creatorProfile == null) {
      return _buildCreatorFundSetup();
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statut du profil
          _buildCreatorFundStatus(),
          const SizedBox(height: 20),
          
          // Métriques principales
          _buildCreatorMetrics(),
          const SizedBox(height: 20),
          
          // Niveau de fund
          _buildFundLevel(),
          const SizedBox(height: 20),
          
          // Actions
          _buildCreatorActions(),
          const SizedBox(height: 20),
          
          // Historique des paiements
          _buildPayoutHistory(),
        ],
      ),
    );
  }
  
  Widget _buildCreatorFundSetup() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.monetization_on,
              color: Color(0xFF00D4FF),
              size: 64,
            ),
            const SizedBox(height: 16),
            const Text(
              'TikTok Creator Fund',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rejoignez le Creator Fund pour monétiser vos contenus',
              style: TextStyle(
                color: Colors.white54,
                fontSize: 16,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _setupCreatorFund,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF00D4FF),
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              ),
              child: const Text(
                'Commencer',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildCreatorFundStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Icon(
            _creatorProfile!.isEligible ? Icons.check_circle : Icons.warning,
            color: _creatorProfile!.isEligible ? Colors.green : Colors.orange,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _creatorProfile!.isEligible ? 'Éligible au Creator Fund' : 'Non éligible',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Niveau: ${_creatorProfile!.fundLevel.toString().split('.').last.toUpperCase()}',
                  style: const TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildCreatorMetrics() {
    if (_creatorStats == null) return const SizedBox();
    
    return Column(
      children: [
        CreatorStatsCard(stats: _creatorStats!),
        const SizedBox(height: 16),
        RevenueChart(revenueHistory: _revenueHistory),
      ],
    );
  }
  
  Widget _buildFundLevel() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Niveau de Fund',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildFundLevelProgress(),
        ],
      ),
    );
  }
  
  Widget _buildFundLevelProgress() {
    final levels = ['Bronze', 'Silver', 'Gold', 'Platinum'];
    final currentLevelIndex = levels.indexOf(_creatorProfile!.fundLevel.toString().split('.').last);
    
    return Column(
      children: [
        Row(
          children: levels.asMap().entries.map((entry) {
            final index = entry.key;
            final level = entry.value;
            final isActive = index <= currentLevelIndex;
            final isCurrent = index == currentLevelIndex;
            
            return Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 2),
                height: 8,
                decoration: BoxDecoration(
                  color: isActive ? const Color(0xFF00D4FF) : Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: isCurrent
                    ? Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      )
                    : null,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: levels.map((level) => Text(
            level,
            style: TextStyle(
              color: Colors.white54,
              fontSize: 10,
            ),
          )).toList(),
        ),
      ],
    );
  }
  
  Widget _buildCreatorActions() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _requestPayout,
                icon: const Icon(Icons.payment, color: Colors.black),
                label: const Text('Demander paiement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF00D4FF),
                  foregroundColor: Colors.black,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ElevatedButton.icon(
                onPressed: _updatePayoutInfo,
                icon: const Icon(Icons.settings, color: Colors.white),
                label: const Text('Infos paiement'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.1),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
  
  Widget _buildPayoutHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Historique des paiements',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_revenueHistory.isEmpty)
          const Center(
            child: Text(
              'Aucun paiement historique',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._revenueHistory.take(5).map((record) => _buildPayoutItem(record)),
      ],
    );
  }
  
  Widget _buildPayoutItem(RevenueRecord record) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: const Color(0xFF00D4FF).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.monetization_on,
              color: Color(0xFF00D4FF),
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${record.amount.toStringAsFixed(2)} ${record.currency}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(record.periodEnd),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _getPayoutStatusColor(record.status),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              _getPayoutStatusText(record.status),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSponsorshipsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques sponsorships
          if (_sponsorshipStats != null) _buildSponsorshipStats(),
          const SizedBox(height: 20),
          
          // Sponsorships actifs
          _buildActiveSponsorships(),
          const SizedBox(height: 20),
          
          // Marques disponibles
          _buildAvailableBrands(),
        ],
      ),
    );
  }
  
  Widget _buildSponsorshipStats() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Statistiques Sponsorships',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Total', '${_sponsorshipStats!.totalSponsorships}'),
              const SizedBox(width: 16),
              _buildStatItem('Actifs', '${_sponsorshipStats!.activeSponsorships}'),
              const SizedBox(width: 16),
              _buildStatItem('Complétés', '${_sponsorshipStats!.completedSponsorships}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Revenus', '${_sponsorshipStats!.totalRevenue.toStringAsFixed(2)}$'),
              const SizedBox(width: 16),
              _buildStatItem('En attente', '${_sponsorshipStats!.pendingRevenue.toStringAsFixed(2)}$'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildStatItem(String label, String value) {
    return Expanded(
      child: Column(
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
  
  Widget _buildActiveSponsorships() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Sponsorships Actifs',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_sponsorships.isEmpty)
          const Center(
            child: Text(
              'Aucun sponsorship actif',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._sponsorships.map((sponsorship) => SponsorshipCard(sponsorship: sponsorship)),
      ],
    );
  }
  
  Widget _buildAvailableBrands() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Marques Partenaires',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_availableBrands.isEmpty)
          const Center(
            child: Text(
              'Aucune marque disponible',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._availableBrands.map((brand) => _buildBrandCard(brand)),
      ],
    );
  }
  
  Widget _buildBrandCard(BrandPartnership brand) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          // Logo
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              color: Colors.black,
            ),
            child: brand.brandLogoUrl.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: brand.brandLogoUrl,
                    fit: BoxFit.cover,
                  )
                : const Icon(Icons.business, color: Colors.white54),
          ),
          const SizedBox(width: 12),
          
          // Informations
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      brand.brandName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    if (brand.isVerified)
                      const SizedBox(width: 4),
                    if (brand.isVerified)
                      const Icon(
                        Icons.verified,
                        color: Color(0xFF00D4FF),
                        size: 16,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  brand.industry,
                  style: const TextStyle(
                    color: Color(0xFF00D4FF),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Budget: ${brand.budgetRangeMin.toStringAsFixed(0)}$ - ${brand.budgetRangeMax.toStringAsFixed(0)}$',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          
          // Action
          IconButton(
            icon: const Icon(Icons.arrow_forward, color: Color(0xFF00D4FF)),
            onPressed: () => _showBrandDetails(brand),
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Revenus totaux
          _buildTotalRevenue(),
          const SizedBox(height: 20),
          
          // Graphique des revenus
          RevenueChart(revenueHistory: _revenueHistory),
          const SizedBox(height: 20),
          
          // Détail par source
          _buildRevenueBySource(),
        ],
      ),
    );
  }
  
  Widget _buildTotalRevenue() {
    final totalRevenue = _revenueHistory.fold(0.0, (sum, record) => sum + record.amount);
    final pendingRevenue = _revenueHistory
        .where((record) => record.status == 'pending')
        .fold(0.0, (sum, record) => sum + record.amount);
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Revenus Totaux',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${totalRevenue.toStringAsFixed(2)}$',
                      style: const TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Total',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      '${pendingRevenue.toStringAsFixed(2)}$',
                      style: const TextStyle(
                        color: Colors.orange,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'En attente',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRevenueBySource() {
    final revenueBySource = <String, double>{};
    for (final record in _revenueHistory) {
      revenueBySource[record.revenueSource] = (revenueBySource[record.revenueSource] ?? 0) + record.amount;
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Revenus par Source',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...revenueBySource.entries.map((entry) => _buildRevenueSourceItem(entry.key, entry.value)),
      ],
    );
  }
  
  Widget _buildRevenueSourceItem(String source, double amount) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            _getSourceIcon(source),
            color: const Color(0xFF00D4FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _getSourceName(source),
              style: const TextStyle(color: Colors.white),
            ),
          ),
          Text(
            '${amount.toStringAsFixed(2)}$',
            style: const TextStyle(
              color: Color(0xFF00D4FF),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnalyticsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Performance globale
          _buildGlobalPerformance(),
          const SizedBox(height: 20),
          
          // Taux d'engagement
          _buildEngagementRate(),
          const SizedBox(height: 20),
          
          // Croissance mensuelle
          _buildMonthlyGrowth(),
        ],
      ),
    );
  }
  
  Widget _buildGlobalPerformance() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Globale',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_creatorStats != null) ...[
            _buildPerformanceRow('Vues totales', '${_creatorStats!.totalViews}'),
            _buildPerformanceRow('Likes totaux', '${_creatorStats!.totalLikes}'),
            _buildPerformanceRow('Shares totaux', '${_creatorStats!.totalShares}'),
            _buildPerformanceRow('Vidéos', '${_creatorStats!.totalVideos}'),
            _buildPerformanceRow('Feeds', '${_creatorStats!.totalFeeds}'),
          ],
        ],
      ),
    );
  }
  
  Widget _buildPerformanceRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildEngagementRate() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Taux d\'Engagement',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          if (_creatorStats != null)
            Column(
              children: [
                LinearProgressIndicator(
                  value: (_creatorStats!.engagementRate / 10).clamp(0.0, 1.0),
                  backgroundColor: Colors.white.withOpacity(0.2),
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF00D4FF)),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      '${_creatorStats!.engagementRate.toStringAsFixed(2)}%',
                      style: const TextStyle(
                        color: Color(0xFF00D4FF),
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Spacer(),
                    const Text(
                      'Objectif: 10%',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
        ],
      ),
    );
  }
  
  Widget _buildMonthlyGrowth() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Croissance Mensuelle',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Graphique de croissance à implémenter',
            style: TextStyle(color: Colors.white54),
          ),
        ],
      ),
    );
  }
  
  // Méthodes utilitaires
  
  Future<void> _setupCreatorFund() async {
    // Implémenter la configuration du Creator Fund
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Configuration Creator Fund bientôt disponible !'),
        backgroundColor: Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _requestPayout() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      final payoutId = await TikTokCreatorFundService.requestPayout(userId);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Demande de paiement créée: $payoutId'),
          backgroundColor: Colors.green,
        ),
      );
      
      // Recharger les données
      await _initializeData();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur demande paiement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _updatePayoutInfo() async {
    // Implémenter la mise à jour des infos de paiement
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Mise à jour infos paiement bientôt disponible !'),
        backgroundColor: Color(0xFF00D4FF),
      ),
    );
  }
  
  void _showBrandDetails(BrandPartnership brand) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.black,
        title: Text(
          brand.brandName,
          style: const TextStyle(color: Colors.white),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              brand.brandDescription,
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 12),
            Text(
              'Industrie: ${brand.industry}',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Budget: ${brand.budgetRangeMin.toStringAsFixed(0)}$ - ${brand.budgetRangeMax.toStringAsFixed(0)}$',
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 8),
            Text(
              'Contact: ${brand.contactEmail}',
              style: const TextStyle(color: Colors.white),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              'Fermer',
              style: TextStyle(color: Color(0xFF00D4FF)),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _createSponsorshipRequest(brand);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00D4FF),
              foregroundColor: Colors.black,
            ),
            child: const Text('Proposer'),
          ),
        ],
      ),
    );
  }
  
  Future<void> _createSponsorshipRequest(BrandPartnership brand) async {
    // Implémenter la création de demande de sponsorship
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Création demande sponsorship bientôt disponible !'),
        backgroundColor: Color(0xFF00D4FF),
      ),
    );
  }
  
  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);
    
    if (difference.inDays > 0) {
      return '${difference.inDays}j';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}min';
    } else {
      return 'maintenant';
    }
  }
  
  Color _getPayoutStatusColor(String status) {
    switch (status) {
      case 'paid':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'failed':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }
  
  String _getPayoutStatusText(String status) {
    switch (status) {
      case 'paid':
        return 'Payé';
      case 'pending':
        return 'En attente';
      case 'failed':
        return 'Échec';
      default:
        return status;
    }
  }
  
  IconData _getSourceIcon(String source) {
    switch (source) {
      case 'tiktok_fund':
        return Icons.music_video;
      case 'sponsorship':
        return Icons.handshake;
      case 'premium':
        return Icons.star;
      case 'ads':
        return Icons.ads_click;
      default:
        return Icons.monetization_on;
    }
  }
  
  String _getSourceName(String source) {
    switch (source) {
      case 'tiktok_fund':
        return 'TikTok Creator Fund';
      case 'sponsorship':
        return 'Sponsorships';
      case 'premium':
        return 'Abonnements Premium';
      case 'ads':
        return 'Publicité';
      default:
        return source;
    }
  }
}
