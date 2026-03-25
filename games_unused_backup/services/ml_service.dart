import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tensorflow_lite/tensorflow_lite.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart';
import 'package:camera/camera.dart';
import 'package:path_provider/path_provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'cache_service.dart';

/// Service pour le Machine Learning et IA sur device
class MLService {
  static final Map<String, Interpreter> _models = {};
  static final Map<String, List<MLPrediction>> _predictions = {};
  static final Uuid _uuid = Uuid();
  
  /// Initialiser le service ML
  static Future<void> initialize() async {
    try {
      // Charger les modèles pré-entraînés
      await _loadModels();
      
      print('MLService initialisé avec succès');
    } catch (e) {
      print('Erreur initialisation MLService: $e');
      rethrow;
    }
  }
  
  /// Charger les modèles ML
  static Future<void> _loadModels() async {
    try {
      // Modèle de prédiction de revenus
      await _loadModel(
        'revenue_prediction',
        'assets/models/revenue_prediction.tflite',
        [10, 1],
        [1],
      );
      
      // Modèle de prédiction d'engagement
      await _loadModel(
        'engagement_prediction',
        'assets/models/engagement_prediction.tflite',
        [15, 1],
        [3, 1],
      );
      
      // Modèle de recommandation de contenu
      await _loadModel(
        'content_recommendation',
        'assets/models/content_recommendation.tflite',
        [20, 1],
        [10, 1],
      );
      
      // Modèle de détection d'anomalies
      await _loadModel(
        'anomaly_detection',
        'assets/models/anomaly_detection.tflite',
        [25, 1],
        [1],
      );
      
      print('Modèles ML chargés: ${_models.length}');
    } catch (e) {
      print('Erreur chargement modèles: $e');
    }
  }
  
  /// Charger un modèle spécifique
  static Future<void> _loadModel(
    String modelName,
    String modelPath,
    List<int> inputShape,
    List<int> outputShape,
  ) async {
    try {
      final modelPath = await _getModelPath(modelPath);
      final interpreter = await Interpreter.fromFile(modelPath);
      
      _models[modelName] = interpreter;
      
      print('Modèle $modelName chargé: $modelPath');
    } catch (e) {
      print('Erreur chargement modèle $modelName: $e');
    }
  }
  
