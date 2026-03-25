import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/wallet_service.dart';
import '../services/cache_service.dart';
import '../services/tiktok_creator_fund_service.dart';
import '../services/sponsorship_service.dart';
import '../widgets/wallet_card.dart';
import '../widgets/performance_metrics_card.dart';
import '../widgets/cache_stats_card.dart';
import '../widgets/mobile_analytics_card.dart';
import '../widgets/notifications_card.dart';

/// Écran principal Mobile First pour monétisation optimisée
class MobileFirstScreen extends StatefulWidget {
  const MobileFirstScreen({Key? key}) : super(key: key);
  
  @override
  _MobileFirstScreenState createState() => _MobileFirstScreenState();
}

class _MobileFirstScreenState extends State<MobileFirstScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  UserWallet? _wallet;
  WalletStats? _walletStats;
  CacheStats? _cacheStats;
  List<PaymentMethod> _paymentMethods = [];
  List<WalletTransaction> _transactions = [];
  CreatorStats? _creatorStats;
  SponsorshipStats? _sponsorshipStats;
  MobileAnalyticsStats? _analyticsStats;
  List<MobileNotification> _notifications = [];
  
  // Device info
  String _appVersion = '';
  String _deviceModel = '';
  String _osVersion = '';
  String _networkType = '';
  int _batteryLevel = 0;
  bool _isCharging = false;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
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
      
      // Obtenir les infos device
      await _getDeviceInfo();
      
      // Charger les données en parallèle
      final results = await Future.wait([
        WalletService.getUserWallet(userId),
        WalletService.getWalletStats(userId),
        CacheService.getStats(),
        WalletService.getPaymentMethods(userId),
        WalletService.getTransactions(userId),
        TikTokCreatorFundService.getDetailedStats(userId),
        SponsorshipService.getSponsorshipStats(userId),
        _getMobileAnalyticsStats(userId),
        _getNotifications(userId),
      ]);
      
      setState(() {
        _wallet = results[0] as UserWallet?;
        _walletStats = results[1] as WalletStats?;
        _cacheStats = results[2] as CacheStats?;
        _paymentMethods = results[3] as List<PaymentMethod>;
        _transactions = results[4] as List<WalletTransaction>;
        _creatorStats = results[5] as CreatorStats?;
        _sponsorshipStats = results[6] as SponsorshipStats?;
        _analyticsStats = results[7] as MobileAnalyticsStats?;
        _notifications = results[8] as List<MobileNotification>;
        _isLoading = false;
      });
      
      // Initialiser le cache avec les données fréquemment utilisées
      await _preloadCache();
    } catch (e) {
      print('Erreur initialisation Mobile First: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _getDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = await DeviceInfoPlugin.getInfo();
      final connectivity = await Connectivity().checkConnectivity();
      
      setState(() {
        _appVersion = packageInfo.version;
        _deviceModel = deviceInfo.model;
        _osVersion = deviceInfo.version;
        _networkType = connectivity.name;
        _batteryLevel = deviceInfo.batteryLevel ?? 0;
        _isCharging = deviceInfo.isCharging ?? false;
      });
    } catch (e) {
      print('Erreur infos device: $e');
    }
  }
  
  Future<MobileAnalyticsStats> _getMobileAnalyticsStats(String userId) async {
    // Simuler les stats analytics
    return MobileAnalyticsStats(
      totalSessions: 42,
      avgSessionDuration: 180, // 3 minutes
      totalScreenViews: 156,
      crashRate: 0.2,
      appLaunches: 28,
      retentionRate: 0.85,
      lastActive: DateTime.now(),
    );
  }
  
  Future<List<MobileNotification>> _getNotifications(String userId) async {
    // Simuler les notifications
    return [
      MobileNotification(
        id: '1',
        userId: userId,
        title: 'Nouveau revenu !',
        body: 'Vous avez gagné 50$ avec TikTok Creator Fund',
        type: NotificationType.revenue,
        priority: NotificationPriority.high,
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
      ),
      MobileNotification(
        id: '2',
        userId: userId,
        title: 'Sponsorship disponible',
        body: 'Nike vous propose un partenariat de 1000$',
        type: NotificationType.sponsorship,
        priority: NotificationPriority.normal,
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
    ];
  }
  
  Future<void> _preloadCache() async {
    try {
      // Précharger les données fréquemment utilisées
      await CacheService.preload([
        'user_wallet_${Supabase.instance.client.auth.currentUser?.id}',
        'payment_methods_${Supabase.instance.client.auth.currentUser?.id}',
        'creator_stats_${Supabase.instance.client.auth.currentUser?.id}',
        'sponsorship_stats_${Supabase.instance.client.auth.currentUser?.id}',
      ]);
    } catch (e) {
      print('Erreur préchargement cache: $e');
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Mobile First',
          style: const TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Color(0xFF00D4FF)),
            onPressed: _refreshData,
          ),
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white),
            onPressed: _showSettings,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00D4FF),
          labelColor: const Color(0xFF00D4FF),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Wallet'),
            Tab(text: 'Cache'),
            Tab(text: 'Analytics'),
            Tab(text: 'Notifications'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildWalletTab(),
                _buildCacheTab(),
                _buildAnalyticsTab(),
                _buildNotificationsTab(),
                _buildPerformanceTab(),
              ],
            ),
    );
  }
  
  Widget _buildWalletTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Carte wallet
          if (_wallet != null) WalletCard(wallet: _wallet!, stats: _walletStats!),
          const SizedBox(height: 16),
          
          // Actions rapides
          _buildQuickActions(),
          const SizedBox(height: 16),
          
          // Transactions récentes
          _buildRecentTransactions(),
          const SizedBox(height: 16),
          
          // Méthodes de paiement
          _buildPaymentMethods(),
        ],
      ),
    );
  }
  
  Widget _buildQuickActions() {
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
            'Actions Rapides',
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
                child: ElevatedButton.icon(
                  onPressed: _addFunds,
                  icon: const Icon(Icons.add_circle, color: Colors.black),
                  label: const Text('Ajouter fonds'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _withdrawFunds,
                  icon: const Icon(Icons.remove_circle, color: Colors.white),
                  label: const Text('Retirer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _viewTransactions,
                  icon: const Icon(Icons.history, color: Colors.white),
                  label: const Text('Historique'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _addPaymentMethod,
                  icon: const Icon(Icons.credit_card, color: Colors.white),
                  label: const Text('Carte'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecentTransactions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Transactions Récentes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_transactions.isEmpty)
          const Center(
            child: Text(
              'Aucune transaction récente',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._transactions.take(5).map((transaction) => _buildTransactionItem(transaction)),
      ],
    );
  }
  
  Widget _buildTransactionItem(WalletTransaction transaction) {
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
            _getTransactionIcon(transaction.type),
            color: _getTransactionColor(transaction.type),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  transaction.description,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.amount.toStringAsFixed(2)} ${transaction.currency}',
                  style: TextStyle(
                    color: _getTransactionColor(transaction.type),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(transaction.createdAt),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildPaymentMethods() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Méthodes de Paiement',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_paymentMethods.isEmpty)
          const Center(
            child: Text(
              'Aucune méthode de paiement',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._paymentMethods.map((method) => _buildPaymentMethodItem(method)),
      ],
    );
  }
  
  Widget _buildPaymentMethodItem(PaymentMethod method) {
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
            _getPaymentMethodIcon(method.type),
            color: const Color(0xFF00D4FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${method.brand ?? 'Carte'} ${method.lastFour ?? '****'}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _getPaymentMethodName(method.provider),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                if (method.expiryMonth != null && method.expiryYear != null)
                  Text(
                    'Expire: ${method.expiryMonth}/${method.expiryYear}',
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (method.isDefault)
            const Icon(
              Icons.star,
              color: Colors.amber,
            ),
        ],
      ),
    );
  }
  
  Widget _buildCacheTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques du cache
          if (_cacheStats != null) CacheStatsCard(stats: _cacheStats!),
          const SizedBox(height: 16),
          
          // Actions du cache
          _buildCacheActions(),
          const SizedBox(height: 16),
          
          // Items les plus utilisés
          _buildMostAccessedItems(),
        ],
      ),
    );
  }
  
  Widget _buildCacheActions() {
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
            'Actions Cache',
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
                child: ElevatedButton.icon(
                  onPressed: _clearCache,
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  label: const Text('Vider'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _preloadCache,
                  icon: const Icon(Icons.download, color: Colors.black),
                  label: const Text('Précharger'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _optimizeCache,
                  icon: const Icon(Icons.speed, color: Colors.white),
                  label: const Text('Optimiser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.2),
                    foregroundColor: Colors.green,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMostAccessedItems() {
    if (_cacheStats == null) return const SizedBox();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Items les Plus Accédés',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ..._cacheStats!.mostAccessed.map((item) => _buildCacheItem(item)),
      ],
    );
  }
  
  Widget _buildCacheItem(CacheItem item) {
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
            _getCacheTypeIcon(item.type),
            color: const Color(0xFF00D4FF),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.key,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  'Accès: ${item.accessCount}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Taille: ${_formatSize(item.sizeBytes)}',
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                ),
              ],
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
          // Device info
          _buildDeviceInfo(),
          const SizedBox(height: 16),
          
          // Stats analytics
          if (_analyticsStats != null) MobileAnalyticsCard(stats: _analyticsStats!),
          const SizedBox(height: 16),
          
          // Performance metrics
          _buildPerformanceMetrics(),
        ],
      ),
    );
  }
  
  Widget _buildDeviceInfo() {
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
            'Informations Device',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildInfoRow('App Version', _appVersion),
          _buildInfoRow('Device', _deviceModel),
          _buildInfoRow('OS Version', _osVersion),
          _buildInfoRow('Réseau', _networkType),
          _buildInfoRow('Batterie', '${_batteryLevel}%'),
          _buildInfoRow('Charge', _isCharging ? 'Oui' : 'Non'),
        ],
      ),
    );
  }
  
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
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
  
  Widget _buildPerformanceMetrics() {
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
            'Performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetricRow('Démarrage App', '2.3s', Colors.green),
          _buildMetricRow('Chargement Écran', '45fps', Colors.green),
          _buildMetricRow('Utilisation CPU', '45%', Colors.orange),
          _buildMetricRow('Utilisation Mémoire', '2.1GB', Colors.orange),
          _buildMetricRow('Réseau', 'WiFi 4G', Colors.green),
        ],
      ),
    );
  }
  
  Widget _buildMetricRow(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildNotificationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques notifications
          NotificationsCard(notifications: _notifications),
          const SizedBox(height: 16),
          
          // Notifications récentes
          _buildRecentNotifications(),
        ],
      ),
    );
  }
  
  Widget _buildRecentNotifications() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Notifications Récentes',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        const SizedBox(height: 12),
        if (_notifications.isEmpty)
          const Center(
            child: Text(
              'Aucune notification récente',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._notifications.map((notification) => _buildNotificationItem(notification)),
      ],
    );
  }
  
  Widget _buildNotificationItem(MobileNotification notification) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: _getNotificationPriorityColor(notification.priority),
          width: 2,
        ),
      ),
      child: Row(
        children: [
          Icon(
            _getNotificationIcon(notification.type),
            color: _getNotificationColor(notification.type),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  notification.title,
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  notification.body,
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 12,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(notification.createdAt),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          if (!notification.isRead)
            const Icon(
              Icons.circle,
              color: Color(0xFF00D4FF),
              size: 8,
            ),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Device performance
          _buildDevicePerformance(),
          const SizedBox(height: 16),
          
          // App performance
          _buildAppPerformance(),
          const SizedBox(height: 16),
          
          // Network performance
          _buildNetworkPerformance(),
        ],
      ),
    );
  }
  
  _buildDevicePerformance() {
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
            'Performance Device',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetricRow('CPU Usage', '25%', Colors.green),
          _buildMetricRow('Memory Usage', '1.2GB', Colors.green),
          _buildMetricRow('Storage Available', '45GB', Colors.orange),
          _buildMetricRow('Battery Health', '87%', Colors.green),
        ],
      ),
    );
  }
  
  _buildAppPerformance() {
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
            'Performance App',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetricRow('Temps de Démarrage', '2.3s', Colors.green),
          _buildMetricRow('Temps de Chargement', '1.8s', Colors.green),
          _buildMetricRow('FPS Moyen', '58fps', Colors.green),
          _buildMetricRow('Utilisation CPU', '32%', Colors.orange),
        ],
      ),
    );
  }
  
  _buildNetworkPerformance() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: (
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Performance Réseau',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetricRow('Latence Moyenne', '45ms', Colors.green),
          _buildMetricRow('Débit Moyen', '2.1Mbps', Colors.green),
          _buildMetricRow('Perte de Paquets', '0.1%', Colors.green),
          _buildMetricRow('Qualité Signal', 'Excellent', Colors.green),
        ],
      ),
    );
  }
  
  // Méthodes utilitaires
  
  Future<void> _refreshData() async {
    await _initializeData();
  }
  
  Future<void> _showSettings() async {
    // Ouvrir les paramètres
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paramètres bientôt disponibles !'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _addFunds() async {
    // Implémenter l'ajout de fonds
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ajout de fonds bientôt disponible !'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _withdrawFunds() async {
    // Implémenter le retrait de fonds
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Retrait de fonds bientôt disponible !'),
        backgroundColor: Colors.orange,
      ),
    );
  }
  
  Future<void> _viewTransactions() async {
    // Implémenter la vue des transactions
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Historique des transactions bientôt disponible !'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _addPaymentMethod() async {
    // Implémenter l'ajout de méthode de paiement
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Ajout méthode de paiement bientôt disponible !'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _clearCache() async {
    await CacheService.clear();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache vidé !'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _preloadCache() async {
    await _preloadCache();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Préchargement terminé !'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _optimizeCache() async {
    await CacheService.cleanupExpired();
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Cache optimisé !'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  // Méthodes utilitaires pour les icônes et couleurs
  
  IconData _getTransactionIcon(TransactionType type) {
    switch (type) {
      case TransactionType.credit:
        return Icons.add_circle;
      case TransactionType.debit:
        return Icons.remove_circle;
      case TransactionType.refund:
        return Icons.refresh;
      case TransactionType.withdrawal:
        return Icons.account_balance_wallet;
    }
  }
  
  Color _getTransactionColor(TransactionType type) {
    switch (type) {
      case TransactionType.credit:
        return Colors.green;
      case TransactionType.debit:
        return Colors.red;
      case TransactionType.refund:
        return Colors.blue;
      case TransactionType.withdrawal:
        return Colors.orange;
    }
  }
  
  IconData _getPaymentMethodIcon(PaymentMethodType type) {
    switch (type) {
      case PaymentMethodType.creditCard:
        return Icons.credit_card;
      case PaymentMethod.paypal:
        return Icons.payment;
      case PaymentMethod.applePay:
        return Icons.apple;
      case PaymentMethod.googlePay:
        return Icons.android;
      case PaymentMethod.crypto:
        return Icons.currency_bitcoin;
    }
  }
  
  String _getPaymentMethodName(String provider) {
    switch (provider) {
      case 'stripe':
        return 'Stripe';
      case 'paypal':
        return 'PayPal';
      case 'apple':
        return 'Apple Pay';
      case 'google':
        return 'Google Pay';
      default:
        return provider;
    }
  }
  
  IconData _getCacheTypeIcon(CacheType type) {
    switch (type) {
      case CacheType.userData:
        return Icons.person;
      case CacheType.apiResponse:
        return Icons.api;
      case CacheType.image:
        return Icons.image;
      case CacheType.video:
        return Icons.video_library;
      case CacheType.config:
        return Icons.settings;
      case CacheType.other:
        return Icons.storage;
    }
  }
  
  Color _getNotificationIcon(NotificationType type) {
    switch (type) {
      case NotificationType.revenue:
        return Icons.monetization_on;
      case NotificationType.sponsorship:
        return Icons.handshake;
      case NotificationType.system:
        return Icons.info;
      case NotificationType.social:
        return Icons.share;
      case NotificationType.reminder:
        return Icons.alarm;
    }
  }
  
  Color _getNotificationPriority(NotificationPriority priority) {
    switch (priority) {
      case NotificationPriority.low:
        return Colors.grey;
      case NotificationPriority.normal:
        return Colors.white;
      case NotificationPriority.high:
        return Colors.orange;
      case NotificationPriority.critical:
        return Colors.red;
    }
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
  
  String _formatSize(int bytes) {
    if (bytes < 1024) {
      return '${bytes}B';
    } else if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)}KB';
    } else {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
    }
  }
}
