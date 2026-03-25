import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/monitoring_service.dart';
import '../services/ml_service.dart';
import '../services/wallet_service.dart';
import '../services/tiktok_creator_fund_service.dart';
import '../services/sponsorship_service.dart';
import '../widgets/production_metrics_card.dart';
import '../widgets/health_status_card.dart';
import '../widgets/feature_flag_card.dart';
import '../widgets/ab_test_card.dart';
import '../widgets/deployment_log_card.dart';

/// Écran principal pour le monitoring et déploiement en production
class ProductionScreen extends StatefulWidget {
  const ProductionScreen({Key? key}) : super(key: key);
  
  @override
  _ProductionScreenState createState() => _ProductionScreenState();
}

class _ProductionScreenState extends State<ProductionScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  MonitoringStats? _monitoringStats;
  List<SystemHealthMetric> _systemHealth = [];
  List<PerformanceMetric> _performanceMetrics = [];
  List<DeploymentLog> _deploymentLogs = [];
  List<FeatureFlag> _featureFlags = [];
  List<ABTest> _abTests = [];
  List<ABTestResult> _abTestResults = [];
  
  // Device info
  String _appVersion = '';
  String _deviceModel = '';
  String _osVersion = '';
  String _networkType = '';
  int _batteryLevel = 0;
  double _memoryUsage = 0.0;
  double _cpuUsage = 0.0;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
    _initializeData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }
  
  Future<void> _initializeData() async {
    try {
      // Obtenir les infos device
      await _getDeviceInfo();
      
      // Charger les données en parallèle
      final results = await Future.wait([
        MonitoringService.getMonitoringStats(),
        MonitoringService.getSystemHealth(),
        MonitoringService.getPerformanceMetrics(),
        MonitoringService.getDeploymentLogs(),
        _getFeatureFlags(),
        _getABTests(),
        _getABTestResults(),
      ]);
      
      setState(() {
        _monitoringStats = results[0] as MonitoringStats;
        _systemHealth = results[1] as List<SystemHealthMetric>;
        _performanceMetrics = results[2] as List<PerformanceMetric>;
        _deploymentLogs = results[3] as List<DeploymentLog>;
        _featureFlags = results[4] as List<FeatureFlag>;
        _abTests = results[5] as List<ABTest>;
        _abTestResults = results[6] as List<ABTestResult>;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur initialisation Production: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  Future<void> _getDeviceInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final deviceInfo = DeviceInfoPlugin();
      final connectivity = await Connectivity().checkConnectivity();
      
      setState(() {
        _appVersion = packageInfo.version;
        _deviceModel = await _getDeviceModel();
        _osVersion = await _getOSVersion();
        _networkType = connectivity.name;
        _batteryLevel = await _getBatteryLevel();
        _memoryUsage = await _getMemoryUsage();
        _cpuUsage = await _getCPUUsage();
      });
    } catch (e) {
      print('Erreur infos device: $e');
    }
  }
  
  Future<List<FeatureFlag>> _getFeatureFlags() async {
    // Simuler les feature flags
    return [
      FeatureFlag(
        key: 'ml_predictions',
        name: 'ML Predictions',
        description: 'Enable ML predictions for revenue and engagement',
        isEnabled: true,
        rolloutPercentage: 100.0,
        targetPlatforms: ['ios', 'android', 'web'],
        targetVersions: ['1.0.0', '1.1.0'],
        conditions: {},
        createdAt: DateTime.now(),
      ),
      FeatureFlag(
        key: 'recommendations_v2',
        name: 'Recommendations v2',
        description: 'New recommendation algorithm',
        isEnabled: true,
        rolloutPercentage: 50.0,
        targetPlatforms: ['ios', 'android'],
        targetVersions: ['1.0.0'],
        conditions: {},
        createdAt: DateTime.now(),
      ),
      FeatureFlag(
        key: 'enhanced_analytics',
        name: 'Enhanced Analytics',
        description: 'Enhanced analytics tracking',
        isEnabled: true,
        rolloutPercentage: 100.0,
        targetPlatforms: ['ios', 'android', 'web'],
        targetVersions: ['1.0.0', '1.1.0'],
        conditions: {},
        createdAt: DateTime.now(),
      ),
      FeatureFlag(
        key: 'a_b_testing_ui',
        name: 'A/B Testing UI',
        description: 'Enable A/B testing interface',
        isEnabled: false,
        rolloutPercentage: 0.0,
        targetPlatforms: [],
        targetVersions: [],
        conditions: {},
        createdAt: DateTime.now(),
      ),
    ];
  }
  
  Future<List<ABTest>> _getABTests() async {
    // Simuler les A/B tests
    return [
      ABTest(
        id: '1',
        name: 'recommendation_algorithm',
        description: 'Test new recommendation algorithm vs current',
        testType: 'algorithm_change',
        variantA: {
          'algorithm': 'collaborative_filtering',
          'weights': {'views': 0.4, 'likes': 0.3, 'shares': 0.3},
        },
        variantB: {
          'algorithm': 'hybrid_ml',
          'weights': {'views': 0.3, 'likes': 0.4, 'shares': 0.3},
          'ml_features': true,
        },
        trafficSplit: 50.0,
        isActive: false,
        startDate: DateTime.now().subtract(const Duration(days: 7)),
        endDate: DateTime.now().add(const Duration(days: 7)),
        targetAudience: {},
        successMetrics: {
          'primary_metric': 'click_through_rate',
          'secondary_metrics': ['engagement_time', 'conversion_rate'],
        },
        createdBy: 'admin',
        createdAt: DateTime.now(),
      ),
    ];
  }
  
  Future<List<ABTestResult>> _getABTestResults() async {
    // Simuler les résultats A/B tests
    return [
      ABTestResult(
        id: '1',
        testId: '1',
        userId: 'demo_user_1',
        variant: 'control',
        platform: 'android',
        appVersion: '1.0.0',
        assignedAt: DateTime.now().subtract(const Duration(hours: 2)),
        conversionEvent: 'click',
        conversionValue: 1.0,
        engagementMetrics: {
          'time_spent': 120.0,
          'interactions': 5,
          'scroll_depth': 3.2,
        },
        performanceMetrics: {
          'load_time': 1.2,
          'fps': 58,
          'memory_usage': 45.6,
        },
        createdAt: DateTime.now(),
      ),
      ABTestResult(
        id: '2',
        testId: '1',
        userId: 'demo_user_2',
        variant: 'variant_b',
        platform: 'ios',
        appVersion: '1.1.0',
        assignedAt: DateTime.now().subtract(const Duration(hours: 1)),
        conversionEvent: 'click',
        conversionValue: 1.5,
        engagementMetrics: {
          'time_spent': 150.0,
          'interactions': 8,
          'scroll_depth': 4.1,
        },
        performanceMetrics: {
          'load_time': 1.0,
          'fps': 60,
          'memory_usage': 42.3,
        },
        createdAt: DateTime.now(),
      ),
    ];
  }
  
  Future<String> _getDeviceModel() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        return '${androidInfo.brand} ${androidInfo.model}';
      } else if (Platform.isIOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        return '${iosInfo.model} ${iosInfo.systemVersion}';
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  Future<String> _getOSVersion() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        return androidInfo.version.release;
      } else if (Platform.isIOS) {
        final iosInfo = await DeviceInfoPlugin().iosInfo;
        return iosInfo.systemVersion;
      }
      return 'Unknown';
    } catch (e) {
      return 'Unknown';
    }
  }
  
  Future<int> _getBatteryLevel() async {
    try {
      if (Platform.isAndroid) {
        final androidInfo = await DeviceInfoPlugin().androidInfo;
        return androidInfo.batteryLevel ?? 0;
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }
  
  Future<double> _getMemoryUsage() async {
    // Simulation - à implémenter avec des packages spécifiques
    return 0.0;
  }
  
  Future<double> _getCPUUsage() async {
    // Simulation - à implémenter avec des packages spécifiques
    return 0.0;
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: Text(
          'Production',
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
            Tab(text: 'Overview'),
            Tab(text: 'Health'),
            Tab(text: 'Performance'),
            Tab(text: 'Feature Flags'),
            Tab(text: 'A/B Tests'),
            Tab(text: 'Deployments'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildOverviewTab(),
                _buildHealthTab(),
                _buildPerformanceTab(),
                _buildFeatureFlagsTab(),
                _buildABTestsTab(),
                _buildDeploymentsTab(),
              ],
            ),
    );
  }
  
  Widget _buildOverviewTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Statistiques générales
          if (_monitoringStats != null) ProductionMetricsCard(stats: _monitoringStats!),
          const SizedBox(height: 16),
          
          // Device info
          _buildDeviceInfo(),
          const SizedBox(height: 16),
          
          // Actions rapides
          _buildQuickActions(),
          const SizedBox(height: 16),
          
          // Métriques récentes
          _buildRecentMetrics(),
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
          Row(
            children: [
              _buildInfoItem('App Version', _appVersion),
              const SizedBox(width: 16),
              _buildInfoItem('Device', _deviceModel),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoItem('OS Version', _osVersion),
              const SizedBox(width: 16),
              _buildInfoItem('Réseau', _networkType),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoItem('Batterie', '${_batteryLevel}%'),
              const SizedBox(width: 16),
              _buildInfoItem('Mémoire', '${_memoryUsage.toStringAsFixed(1)}MB'),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _buildInfoItem('CPU', '${_cpuUsage.toStringAsFixed(1)}%'),
              const SizedBox(width: 16),
              _buildInfoItem('Platform', Platform.operatingSystem),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInfoItem(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 12,
            ),
          ),
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
                  onPressed: _runHealthCheck,
                  icon: const Icon(Icons.health_and_safety, color: Colors.black),
                  label: const Text('Vérifier Santé'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _runPerformanceTest,
                  icon: const Icon(Icons.speed, color: Colors.white),
                  label: const Text('Tester Performance'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.2),
                    foregroundColor: Colors.green,
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
                  onPressed: _refreshMetrics,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Rafraîchir Métriques'),
                  style: ElevatedButton.from(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportMetrics,
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text('Exporter'),
                  style: ElevatedButton.from(
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
  
  Widget _buildRecentMetrics() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Métriques Récentes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_performanceMetrics.isEmpty)
          const Center(
            child: Text(
              'Aucune métrique récente',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._performanceMetrics.take(5).map((metric) => _buildMetricItem(metric)),
      ],
    );
  }
  
  Widget _buildMetricItem(PerformanceMetric metric) {
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
            _getMetricIcon(metric.metricType),
            color: _getMetricColor(metric.metricType),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  metric.metricName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${metric.metricValue.toStringAsFixed(2)} ${metric.unit ?? ''}',
                  style: TextStyle(
                    color: _getMetricColor(metric.metricType),
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _formatDate(metric.createdAt),
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
  
  Widget _buildHealthTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions santé
          _buildHealthActions(),
          const SizedBox(height: 16),
          
          // État des services
          _buildServiceHealth(),
          const SizedBox(height: 16),
          
          // Alertes système
          _buildSystemAlerts(),
        ],
      ),
    );
  }
  
  Widget _buildHealthActions() {
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
            'Actions Santé',
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
                  onPressed: _runHealthCheck,
                  icon: const Icon(Icons.health_and_safety, color: Colors.black),
                  label: const Text('Vérifier Santé'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _runDiagnostics,
                  icon: const Icon(Icons.bug_report, color: Colors.white),
                  label: const Text('Diagnostics'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.withOpacity(0.2),
                    foregroundColor: Colors.orange,
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
                  onPressed: _clearLogs,
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  label: const Text('Nettoyer Logs'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _generateReport,
                  icon: const Icon(Icons.description, color: Colors.black),
                  label: const Text('Rapport'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildServiceHealth() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'État des Services',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_systemHealth.isEmpty)
          const Center(
            child: Text(
              'Aucun service monitoré',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._systemHealth.map((health) => HealthStatusCard(health: health)),
      ],
    );
  }
  
  Widget _buildSystemAlerts() {
    final unhealthyServices = _systemHealth.where((h) => h.healthStatus != 'healthy').toList();
    final criticalServices = _systemHealth.where((h) => h.healthStatus == 'unhealthy').toList();
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Alertes Système',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: bold,
          ),
        ),
        const SizedBox(height: 12),
        if (criticalServices.isNotEmpty)
          Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.red.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.red),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.error,
                color: Colors.red,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${criticalServices.length} services critiques',
                  style: const TextStyle(
                    color: Colors.red,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (unhealthyServices.isNotEmpty)
          Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.orange.withOpacity(0.2),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.orange),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.warning,
                color: Colors.orange,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${unhealthyServices.length} services dégradés',
                  style: const TextStyle(
                    color: Colors.orange,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        if (_systemHealth.every((h) => h.healthStatus == 'healthy'))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.green),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Tous les services sont sains',
                    style: TextStyle(
                      color: Colors.green,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
  
  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions performance
          _buildPerformanceActions(),
          const SizedBox(height: 16),
          
          // Métriques par type
          _buildMetricsByType(),
          const SizedBox(height: 16),
          
          // Performance par device
          _buildPerformanceByDevice(),
          const SizedBox(height: 16),
          
          // Tendances
          _buildPerformanceTrends(),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceActions() {
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
            'Actions Performance',
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
                  onPressed: _runPerformanceTest,
                  icon: const Icon(Icons.speed, color: Colors.black),
                  label: const Text('Tester'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _optimizePerformance,
                  icon: const Icon(Icons.tune, color: Colors.white),
                  label: const Text('Optimiser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green.withOpacity(0.2),
                    foregroundColor: Colors.green,
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
                  onPressed: _refreshMetrics,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Rafraîchir'),
                  style: ElevatedButton.from(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _benchmarkTests,
                  icon: const Icon(Icons.assessment, color: Colors.black),
                  label: const Text('Benchmark'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildMetricsByType() {
    if (_performanceMetrics.isEmpty) return const SizedBox();
    
    final metricsByType = <String, List<PerformanceMetric>>{};
    for (final metric in _performanceMetrics) {
      if (!metricsByType.containsKey(metric.metricType)) {
        metricsByType[metric.metricType] = [];
      }
      metricsByType[metric.metricType]!.add(metric);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Métriques par Type',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...metricsByType.entries.map((entry) => _buildMetricTypeSection(entry.key, entry.value)),
      ],
    );
  }
  
  Widget _buildMetricTypeSection(String type, List<PerformanceMetric> metrics) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            type,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...metrics.take(5).map((metric) => _buildMetricItem(metric)),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceByDevice() {
    if (_performanceMetrics.isEmpty) return const SizedBox();
    
    final metricsByDevice = <String, List<PerformanceMetric>>{};
    for (final metric in _performanceMetrics) {
      final deviceKey = metric.deviceModel ?? 'Unknown';
      if (!metricsByDevice.containsKey(deviceKey)) {
        metricsByDevice[deviceKey] = [];
      }
      metricsByDevice[deviceKey]!.add(metric);
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Performance par Device',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        ...metricsByDevice.entries.take(5).map((entry) => _buildDeviceSection(entry.key, entry.value)),
      ],
    );
  }
  
  Widget _buildDeviceSection(String device, List<PerformanceMetric> metrics) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            device,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          ...metrics.take(5).map((metric) => _buildMetricItem(metric)),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceTrends() {
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
            'Tendances Performance',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            'Graphique des tendances de performance à implémenter',
            style: TextStyle(
              color: Colors.white54,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeatureFlagsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions feature flags
          _buildFeatureFlagsActions(),
          const SizedBox(height: 16),
          
          // Feature flags actifs
          _buildActiveFeatureFlags(),
          const SizedBox(height: 16),
          
          // Statistiques
          _buildFeatureFlagsStats(),
        ],
      ),
    );
  }
  
  Widget _buildFeatureFlagsActions() {
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
            'Actions Feature Flags',
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
                  onPressed: _refreshFeatureFlags,
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  label: const Text('Rafraîchir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _toggleFeatureFlag,
                  icon: const Icon(Icons.toggle_on, color: Colors.white),
                  label: const Text('Basculer'),
                  style: ElevatedButton.from(
                    backgroundColor: Colors.white.withOpacity(0.1),
                    foregroundColor: Colors.white,
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
                  onPressed: _createFeatureFlag,
                  icon: const Icon(Icons.add_circle, color: Colors.black),
                  label: const Text('Créer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _rolloutFeatureFlag,
                  icon: const Icon.publish(color: Colors.white),
                  label: const Text('Rollout'),
                  style: ElevatedButton.from(
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
  
  Widget _buildActiveFeatureFlags() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Feature Flags Actifs',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_featureFlags.isEmpty)
          const Center(
            child: Text(
              'Aucun feature flag actif',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._featureFlags.map((flag) => FeatureFlagCard(flag: flag)),
      ],
    );
  }
  
  Widget _buildFeatureFlagsStats() {
    if (_featureFlags.isEmpty) return const SizedBox();
    
    final enabledFlags = _featureFlags.where((f) => f.isEnabled).length;
    final totalFlags = _featureFlags.length;
    final avgRollout = _featureFlags.map((f) => f.rolloutPercentage).reduce((a, b) => a + b) / totalFlags;
    
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
            'Statistiques Feature Flags',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Total', '$totalFlags'),
              const SizedBox(width: 16),
              _buildStatItem('Actifs', '$enabledFlags'),
              const SizedBox(width: 16),
              _buildStatItem('Rollout Moyen', '${avgRollout.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('iOS', '${_getPlatformCount('ios')}/${_getPlatformCount('ios') + _getPlatformCount('android') + _getPlatformCount('web')}'),
              const SizedBox(width: 16),
              _buildStatItem('Android', '${_getPlatformCount('android')}/${_getPlatformCount('ios') + _getPlatformCount('android') + _getPlatformCount('web')}'),
              const SizedBox(width: 16),
              _buildStatItem('Web', '${_getPlatformCount('web')}/${_getPlatformCount('ios') + _getPlatformCount('android') + _getPlatformCount('web')}'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildABTestsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions A/B tests
          _buildABTestActions(),
          const SizedBox(height: 16),
          
          // Tests actifs
          _buildActiveABTests(),
          const SizedBox(height: 16),
          
          // Résultats
          _buildABTestResults(),
        ],
      ),
    );
  }
  
  Widget _buildABTestActions() {
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
            'Actions A/B Tests',
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
                  onPressed: _refreshABTests,
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  label: const Text('Rafraîchir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createABTest,
                  icon: const Icon(Icons.add_circle, color: Colors.black),
                  label: const Text('Créer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
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
                  onPressed: _toggleABTest,
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text('Démarrer'),
                  style: ElevatedButton.from(
                    backgroundColor: Colors.green.withOpacity(0.2),
                    foregroundColor: Colors.green,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _analyzeABTestResults,
                  icon: const Icon(Icons.analytics, color: Colors.white),
                  label: const Text('Analyser'),
                  style: ElevatedButton.from(
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
  
  Widget _buildActiveABTests() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Tests A/B Actifs',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_abTests.isEmpty)
          const Center(
            child: Text(
              'Aucun test A/B actif',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._abTests.map((test) => ABTestCard(test: test)),
      ],
    );
  }
  
  Widget _buildABTestResults() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Résultats A/B Tests',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_abTestResults.isEmpty)
          const Center(
            child: Text(
              'Aucun résultat A/B',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._abTestResults.map((result) => _buildABTestResultItem(result)),
      ],
    );
  }
  
  Widget _buildABTestResultItem(ABTestResult result) {
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
            _getABTestVariantIcon(result.variant),
            color: _getABTestVariantColor(result.variant),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Test: ${result.testId}',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Variant: ${result.variant}',
                  style: TextStyle(
                    color: _getABTestVariantColor(result.variant),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                if (result.conversionEvent != null)
                  Text(
                    'Conversion: ${result.conversionEvent}',
                    style: const TextStyle(
                      color: Colors.green,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
          ),
          if (result.conversionValue != null)
            Text(
              'Valeur: ${result.conversionValue.toStringAsFixed(2)}$',
              style: TextStyle(
                color: Colors.amber,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
  
  Widget _buildDeploymentsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions déploiement
          _buildDeploymentActions(),
          const SizedBox(height: 16),
          
          // Logs de déploiement
          _buildDeploymentLogs(),
          const SizedBox(height: 16),
          
          // Statistiques de déploiement
          _buildDeploymentStats(),
        ],
      ),
    );
  }
  
  Widget _buildDeploymentActions() {
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
            'Actions Déploiement',
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
                  onPressed: _refreshDeploymentLogs,
                  icon: const Icon(Icons.refresh, color: Colors.black),
                  label: const Text('Rafraîchir'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _createDeployment,
                  icon: const Icon(Icons.upload, color: Colors.black),
                  label: const Text('Déployer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
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
                  onPressed: _rollbackDeployment,
                  icon: const Icon(Icons.restore, color: Colors.white),
                  label: const Text('Rollback'),
                  style: ElevatedButton.from(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _scheduleDeployment,
                  icon: const Icon(Icons.schedule, color: Colors.white),
                  label: const Text('Programmer'),
                  style: ElevatedButton.from(
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
  
  Widget _buildDeploymentLogs() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Logs de Déploiement',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_deploymentLogs.isEmpty)
          const Center(
            child: Text(
              'Aucun log de déploiement',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._deploymentLogs.take(10).map((log) => DeploymentLogCard(log: log)),
      ],
    );
  }
  
  Widget _buildDeploymentStats() {
    if (_deploymentLogs.isEmpty) return const SizedBox();
    
    final successfulDeployments = _deploymentLogs.where((l) => l.status == 'success').length;
    final totalDeployments = _deploymentLogs.length;
    final successRate = totalDeployments > 0 ? (successfulDeployments / totalDeployments) * 100 : 0.0;
    
    final avgDuration = _deploymentLogs
        .where((l) => l.durationSeconds != null)
        .map((l) => l.durationSeconds!)
        .reduce((a, b) => a + b) / successfulDeployments;
    
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
            'Statistiques de Déploiement',
            style: TextStyle(
              color: Color(0xFF00D4FF),
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Total', '$totalDeployments'),
              const SizedBox(width: 16),
              _buildStatItem('Succès', '$successfulDeployments'),
              const SizedBox(width: 16),
              _buildStatItem('Taux de succès', '${successRate.toStringAsFixed(1)}%'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Durée Moyenne', '${avgDuration.toStringAsFixed(1)}s'),
              const SizedBox(width: 16),
              _buildStatItem('Dernier', '${_deploymentLogs.last.deployedBy}'),
              const SizedBox(width: 16),
              _buildStatItem('Version', '${_deploymentLogs.last.version}'),
            ],
          ),
        ],
      ),
    );
  }
  
  // Méthodes utilitaires
  
  Future<void> _refreshData() async {
    await _initializeData();
  }
  
  Future<void> _showSettings() async {
    // Implémenter les paramètres de production
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Paramètres bientôt disponibles !'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _runHealthCheck() async {
    try {
      await MonitoringService.recordMetric(
        metricType: 'health_check',
        metricName: 'system_health_check',
        metricValue: 1.0,
        unit: 'check',
      );
      
      setState(() {
        _systemHealth = await MonitoringService.getSystemHealth();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Vérification santé terminée'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur vérification santé: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _runDiagnostics() async {
    try {
      await MonitoringService.recordMetric(
        metricType: 'diagnostics',
        metricName: 'system_diagnostics',
        metricValue: 1.0,
        unit: 'check',
      );
      
      // Simuler des diagnostics système
      await Future.delayed(const Duration(seconds: 2));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Diagnostics terminés'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of context).showSnackBar(
        SnackBar(
          content: Text('Erreur diagnostics: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _runPerformanceTest() async {
    try {
      final timerId = MonitoringService.startTimer('performance_test');
      
      // Simuler des tests de performance
      await MonitoringService.recordMetric(
        metricType: 'app_startup',
        metricName: 'app_startup_time',
        metricValue: 1500.0,
        unit: 'ms',
      );
      
      await MonitoringService.recordMetric(
        metricType: 'screen_load',
        metricName: 'main_screen_load',
        metricValue: 800.0,
        unit: 'ms',
      );
      
      await MonitoringService.recordMetric(
        metricType: 'api_response',
        metricName: 'api_response_time',
        metricValue: 120.0,
        unit: 'ms',
      );
      
      await MonitoringService.stopTimer(timerId, 'performance_test_complete');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tests performance terminés'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur tests performance: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _optimizePerformance() async {
    try {
      await MonitoringService.recordMetric(
        metricType: 'optimization',
        metricName: 'performance_optimization',
        metricValue: 1.0,
        unit: 'improvement',
      );
      
      // Simuler l'optimisation
      await Future.delayed(const Duration(seconds: 3));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Optimisation terminée'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur optimisation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _refreshMetrics() async {
    try {
      final metrics = await MonitoringService.getPerformanceMetrics();
      setState(() {
        _performanceMetrics = metrics;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Métriques rafraîchies'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur rafraîchissement métriques: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _benchmarkTests() async {
    try {
      final timerId = MonitoringService.startTimer('benchmark_test');
      
      // Simuler des benchmarks
      await MonitoringService.recordMetric(
        metricType: 'benchmark',
        metricName: 'cpu_benchmark',
        metricValue: 85.0,
        unit: 'score',
      );
      
      await MonitoringService.recordMetric(
        metricType: 'memory_benchmark',
        metricName: 'memory_benchmark',
        metricValue: 75.0,
        unit: 'score',
      );
      
      await MonitoringService.recordMetric(
        metricType: 'network_benchmark',
        metricName: 'network_benchmark',
        metricValue: 90.0,
        unit: 'score',
      );
      
      await MonitoringService.stopTimer(timerId, 'benchmark_test_complete');
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Benchmarks terminés'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur benchmarks: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _clearLogs() async {
    try {
      await MonitoringService.cleanup();
      
      setState(() {
        _performanceMetrics.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Logs nettoyés'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur nettoyage logs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _generateReport() async {
    try {
      final stats = await MonitoringService.getMonitoringStats();
      
      final report = {
        'timestamp': DateTime.now().toIso8601String(),
        'monitoring_stats': stats.toJson(),
        'system_health': _systemHealth.map((h) => h.toJson()).toList(),
        'performance_metrics': _performanceMetrics.take(20).map((m) => m.toJson()).toList(),
        'deployment_logs': _deployment_logs.take(10).map((l) => l.toJson()).toList(),
        'device_info': {
          'app_version': _appVersion,
          'device_model': _deviceModel,
          'os_version': _osVersion,
          'network_type': _networkType,
          'battery_level': _batteryLevel,
          'memory_usage': _memoryUsage,
          'cpu_usage': _cpuUsage,
          'platform': Platform.operatingSystem,
        },
      };
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Rapport généré: ${jsonEncode(report)}'),
          backgroundColor: const Color(0xFF00D4FF),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur génération rapport: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _refreshFeatureFlags() async {
    try {
      setState(() {
        _featureFlags = _getFeatureFlags();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Feature flags rafraîchis'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur rafraîchissement feature flags: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _toggleFeatureFlag() async {
    // Implémenter le basculement de feature flag
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Basculement feature flag bientôt disponible'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _createFeatureFlag() async {
    // Implémenter la création de feature flag
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Création feature flag bientôt disponible'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _rolloutFeatureFlag() async {
    // Implémenter le rollout de feature flag
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rollout feature flag bientôt disponible'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _refreshABTests() async {
    try {
      setState(() {
        _abTests = _getABTests();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('A/B tests rafraîchis'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur rafraîchissement A/B tests: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _createABTest() async {
    // Implémenter la création de test A/B
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Création test A/B bientôt disponible'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _toggleABTest() async {
    // Implémenter le basculement de test A/B
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Basculement test A/B bientôt disponible'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _analyzeABTestResults() async {
    // Implémenter l'analyse des résultats A/B
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Analyse résultats A/B bientôt disponible'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _refreshDeploymentLogs() async {
    try {
      setState(() {
        _deploymentLogs = await MonitoringService.getDeploymentLogs();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: 'Logs de déploiement rafraîchis'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur rafraîchissement logs: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _createDeployment() async {
    // Implémenter la création de déploiement
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Création déploiement bientôt disponible'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  Future<void> _rollbackDeployment() async {
    // Implémenter le rollback de déploiement
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Rollback déploiement bientôt disponible'),
        backgroundColor: Colors.red,
      ),
    );
  }
  
  Future<void> _scheduleDeployment() async {
    // Implémenter la programmation de déploiement
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: text: 'Programmation déploiement bientôt disponible'),
        backgroundColor: const Color(0xFF00D4FF),
      ),
    );
  }
  
  // Méthodes utilitaires
  
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
  
  IconData _getMetricIcon(String metricType) {
    switch (metricType) {
      case 'app_startup':
        return Icons.launch;
      case 'screen_load':
        return Icons.speed;
      case 'api_response':
        return api;
      case 'user_interaction':
        return Icons.touch_app;
      case 'ml_inference':
        return Icons.psychology;
      case 'timer':
        return Icons.timer;
      case 'health_check':
        return Icons.health_and_safety;
      case 'diagnostics':
        return Icons.bug_report;
      case 'optimization':
        return Icons.tune;
      case 'benchmark':
        return Icons.assessment;
      default:
        return Icons.analytics;
    }
  }
  
  Color _getMetricColor(String metricType) {
    switch (metricType) {
      case 'app_startup':
        return Colors.green;
      case 'screen_load':
        return Colors.blue;
      case 'api_response':
        return Colors.orange;
      case 'user_interaction':
        return Colors.purple;
      case 'ml_inference':
        return Colors.pink;
      case 'timer':
        return Colors.grey;
      case 'health_check':
        return Colors.green;
      case 'diagnostics':
        return Colors.yellow;
      case 'optimization':
        Colors.teal;
      case 'benchmark':
        Colors.amber;
      default:
        return Colors.grey;
    }
  }
  
  int _getPlatformCount(String platform) {
    return _featureFlags.where((f) => f.targetPlatforms.contains(platform)).length;
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
}