  /// Obtenir le chemin du modèle
  static Future<String> _getModelPath(String relativePath) async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      return '${directory.path}/$relativePath';
    } catch (e) {
      print('Erreur obtention chemin modèle: $e');
      rethrow;
    }
  }
  
  /// Prédire les revenus d'un utilisateur
  static Future<MLPrediction> predictRevenue({
    required String userId,
    required List<double> features,
    String? modelId,
  }) async {
    try {
      final model = _models['revenue_prediction'];
      if (model == null) {
        throw Exception('Modèle de prédiction de revenus non disponible');
      }
      
      // Préparer les données d'entrée
      final input = Float32List.fromList(features);
      
      // Exécuter la prédiction
      final output = await model.run(input);
      
      // Interpréter le résultat
      final revenue = output[0];
      final confidence = _calculateConfidence(output);
      
      final prediction = MLPrediction(
        id: _uuid.v4(),
        userId: userId,
        modelId: modelId ?? 'revenue_prediction_v1',
        predictionType: 'revenue_prediction',
        predictionValue: revenue,
        confidenceScore: confidence,
        inputData: features,
        metadata: {
          'model': 'revenue_prediction_v1',
          'input_shape': [10, 1],
          'output_shape': [1],
        },
        createdAt: DateTime.now(),
      );
      
      // Sauvegarder la prédiction
      await _savePrediction(prediction);
      
      return prediction;
    } catch (e) {
      print('Erreur prédiction revenus: $e');
      rethrow;
    }
  }
  
  /// Prédire l'engagement d'un utilisateur
  static Future<MLPrediction> predictEngagement({
    required String userId,
    required List<double> features,
    String? modelId,
  }) async {
    try {
      final model = _models['engagement_prediction'];
      if (model == null) {
        throw Exception('Modèle de prédiction d\'engagement non disponible');
      }
      
      final input = Float32List.fromList(features);
      final output = await model.run(input);
      
      final engagementScore = output[0];
      final confidence = _calculateConfidence(output);
      
      final prediction = MLPrediction(
        id: _uuid.v4(),
        userId: userId,
        modelId: modelId ?? 'engagement_prediction_v1',
        predictionType: 'engagement_prediction',
        predictionValue: engagementScore,
        confidenceScore: confidence,
        inputData: features,
        metadata: {
          'model': 'engagement_prediction_v1',
          'input_shape': [15, 1],
          'output_shape': [3, 1],
        },
        createdAt: DateTime.now(),
      );
      
      await _savePrediction(prediction);
      
      return prediction;
    } catch (e) {
      print('Erreur prédiction engagement: $e');
      rethrow;
    }
  }
  
  /// Générer des recommandations de contenu
  static Future<List<MLRecommendation>> generateRecommendations({
    required String userId,
    required List<double> userProfile,
    int limit = 10,
    String? modelId,
  }) async {
    try {
      final model = _models['content_recommendation'];
      if (model == null) {
        throw Exception('Modèle de recommandation non disponible');
      }
      
      final input = Float32List.fromList(userProfile);
      final output = await model.run(input);
      
      // Interpréter les sorties (probabilités)
      final recommendations = <MLRecommendation>[];
      for (int i = 0; i < output.length; i += 10) {
        if (i + 10 <= output.length) {
          final scores = output.sublist(i, i + 10);
          final topScoreIndex = _getTopScoreIndex(scores);
          
          recommendations.add(MLRecommendation(
            id: _uuid.v4(),
            userId: userId,
            itemId: 'content_$i',
            itemType: 'content',
            itemTitle: 'Recommendation $i',
            score: scores[topScoreIndex],
            confidence: _calculateConfidence(scores),
            features: userProfile,
            metadata: {
              'model': 'content_recommendation_v1',
              'all_scores': scores.toList(),
            },
            createdAt: DateTime.now(),
          ));
        }
      }
      
      // Trier par score et limiter
      recommendations.sort((a, b) => b.score.compareTo(a.score));
      final limitedRecommendations = recommendations.take(limit);
      
      // Sauvegarder les recommandations
      for (final rec in limitedRecommendations) {
        await _saveRecommendation(rec);
      }
      
      return limitedRecommendations;
    } catch (e) {
      print('Erreur génération recommandations: $e');
      rethrow;
    }
  }
  
  /// Détecter des anomalies dans le comportement utilisateur
  static Future<MLAnomaly> detectAnomaly({
    required String userId,
    required List<double> behaviorMetrics,
    double threshold = 0.7,
    String? modelId,
  }) async {
    try {
      final model = _models['anomaly_detection'];
      if (model == null) {
        throw Exception('Modèle de détection d\'anomalies non disponible');
      }
      
      final input = Float32List.fromList(behaviorMetrics);
      final output = await model.run(input);
      
      final anomalyScore = output[0];
      final confidence = _calculateConfidence(output);
      
      final isAnomaly = anomalyScore > threshold;
      
      final anomaly = MLAnomaly(
        id: _uuid.v4(),
        userId: userId,
        anomalyType: _classifyAnomalyType(anomalyScore),
        severity: _classifySeverity(anomalyScore),
        anomalyScore: anomalyScore,
        threshold: threshold,
        confidence: confidence,
        behaviorMetrics: behaviorMetrics,
        metadata: {
          'model': 'anomaly_detection_v1',
          'input_shape': [25, 1],
          'output_shape': [1],
        },
        isAnomaly: isAnomaly,
        detectedAt: DateTime.now(),
      );
      
      if (isAnomaly) {
        await _saveAnomaly(anomaly);
      }
      
      return anomaly;
    } catch (e) {
      print('Erreur détection anomalie: $e');
      rethrow;
    }
  }
  
  /// Analyser une image avec ML Kit
  static Future<MLImageAnalysis> analyzeImage({
    required String imagePath,
    List<String> labels = const ['text', 'face', 'object'],
  }) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      
      // Analyser avec ML Kit (simulation)
      final analysis = MLImageAnalysis(
        id: _uuid.v4(),
        imagePath: imagePath,
        detectedLabels: labels,
        confidenceScores: labels.map((label) => 0.85).toList(), // Simulation
        metadata: {
          'image_size': imageBytes.length,
          'analysis_time': DateTime.now(),
        },
        createdAt: DateTime.now(),
      );
      
      return analysis;
    } catch (e) {
      print('Erreur analyse image: $e');
      rethrow;
    }
  }
  
  /// Extraire les caractéristiques d'une image
  static Future<List<double>> extractImageFeatures(String imagePath) async {
    try {
      final imageFile = File(imagePath);
      final imageBytes = await imageFile.readAsBytes();
      
      // Décoder l'image
      final image = decodeImage(imageBytes);
      
      // Extraire les caractéristiques de base
      final features = <double>[];
      
      // Taille de l'image
      features.add(image.width.toDouble());
      features.add(image.height.toDouble());
      
      // Ratio d'aspect
      features.add(image.width / image.height);
      
      // Moyenne des pixels (simulation)
      final pixelData = image.data;
      double sum = 0.0;
      for (int i = 0; i < pixelData.length; i++) {
        sum += pixelData[i];
      }
      features.add(sum / pixelData.length);
      
      // Histogramme simplifié (luminosité)
      final histogram = _calculateHistogram(pixelData);
      features.addAll(histogram);
      
      return features;
    } catch (e) {
      print('Erreur extraction caractéristiques image: $e');
      rethrow;
    }
  }
  
  /// Entraîner un modèle avec des données locales
  static Future<void> trainModel({
    required String modelName,
    required List<List<double>> trainingData,
    required List<double> targetValues,
    String modelType = 'regression',
    int epochs = 100,
    double learningRate = 0.001,
    int batchSize = 32,
  }) async {
    try {
      // Simulation d'entraînement (en réalité, cela nécessite TensorFlow complet)
      print('Entraînement du modèle $modelName simulé...');
      print('Données d\'entraînement: ${trainingData.length} échantillons');
      print('Époques: $epochs, Learning Rate: $learningRate, Batch Size: $batchSize');
      
      // En réalité, ceci utiliserait TensorFlow pour entraîner le modèle
      // et le sauvegarderait comme un nouveau fichier .tflite
      
      // Pour l'instant, nous allons juste simuler le processus
      await _simulateTraining(modelName, epochs);
      
    } catch (e) {
      print('Erreur entraînement modèle: $e');
      rethrow;
    }
  }
  
  /// Simuler l'entraînement d'un modèle
  static Future<void> _simulateTraining(String modelName, int epochs) async {
    for (int epoch = 0; epoch < epochs; epoch++) {
      print('Epoch $epoch/${epochs} - Entraînement simulé...');
      
      // Simuler une perte qui diminue
      final loss = 1.0 - (epoch / epochs) * 0.8;
      
      // Simuler une métrique d'accuracy qui augmente
      final accuracy = 0.5 + (epoch / epochs) * 0.4;
      
      await Future.delayed(const Duration(milliseconds: 100));
      
      print('  Loss: ${loss.toStringAsFixed(4)}, Accuracy: ${(accuracy * 100).toStringAsFixed(1)}%');
    }
    
    print('Entraînement du modèle $modelName terminé');
  }
  
  /// Obtenir les prédictions d'un utilisateur
  static Future<List<MLPrediction>> getUserPredictions(String userId, {int limit = 20}) async {
    try {
      final result = await Supabase.instance.client
          .from('ml_predictions')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      
      return result.map((json) => MLPrediction.fromJson(json)).toList();
    } catch (e) {
      print('Erreur récupération prédictions: $e');
      return [];
    }
  }
  
  /// Obtenir les recommandations d'un utilisateur
  static Future<List<MLRecommendation>> getUserRecommendations(String userId, {int limit = 20}) async {
    try {
      final result = await Supabase.instance.client
          .from('recommendations')
          .select()
          .eq('user_id', userId)
          .order('recommendation_score', ascending: false)
          .limit(limit);
      
      return result.map((json) => MLRecommendation.fromJson(json)).toList();
    } catch (e) {
      print('Erreur récupération recommandations: $e');
      return [];
    }
  }
  
  /// Obtenir les anomalies détectées pour un utilisateur
  static Future<List<MLAnomaly>> getUserAnomalies(String userId, {int limit = 20}) async {
    try {
      final result = await Supabase.instance.client
          .from('anomaly_detection')
          .select()
          .eq('user_id', userId)
          .order('anomaly_score', ascending: false)
          .limit(limit);
      
      return result.map((json) => MLAnomaly.fromJson(json)).toList();
    } catch (e) {
      print('Erreur récupération anomalies: $e');
      return [];
    }
  }
  
  /// Obtenir les insights IA
  static Future<List<AIInsight>> getAIInsights({int limit = 20}) async {
    try {
      final result = await Supabase.instance.client
          .from('ai_insights')
          .select()
          .eq('actionable', true)
          .order('impact_score', ascending: false)
          .limit(limit);
      
      return result.map((json) => AIInsight.fromJson(json)).toList();
    } catch (e) {
      print('Erreur récupération insights: $e');
      return [];
    }
  }
  
  /// Obtenir les métriques de performance ML
  static Future<MLPerformanceMetrics> getMLPerformanceMetrics(String userId) async {
    try {
      // Combiner les métriques de performance ML avec les données utilisateur
      final mlMetrics = await _getMLMetricsFromDB();
      final userMetrics = await _getUserMetrics(userId);
      
      return MLPerformanceMetrics(
        userId: userId,
        modelAccuracy: mlMetrics['accuracy'] ?? 0.0,
        modelPrecision: mlMetrics['precision'] ?? 0.0,
        modelRecall: mlMetrics['recall'] ?? 0.0,
        modelF1Score: mlMetrics['f1_score'] ?? 0.0,
        predictionAccuracy: _calculatePredictionAccuracy(userId),
        userEngagementScore: userMetrics['engagement_score'] ?? 0.0,
        performanceImprovement: userMetrics['performance_improvement'] ?? 0.0,
        cacheHitRate: userMetrics['cache_hit_rate'] ?? 0.0,
        modelInferenceTime: mlMetrics['inference_time_ms'] ?? 0,
        createdAt: DateTime.now(),
      );
    } catch (e) {
      print('Erreur métriques performance ML: $e');
      rethrow;
    }
  }
  
  /// Sauvegarder une prédiction
  static Future<void> _savePrediction(MLPrediction prediction) async {
    try {
      await Supabase.instance.client
          .from('ml_predictions')
          .insert(prediction.toJson());
      
      // Mettre en cache pour accès rapide
      final cacheKey = 'prediction_${prediction.userId}_${prediction.id}';
      await CacheService.set(cacheKey, prediction.toJson());
    } catch (e) {
      print('Erreur sauvegarde prédiction: $e');
    }
  }
  
  /// Sauvegarder une recommandation
  static Future<void> _saveRecommendation(MLRecommendation recommendation) async {
    try {
      await Supabase.instance.client
          .from('recommendations')
          .insert(recommendation.toJson());
      
      final cacheKey = 'recommendation_${recommendation.userId}_${recommendation.id}';
      await CacheService.set(cacheKey, recommendation.toJson());
    } catch (e) {
      print('Erreur sauvegarde recommandation: $e');
    }
  }
  
  /// Sauvegarder une anomalie
  static Future<void> _saveAnomaly(MLAnomaly anomaly) async {
    try {
      await Supabase.instance.client
          .from('anomaly_detection')
          .insert(anomaly.toJson());
      
      final cacheKey = 'anomaly_${anomaly.userId}_${anomaly.id}';
      await CacheService.set(cacheKey, anomaly.toJson());
    } catch (e) {
      print('Erreur sauvegarde anomalie: $e');
    }
  }
  
  /// Obtenir les métriques ML depuis la base
  static Future<Map<String, double>> _getMLMetricsFromDB() async {
    try {
      final result = await Supabase.instance.client
          .from('ml_models')
          .select()
          .eq('is_active', true)
          .maybeSingle();
      
      if (result != null) {
        return {
          'accuracy': result['accuracy']?.toDouble() ?? 0.0,
          'precision': result['precision']?.toDouble() ?? 0.0,
          'recall': result['recall']?.toDouble() ?? 0.0,
          'f1_score': result['f1_score']?.toDouble() ?? 0.0,
          'inference_time_ms': 50.0, // Simulé
        };
      }
      
      return {};
    } catch (e) {
      print('Erreur métriques ML: $e');
      return {};
    }
  }
  
  /// Obtenir les métriques utilisateur
  static Future<Map<String, double>> _getUserMetrics(String userId) async {
    try {
      // Simuler les métriques utilisateur basés sur les données existantes
      final userBehavior = await _getUserBehaviorMetrics(userId);
      final cacheStats = await CacheService.getStats();
      
      return {
        'engagement_score': _calculateEngagementScore(userBehavior),
        'performance_improvement': _calculatePerformanceImprovement(userBehavior),
        'cache_hit_rate': cacheStats.hitRate,
      };
    } catch (e) {
      print('Erreur métriques utilisateur: $e');
      return {};
    }
  }
  
  /// Obtenir les métriques de comportement utilisateur
  static Future<List<Map<String, dynamic>>> _getUserBehaviorMetrics(String userId) async {
    try {
      // Simuler les métriques de comportement
      return [
        {'metric': 'session_duration', 'value': 180.0},
        {'metric': 'page_views', 'value': 15.0},
        {'metric': 'clicks', 'value': 45.0},
        {'metric': 'scroll_depth', 'value': 3.2},
        {'metric': 'time_on_page', 'value': 120.0},
      ];
    } catch (e) {
      print('Erreur métriques comportement: $e');
      return [];
    }
  }
  
  /// Calculer le score d'engagement
  static double _calculateEngagementScore(List<Map<String, dynamic>> behaviorMetrics) {
    double score = 0.0;
    
    for (final metric in behaviorMetrics) {
      final metricName = metric['metric'] as String;
      final value = metric['value'] as double;
      
      switch (metricName) {
        case 'session_duration':
          score += (value / 300.0) * 0.3; // 30% pour 5min session
          break;
        case 'page_views':
          score += (value / 20.0) * 0.2; // 20% pour 20 pages
          break;
        case 'clicks':
          score += (value / 50.0) * 0.3; // 30% pour 50 clicks
          break;
        case 'scroll_depth':
          score += (value / 5.0) * 0.1; // 10% pour 5 scrolls
          break;
        case 'time_on_page':
          score += (value / 180.0) * 0.1; // 10% pour 3min
          break;
      }
    }
    
    return score.clamp(0.0, 1.0);
  }
  
  /// Calculer l'amélioration de performance
  static double _calculatePerformanceImprovement(List<Map<String, dynamic>> behaviorMetrics) {
    // Simulation basée sur les métriques actuelles vs baseline
    return 0.15; // 15% d'amélioration simulée
  }
  
  /// Calculer la précision des prédictions
  static double _calculatePredictionAccuracy(String userId) async {
    try {
      final predictions = await getUserPredictions(userId);
      if (predictions.isEmpty) return 0.0;
      
      int correct = 0;
      for (final prediction in predictions) {
        if (prediction.actualValue != null) {
          final error = (prediction.actualValue! - prediction.predictionValue).abs();
          if (error < 0.1) correct++;
        }
      }
      
      return correct / predictions.length;
    } catch (e) {
      print('Erreur calcul précision prédiction: $e');
      return 0.0;
    }
  }
  
  /// Calculer le score de confiance
  static double _calculateConfidence(List<double> output) {
    if (output.isEmpty) return 0.0;
    
    // Utiliser softmax pour calculer la confiance
    final maxVal = output.reduce((a, b) => a > b ? a : b);
    final expSum = output.map((val) => math.exp(val)).reduce((a, b) => a + b);
    
    return maxVal / expSum;
  }
  
  /// Obtenir l'index du score le plus élevé
  static int _getTopScoreIndex(List<double> scores) {
    if (scores.isEmpty) return 0;
    
    int maxIndex = 0;
    for (int i = 1; i < scores.length; i++) {
      if (scores[i] > scores[maxIndex]) {
        maxIndex = i;
      }
    }
    
    return maxIndex;
  }
  
  /// Classifier le type d'anomalie
  static String _classifyAnomalyType(double anomalyScore) {
    if (anomalyScore < 0.3) return 'low';
    if (anomalyScore < 0.6) return 'medium';
    if (anomalyScore < 0.8) return 'high';
    return 'critical';
  }
  
  /// Classifier la sévérité de l'anomalie
  static String _classifySeverity(double anomalyScore) {
    if (anomalyScore < 0.3) return 'low';
    if (anomalyScore < 0.6) return 'medium';
    if (anomalyScore < 0.8) return 'high';
    return 'critical';
  }
  
  /// Calculer un histogramme simplifié
  static List<double> _calculateHistogram(Uint8List pixelData) {
    final histogram = List<double>.filled(256, 0.0);
    
    for (final pixel in pixelData) {
      histogram[pixel]++;
    }
    
    // Normaliser
    final total = pixelData.length;
    for (int i = 0; i < histogram.length; i++) {
      histogram[i] = histogram[i] / total;
    }
    
    return histogram;
  }
  
  /// Nettoyer le cache ML
  static Future<void> clearMLCache() async {
    try {
      final keys = _predictions.keys.toList();
      for (final key in keys) {
        await CacheService.remove(key);
      }
      _predictions.clear();
      
      print('Cache ML vidé');
    } catch (e) {
      print('Erreur vidange cache ML: $e');
    }
  }
  
  /// Obtenir les statistiques du service ML
  static Future<MLServiceStats> getStats() async {
    try {
      final cacheStats = await CacheService.getStats();
      
      return MLServiceStats(
        modelsLoaded: _models.length,
        predictionsCount: _predictions.values.fold(0, (sum, list) => sum + list.length),
        cacheSize: cacheStats.totalSize,
        cacheHitRate: cacheStats.hitRate,
        modelsAvailable: _models.keys.toList(),
        lastUpdated: DateTime.now(),
      );
    } catch (e) {
      print('Erreur statistiques ML: $e');
      rethrow;
    }
  }
}

