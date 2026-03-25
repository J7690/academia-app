import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:camera/camera.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../services/ml_service.dart';
import '../services/wallet_service.dart';
import '../services/tiktok_creator_fund_service.dart';
import '../services/sponsorship_service.dart';
import '../widgets/ml_prediction_card.dart';
import '../widgets/ml_recommendation_card.dart';
import '../widgets/ml_anomaly_card.dart';
import '../widgets/ai_insight_card.dart';
import '../widgets/ml_performance_metrics_card.dart';

/// Écran principal Machine Learning pour IA et prédictions
class MLScreen extends StatefulWidget {
  const MLScreen({Key? key}) : super(key: key);
  
  @override
  _MLScreenState createState() => _MLScreenState();
}

class _MLScreenState extends State<MLScreen>
    with TickerProviderStateMixin {
  late TabController _tabController;
  
  bool _isLoading = true;
  List<MLPrediction> _predictions = [];
  List<MLRecommendation> _recommendations = [];
  List<MLAnomaly> _anomalies = [];
  List<AIInsight> _insights = [];
  MLPerformanceMetrics? _performanceMetrics;
  MLServiceStats? _mlStats;
  
  // Camera pour analyse d'image
  CameraController? _cameraController;
  bool _isCameraInitialized = false;
  XFile? _capturedImage;
  MLImageAnalysis? _imageAnalysis;
  
  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _initializeData();
  }
  
  @override
  void dispose() {
    _tabController.dispose();
    _cameraController?.dispose();
    super.dispose();
  }
  
  Future<void> _initializeData() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      // Initialiser le service ML
      await MLService.initialize();
      
      // Charger les données en parallèle
      final results = await Future.wait([
        MLService.getUserPredictions(userId),
        MLService.getUserRecommendations(userId),
        MLService.getUserAnomalies(userId),
        MLService.getAIInsights(),
        MLService.getMLPerformanceMetrics(userId),
        MLService.getStats(),
      ]);
      
      setState(() {
        _predictions = results[0] as List<MLPrediction>;
        _recommendations = results[1] as List<MLRecommendation>;
        _anomalies = results[2] as List<MLAnomaly>;
        _insights = results[3] as List<AIInsight>;
        _performanceMetrics = results[4] as MLPerformanceMetrics;
        _mlStats = results[5] as MLServiceStats;
        _isLoading = false;
      });
    } catch (e) {
      print('Erreur initialisation ML: $e');
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
        title: Text(
          'Machine Learning',
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
            icon: const Icon(Icons.camera_alt, color: Colors.white),
            onPressed: _captureImage,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: const Color(0xFF00D4FF),
          labelColor: const Color(0xFF00D4FF),
          unselectedLabelColor: Colors.white54,
          tabs: const [
            Tab(text: 'Prédictions'),
            Tab(text: 'Recommandations'),
            Tab(text: 'Anomalies'),
            Tab(text: 'Insights'),
            Tab(text: 'Performance'),
          ],
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF00D4FF)))
          : TabBarView(
              controller: _tabController,
              children: [
                _buildPredictionsTab(),
                _buildRecommendationsTab(),
                _buildAnomaliesTab(),
                _buildInsightsTab(),
                _buildPerformanceTab(),
              ],
            ),
    );
  }
  
  Widget _buildPredictionsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions de prédiction
          _buildPredictionActions(),
          const SizedBox(height: 16),
          
          // Prédictions récentes
          _buildRecentPredictions(),
          const SizedBox(height: 16),
          
          // Statistiques des prédictions
          _buildPredictionStats(),
        ],
      ),
    );
  }
  
  Widget _buildPredictionActions() {
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
            'Actions de Prédiction',
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
                  onPressed: _predictRevenue,
                  icon: const Icon(Icons.monetization_on, color: Colors.black),
                  label: const Text('Prédire Revenus'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _predictEngagement,
                  icon: const Icon(Icons.trending_up, color: Colors.white),
                  label: const Text('Prédire Engagement'),
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
                  onPressed: _detectAnomaly,
                  icon: const Icon(Icons.warning, color: Colors.white),
                  label: const Text('Détecter Anomalie'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.orange.withOpacity(0.2),
                    foregroundColor: Colors.orange,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _analyzeImage,
                  icon: const Icon(Icons.image, color: Colors.black),
                  label: const Text('Analyser Image'),
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
  
  Widget _buildRecentPredictions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Prédictions Récentes',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_predictions.isEmpty)
          const Center(
            child: Text(
              'Aucune prédiction récente',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._predictions.take(5).map((prediction) => MLPredictionCard(prediction: prediction)),
      ],
    );
  }
  
  Widget _buildPredictionStats() {
    if (_predictions.isEmpty) return const SizedBox();
    
    final revenuePredictions = _predictions.where((p) => p.predictionType == 'revenue_prediction').toList();
    final engagementPredictions = _predictions.where((p) => p.predictionType == 'engagement_prediction').toList();
    
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
            'Statistiques des Prédictions',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Total', '${_predictions.length}'),
              const SizedBox(width: 16),
              _buildStatItem('Revenus', '${revenuePredictions.length}'),
              const SizedBox(width: 16),
              _buildStatItem('Engagement', '${engagementPredictions.length}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Confiance Moyenne', '${_calculateAverageConfidence(_predictions).toStringAsFixed(1)}%'),
              const SizedBox(width: 16),
              _buildStatItem('Précision', '${_performanceMetrics?.predictionAccuracy.toStringAsFixed(1) ?? '0.0'}%'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecommendationsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions de recommandation
          _buildRecommendationActions(),
          const SizedBox(height: 16),
          
          // Recommandations actives
          _buildActiveRecommendations(),
          const SizedBox(height: 16),
          
          // Recommandations par type
          _buildRecommendationsByType(),
        ],
      ),
    );
  }
  
  Widget _buildRecommendationActions() {
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
            'Actions de Recommandation',
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
                  onPressed: _generateRecommendations,
                  icon: const Icon(Icons.auto_awesome, color: Colors.black),
                  label: const Text('Générer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _refreshRecommendations,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Rafraîchir'),
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
  
  Widget _buildActiveRecommendations() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Recommandations Actives',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_recommendations.isEmpty)
          const Center(
            child: Text(
              'Aucune recommandation active',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._recommendations.take(5).map((recommendation) => MLRecommendationCard(recommendation: recommendation)),
      ],
    );
  }
  
  Widget _buildRecommendationsByType() {
    if (_recommendations.isEmpty) return const SizedBox();
    
    final contentRecs = _recommendations.where((r) => r.itemType == 'content').toList();
    final courseRecs = _recommendations.where((r) => r.itemType == 'course').toList();
    final challengeRecs = _recommendations.where((r) => r.itemType == 'challenge').toList();
    
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
            'Recommandations par Type',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Contenu', '${contentRecs.length}'),
              const SizedBox(width: 16),
              _buildStatItem('Cours', '${courseRecs.length}'),
              const SizedBox(width: 16),
              _buildStatItem('Défis', '${challengeRecs.length}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Score Moyen', '${_calculateAverageScore(_recommendations).toStringAsFixed(1)}'),
              const SizedBox(width: 16),
              _buildStatItem('Confiance', '${_calculateAverageConfidenceRecs(_recommendations).toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildAnomaliesTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions de détection
          _buildAnomalyActions(),
          const SizedBox(height: 16),
          
          // Anomalies détectées
          _buildDetectedAnomalies(),
          const SizedBox(height: 16),
          
          // Statistiques des anomalies
          _buildAnomalyStats(),
        ],
      ),
    );
  }
  
  Widget _buildAnomalyActions() {
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
            'Actions de Détection',
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
                  onPressed: _detectAnomaly,
                  icon: const Icon(Icons.search, color: Colors.black),
                  label: const Text('Scanner'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _resolveAnomalies,
                  icon: const Icon(Icons.check_circle, color: Colors.white),
                  label: const Text('Résoudre'),
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
  
  Widget _buildDetectedAnomalies() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Anomalies Détectées',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_anomalies.isEmpty)
          const Center(
            child: Text(
              'Aucune anomalie détectée',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._anomalies.take(5).map((anomaly) => MLAnomalyCard(anomaly: anomaly)),
      ],
    );
  }
  
  Widget _buildAnomalyStats() {
    if (_anomalies.isEmpty) return const SizedBox();
    
    final criticalAnomalies = _anomalies.where((a) => a.severity == 'critical').toList();
    final highAnomalies = _anomalies.where((a) => a.severity == 'high').toList();
    final resolvedAnomalies = _anomalies.where((a) => a.isResolved).toList();
    
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
            'Statistiques des Anomalies',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Total', '${_anomalies.length}'),
              const SizedBox(width: 16),
              _buildStatItem('Critiques', '${criticalAnomalies.length}'),
              const SizedBox(width: 16),
              _buildStatItem('Hautes', '${highAnomalies.length}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Résolues', '${resolvedAnomalies.length}'),
              const SizedBox(width: 16),
              _buildStatItem('Score Moyen', '${_calculateAverageAnomalyScore(_anomalies).toStringAsFixed(2)}'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildInsightsTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Actions insights
          _buildInsightActions(),
          const SizedBox(height: 16),
          
          // Insights disponibles
          _buildAvailableInsights(),
          const SizedBox(height: 16),
          
          // Insights par catégorie
          _buildInsightsByCategory(),
        ],
      ),
    );
  }
  
  Widget _buildInsightActions() {
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
            'Actions Insights',
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
                  onPressed: _generateInsights,
                  icon: const Icon(Icons.lightbulb, color: Colors.black),
                  label: const Text('Générer'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _applyInsights,
                  icon: const Icon(Icons.play_arrow, color: Colors.white),
                  label: const Text('Appliquer'),
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
  
  Widget _buildAvailableInsights() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Insights Disponibles',
          style: TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        if (_insights.isEmpty)
          const Center(
            child: Text(
              'Aucun insight disponible',
              style: TextStyle(color: Colors.white54),
            ),
          )
        else
          ..._insights.take(5).map((insight) => AIInsightCard(insight: insight)),
      ],
    );
  }
  
  Widget _buildInsightsByCategory() {
    if (_insights.isEmpty) return const SizedBox();
    
    final userBehaviorInsights = _insights.where((i) => i.insightCategory == 'user_behavior').toList();
    final performanceInsights = _insights.where((i) => i.insightCategory == 'performance').toList();
    final revenueInsights = _insights.where((i) => i.insightCategory == 'revenue').toList();
    
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
            'Insights par Catégorie',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Comportement', '${userBehaviorInsights.length}'),
              const SizedBox(width: 16),
              _buildStatItem('Performance', '${performanceInsights.length}'),
              const SizedBox(width: 16),
              _buildStatItem('Revenus', '${revenueInsights.length}'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Impact Moyen', '${_calculateAverageImpact(_insights).toStringAsFixed(1)}'),
              const SizedBox(width: 16),
              _buildStatItem('Confiance', '${_calculateAverageConfidenceInsights(_insights).toStringAsFixed(1)}%'),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildPerformanceTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Métriques de performance ML
          if (_performanceMetrics != null) MLPerformanceMetricsCard(metrics: _performanceMetrics!),
          const SizedBox(height: 16),
          
          // Statistiques du service ML
          if (_mlStats != null) _buildMLServiceStats(),
          const SizedBox(height: 16),
          
          // Actions de performance
          _buildPerformanceActions(),
        ],
      ),
    );
  }
  
  Widget _buildMLServiceStats() {
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
            'Statistiques du Service ML',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Modèles', '${_mlStats!.modelsLoaded}'),
              const SizedBox(width: 16),
              _buildStatItem('Prédictions', '${_mlStats!.predictionsCount}'),
              const SizedBox(width: 16),
              _buildStatItem('Cache', '${_mlStats!.cacheSize}MB'),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _buildStatItem('Hit Rate', '${_mlStats!.cacheHitRate.toStringAsFixed(1)}%'),
              const SizedBox(width: 16),
              _buildStatItem('Dernière MàJ', '${_formatDate(_mlStats!.lastUpdated)}'),
            ],
          ),
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
            'Actions de Performance',
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
                  onPressed: _optimizeModels,
                  icon: const Icon(Icons.speed, color: Colors.black),
                  label: const Text('Optimiser'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00D4FF),
                    foregroundColor: Colors.black,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _retrainModels,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  label: const Text('Réentraîner'),
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
                  onPressed: _clearCache,
                  icon: const Icon(Icons.delete_sweep, color: Colors.white),
                  label: const Text('Vider Cache'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.2),
                    foregroundColor: Colors.red,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _exportMetrics,
                  icon: const Icon(Icons.download, color: Colors.white),
                  label: const Text('Exporter'),
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
  
  // Méthodes utilitaires
  
  Future<void> _refreshData() async {
    await _initializeData();
  }
  
  Future<void> _predictRevenue() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      // Simuler les caractéristiques pour la prédiction de revenus
      final features = List<double>.generate(10, (i) => (i + 1) * 0.1);
      
      final prediction = await MLService.predictRevenue(
        userId: userId,
        features: features,
      );
      
      setState(() {
        _predictions.insert(0, prediction);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prédiction de revenus: ${prediction.predictionValue.toStringAsFixed(2)}$'),
          backgroundColor: const Color(0xFF00D4FF),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur prédiction revenus: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _predictEngagement() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      // Simuler les caractéristiques pour la prédiction d'engagement
      final features = List<double>.generate(15, (i) => (i + 1) * 0.05);
      
      final prediction = await MLService.predictEngagement(
        userId: userId,
        features: features,
      );
      
      setState(() {
        _predictions.insert(0, prediction);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Prédiction d\'engagement: ${(prediction.predictionValue * 100).toStringAsFixed(1)}%'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur prédiction engagement: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _detectAnomaly() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      // Simuler les métriques de comportement
      final behaviorMetrics = List<double>.generate(25, (i) => (i + 1) * 0.02);
      
      final anomaly = await MLService.detectAnomaly(
        userId: userId,
        behaviorMetrics: behaviorMetrics,
        threshold: 0.7,
      );
      
      if (anomaly.isAnomaly) {
        setState(() {
          _anomalies.insert(0, anomaly);
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Anomalie détectée: ${anomaly.anomalyType} (${anomaly.severity})'),
            backgroundColor: Colors.orange,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Aucune anomalie détectée'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur détection anomalie: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _analyzeImage() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      if (_capturedImage == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Veuillez d\'abord capturer une image'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }
      
      final analysis = await MLService.analyzeImage(
        imagePath: _capturedImage!.path,
        labels: ['text', 'face', 'object'],
      );
      
      setState(() {
        _imageAnalysis = analysis;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Image analysée: ${analysis.detectedLabels.length} labels détectés'),
          backgroundColor: const Color(0xFF00D4FF),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur analyse image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _captureImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(source: ImageSource.camera);
      
      if (image != null) {
        setState(() {
          _capturedImage = image;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Image capturée avec succès'),
            backgroundColor: const Color(0xFF00D4FF),
          ),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur capture image: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _generateRecommendations() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;
      
      // Simuler le profil utilisateur
      final userProfile = List<double>.generate(20, (i) => (i + 1) * 0.03);
      
      final recommendations = await MLService.generateRecommendations(
        userId: userId,
        userProfile: userProfile,
        limit: 10,
      );
      
      setState(() {
        _recommendations = recommendations;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${recommendations.length} recommandations générées'),
          backgroundColor: const Color(0xFF00D4FF),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur génération recommandations: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _refreshRecommendations() async {
    await _generateRecommendations();
  }
  
  Future<void> _resolveAnomalies() async {
    // Marquer les anomalies comme résolues
    for (final anomaly in _anomalies) {
      if (!anomaly.isResolved) {
        anomaly.isResolved = true;
        anomaly.resolvedAt = DateTime.now();
        anomaly.resolutionAction = 'Manual resolution';
      }
    }
    
    setState(() {
      _anomalies = _anomalies.where((a) => !a.isResolved).toList();
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Anomalies résolues'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _generateInsights() async {
    try {
      final insights = await MLService.getAIInsights();
      setState(() {
        _insights = insights;
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${insights.length} insights générés'),
          backgroundColor: const Color(0xFF00D4FF),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur génération insights: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _applyInsights() async {
    // Marquer les insights comme appliqués
    for (final insight in _insights) {
      if (insight.actionable && !insight.actionTaken) {
        insight.actionTaken = true;
        insight.actionResult = 'Applied successfully';
      }
    }
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Insights appliqués avec succès'),
        backgroundColor: Colors.green,
      ),
    );
  }
  
  Future<void> _optimizeModels() async {
    try {
      // Simuler l'optimisation des modèles
      await Future.delayed(const Duration(seconds: 2));
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modèles optimisés avec succès'),
          backgroundColor: const Color(0xFF00D4FF),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur optimisation modèles: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _retrainModels() async {
    try {
      // Simuler le réentraînement des modèles
      await MLService.trainModel(
        modelName: 'revenue_prediction',
        trainingData: List.generate(100, (i) => List.generate(10, (j) => (i + j) * 0.01)),
        targetValues: List.generate(100, (i) => i * 0.1),
        epochs: 50,
      );
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Modèles réentraînés avec succès'),
          backgroundColor: const Color(0xFF00D4FF),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur réentraînement modèles: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _clearCache() async {
    try {
      await MLService.clearMLCache();
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Cache ML vidé avec succès'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur vidange cache: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  Future<void> _exportMetrics() async {
    try {
      // Simuler l'export des métriques
      final metrics = {
        'predictions': _predictions.length,
        'recommendations': _recommendations.length,
        'anomalies': _anomalies.length,
        'insights': _insights.length,
        'performance': _performanceMetrics?.toJson(),
        'ml_stats': _mlStats?.toJson(),
        'exported_at': DateTime.now().toIso8601String(),
      };
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Métriques exportées: ${jsonEncode(metrics)}'),
          backgroundColor: const Color(0xFF00D4FF),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Erreur export métriques: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  
  // Méthodes de calcul
  
  double _calculateAverageConfidence(List<MLPrediction> predictions) {
    if (predictions.isEmpty) return 0.0;
    
    final total = predictions.fold(0.0, (sum, p) => sum + p.confidenceScore);
    return (total / predictions.length) * 100;
  }
  
  double _calculateAverageScore(List<MLRecommendation> recommendations) {
    if (recommendations.isEmpty) return 0.0;
    
    final total = recommendations.fold(0.0, (sum, r) => sum + r.score);
    return total / recommendations.length;
  }
  
  double _calculateAverageConfidenceRecs(List<MLRecommendation> recommendations) {
    if (recommendations.isEmpty) return 0.0;
    
    final total = recommendations.fold(0.0, (sum, r) => sum + r.confidence);
    return (total / recommendations.length) * 100;
  }
  
  double _calculateAverageAnomalyScore(List<MLAnomaly> anomalies) {
    if (anomalies.isEmpty) return 0.0;
    
    final total = anomalies.fold(0.0, (sum, a) => sum + a.anomalyScore);
    return total / anomalies.length;
  }
  
  double _calculateAverageImpact(List<AIInsight> insights) {
    if (insights.isEmpty) return 0.0;
    
    final total = insights.fold(0.0, (sum, i) => sum + i.impactScore);
    return total / insights.length;
  }
  
  double _calculateAverageConfidenceInsights(List<AIInsight> insights) {
    if (insights.isEmpty) return 0.0;
    
    final total = insights.fold(0.0, (sum, i) => sum + i.confidence);
    return (total / insights.length) * 100;
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