/// Prédiction ML
class MLPrediction {
  final String id;
  final String userId;
  final String modelId;
  final String predictionType;
  final double predictionValue;
  final double confidenceScore;
  final List<double> inputData;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  final double? actualValue;
  
  MLPrediction({
    required this.id,
    required this.userId,
    required this.modelId,
    required this.predictionType,
    required this.predictionValue,
    required this.confidenceScore,
    required this.inputData,
    required this.metadata,
    required this.createdAt,
    this.actualValue,
  });
  
  factory MLPrediction.fromJson(Map<String, dynamic> json) {
    return MLPrediction(
      id: json['id'],
      userId: json['user_id'],
      modelId: json['model_id'],
      predictionType: json['prediction_type'],
      predictionValue: json['prediction_value']?.toDouble() ?? 0.0,
      confidenceScore: json['confidence_score']?.toDouble() ?? 0.0,
      inputData: List<double>.from(jsonDecode(json['input_data'] ?? '[]')),
      metadata: jsonDecode(json['metadata'] ?? '{}'),
      createdAt: DateTime.parse(json['created_at']),
      actualValue: json['actual_value']?.toDouble(),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'model_id': modelId,
      'prediction_type': predictionType,
      'prediction_value': predictionValue,
      'confidence_score': confidenceScore,
      'input_data': jsonEncode(inputData),
      'metadata': jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
      'actual_value': actualValue,
    };
  }
}

/// Recommandation ML
class MLRecommendation {
  final String id;
  final String userId;
  final String itemId;
  final String itemType;
  final String itemTitle;
  final double score;
  final double confidence;
  final List<double> features;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  
  MLRecommendation({
    required this.id,
    required this.userId,
    required this.itemId,
    required this.itemType,
    required this.itemTitle,
    required this.score,
    required this.confidence,
    required this.features,
    required this.metadata,
    required this.createdAt,
  });
  
  factory MLRecommendation.fromJson(Map<String, dynamic> json) {
    return MLRecommendation(
      id: json['id'],
      userId: json['user_id'],
      itemId: json['item_id'],
      itemType: json['item_type'],
      itemTitle: json['item_title'],
      score: json['recommendation_score']?.toDouble() ?? 0.0,
      confidence: json['confidence']?.toDouble() ?? 0.0,
      features: List<double>.from(jsonDecode(json['features'] ?? '[]')),
      metadata: jsonDecode(json['metadata'] ?? '{}'),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'item_id': itemId,
      'item_type': itemType,
      'item_title': itemTitle,
      'recommendation_score': score,
      'confidence': confidence,
      'features': jsonEncode(features),
      'metadata': jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Anomalie ML
class MLAnomaly {
  final String id;
  final String userId;
  final String anomalyType;
  final String severity;
  final double anomalyScore;
  final double threshold;
  final double confidence;
  final List<double> behaviorMetrics;
  final Map<String, dynamic> metadata;
  final bool isAnomaly;
  final DateTime detectedAt;
  final DateTime? resolvedAt;
  final String? resolutionAction;
  final bool isResolved;
  
  MLAnomaly({
    required this.id,
    required this.userId,
    required this.anomalyType,
    required this.severity,
    required this.anomalyScore,
    required this.threshold,
    required this.confidence,
    required this.behaviorMetrics,
    required this.metadata,
    required this.isAnomaly,
    required this.detectedAt,
    this.resolvedAt,
    this.resolutionAction,
    this.isResolved,
  });
  
  factory MLAnomaly.fromJson(Map<String, dynamic> json) {
    return MLAnomaly(
      id: json['id'],
      userId: json['user_id'],
      anomalyType: json['anomaly_type'],
      severity: json['severity'],
      anomalyScore: json['anomaly_score']?.toDouble() ?? 0.0,
      threshold: json['threshold']?.toDouble() ?? 0.0,
      confidence: json['confidence']?.toDouble() ?? 0.0,
      behaviorMetrics: List<double>.from(jsonDecode(json['behavior_metrics'] ?? '[]')),
      metadata: jsonDecode(json['metadata'] ?? '{}'),
      isAnomaly: json['is_anomaly'] ?? false,
      detectedAt: DateTime.parse(json['detected_at']),
      resolvedAt: json['resolved_at']'] != null ? DateTime.parse(json['resolved_at']) : null,
      resolutionAction: json['resolution_action'],
      isResolved: json['is_resolved'] ?? false,
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'anomaly_type': anomalyType,
      'severity': severity,
      'anomaly_score': anomalyScore,
      'threshold': threshold,
      'confidence': confidence,
      'behavior_metrics': jsonEncode(behaviorMetrics),
      'metadata': jsonEncode(metadata),
      'is_anomaly': isAnomaly,
      'detected_at': detectedAt.toIso8601String(),
      'resolved_at': resolvedAt?.toIso8601String(),
      'resolution_action': resolutionAction,
      'is_resolved': isResolved,
    };
  }
}

/// Analyse d'image ML
class MLImageAnalysis {
  final String id;
  final String imagePath;
  final List<String> detectedLabels;
  final List<double> confidenceScores;
  final Map<String, dynamic> metadata;
  final DateTime createdAt;
  
  MLImageAnalysis({
    required this.id,
    required this.imagePath,
    required this.detectedLabels,
    required this.confidenceScores,
    required this.metadata,
    required this.createdAt,
  });
  
  factory MLImageAnalysis.fromJson(Map<String, dynamic> json) {
    return MLImageAnalysis(
      id: json['id'],
      imagePath: json['image_path'],
      detectedLabels: List<String>.from(jsonDecode(json['detected_labels'] ?? '[]')),
      confidenceScores: List<double>.from(jsonDecode(json['confidence_scores'] ?? '[]')),
      metadata: jsonDecode(json['metadata'] ?? '{}'),
      createdAt: DateTime.parse(json['created_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'image_path': imagePath,
      'detected_labels': jsonEncode(detectedLabels),
      'confidence_scores': jsonEncode(confidenceScores),
      'metadata': jsonEncode(metadata),
      'created_at': createdAt.toIso8601String(),
    };
  }
}

/// Insight IA
class AIInsight {
  final String id;
  final String insightType;
  final String insightCategory;
  final String title;
  final String description;
  final double confidence;
  final double impactScore;
  final Map<String, dynamic> dataEvidence;
  final bool actionable;
  final bool actionTaken;
  final String? actionResult;
  final DateTime createdAt;
  final DateTime expiresAt;
  
  AIInsight({
    required this.id,
    required this.insightType,
    required this.insightCategory,
    required this.title,
    required this.description,
    required this.confidence,
    required this. {
      this.actionTaken = actionTaken;
      this.actionResult = actionResult;
    }
    required this.createdAt,
    required this.expiresAt,
  });
  
  factory AIInsight.fromJson(Map<String, dynamic> json) {
    return AIInsight(
      id: json['id'],
      insightType: json['insight_type'],
      insightCategory: json['insight_category'],
      title: json['title'],
      description: json['description'],
      confidence: json['confidence']?.toDouble() ?? 0.0,
      impactScore: json['impact_score']?.toDouble() ?? 0.0,
      dataEvidence: jsonDecode(json['data_evidence'] ?? '{}'),
      actionable: json['actionable'] ?? false,
      actionTaken: json['action_taken'] ?? false,
      actionResult: json['action_result'],
      createdAt: DateTime.parse(json['created_at']),
      expiresAt: DateTime.parse(json['expires_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'insight_type': insightType,
      'insight_category': insightCategory,
      'title': title,
      'description': description,
      'confidence': confidence,
      'impact_score': impactScore,
      'data_evidence': jsonEncode(dataEvidence),
      'actionable': actionable,
      'action_taken': actionTaken,
      'action_result': actionResult,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
    };
  }
}

/// Métriques de performance ML
class MLPerformanceMetrics {
  final String userId;
  final double modelAccuracy;
  final double modelPrecision;
  final double modelRecall;
  final double modelF1Score;
  final double predictionAccuracy;
  final double userEngagementScore;
  final double performanceImprovement;
  final double cacheHitRate;
  final double modelInferenceTime;
  final DateTime createdAt;
  
  MLPerformanceMetrics({
    required this.userId,
    required this.modelAccuracy,
    required this.modelPrecision,
    required this.modelRecall,
    required this.modelF1Score,
    required this.predictionAccuracy,
    required this.userEngagementScore,
    required this.performanceImprovement,
    required this.cacheHitRate,
    required this.modelInferenceTime,
    required this.createdAt,
  });
}

/// Statistiques du service ML
class MLServiceStats {
  final int modelsLoaded;
  final int predictionsCount;
  final int cacheSize;
  final double cacheHitRate;
  final List<String> modelsAvailable;
  final DateTime lastUpdated;
  
  MLServiceStats({
    required this.modelsLoaded,
    required this.predictionsCount,
    required this.cacheSize,
    required this.cacheHitRate,
    required this.modelsAvailable,
    required this.lastUpdated,
  });
}
