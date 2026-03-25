import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Gestionnaire de Feature Flags pour déploiement progressif
class FeatureFlags {
  // Feature flags principaux
  static bool _bloombergMode = false;
  static bool _liveArena = false;
  static bool _socialSharing = false;
  static bool _economicData = false;
  static bool _adaptiveAI = false;
  static bool _postLiveFeed = false;
  
  // Getters
  static bool get bloombergMode => _bloombergMode;
  static bool get liveArena => _liveArena;
  static bool get socialSharing => _socialSharing;
  static bool get economicData => _economicData;
  static bool get adaptiveAI => _adaptiveAI;
  static bool get postLiveFeed => _postLiveFeed;
  
  // Setters (pour développement et tests)
  static set bloombergMode(bool value) {
    if (kDebugMode) {
      _bloombergMode = value;
    }
  }
  
  static set liveArena(bool value) {
    if (kDebugMode) {
      _liveArena = value;
    }
  }
  
  static set socialSharing(bool value) {
    if (kDebugMode) {
      _socialSharing = value;
    }
  }
  
  static set economicData(bool value) {
    if (kDebugMode) {
      _economicData = value;
    }
  }
  
  static set adaptiveAI(bool value) {
    if (kDebugMode) {
      _adaptiveAI = value;
    }
  }
  
  static set postLiveFeed(bool value) {
    if (kDebugMode) {
      _postLiveFeed = value;
    }
  }
  
  // Activation de toutes les features (pour développement)
  static void enableAllFeatures() {
    if (kDebugMode) {
      _bloombergMode = true;
      _liveArena = true;
      _socialSharing = true;
      _economicData = true;
      _adaptiveAI = true;
      _postLiveFeed = true;
    }
  }
  
  // Désactivation de toutes les features
  static void disableAllFeatures() {
    if (kDebugMode) {
      _bloombergMode = false;
      _liveArena = false;
      _socialSharing = false;
      _economicData = false;
      _adaptiveAI = false;
      _postLiveFeed = false;
    }
  }
  
  // Vérification si une feature est active
  static bool isFeatureEnabled(String featureName) {
    switch (featureName.toLowerCase()) {
      case 'bloomberg':
        return _bloombergMode;
      case 'live_arena':
        return _liveArena;
      case 'social_sharing':
        return _socialSharing;
      case 'economic_data':
        return _economicData;
      case 'adaptive_ai':
        return _adaptiveAI;
      case 'post_live_feed':
        return _postLiveFeed;
      default:
        return false;
    }
  }
  
  // Liste des features actives
  static List<String> getActiveFeatures() {
    final features = <String>[];
    
    if (_bloombergMode) features.add('bloomberg');
    if (_liveArena) features.add('live_arena');
    if (_socialSharing) features.add('social_sharing');
    if (_economicData) features.add('economic_data');
    if (_adaptiveAI) features.add('adaptive_ai');
    if (_postLiveFeed) features.add('post_live_feed');
    
    return features;
  }
  
  // Configuration depuis l'environnement (pour production)
  static void initializeFromEnvironment() {
    // En production, ces valeurs pourraient venir de:
    // - Configuration distante (Firebase Remote Config)
    // - Variables d'environnement
    // - API de configuration
    
    if (!kDebugMode) {
      // Valeurs par défaut pour production
      _bloombergMode = false;  // Sera activé progressivement
      _liveArena = false;
      _socialSharing = false;
      _economicData = false;
      _adaptiveAI = false;
      _postLiveFeed = false;
    }
  }
  
  // Pour le développement - activation rapide
  static void enableFeature(String featureName) {
    if (kDebugMode) {
      switch (featureName.toLowerCase()) {
        case 'bloomberg':
          _bloombergMode = true;
          break;
        case 'live_arena':
          _liveArena = true;
          break;
        case 'social_sharing':
          _socialSharing = true;
          break;
        case 'economic_data':
          _economicData = true;
          break;
        case 'adaptive_ai':
          _adaptiveAI = true;
          break;
        case 'post_live_feed':
          _postLiveFeed = true;
          break;
      }
    }
  }
  
  // Pour le développement - désactivation rapide
  static void disableFeature(String featureName) {
    if (kDebugMode) {
      switch (featureName.toLowerCase()) {
        case 'bloomberg':
          _bloombergMode = false;
          break;
        case 'live_arena':
          _liveArena = false;
          break;
        case 'social_sharing':
          _socialSharing = false;
          break;
        case 'economic_data':
          _economicData = false;
          break;
        case 'adaptive_ai':
          _adaptiveAI = false;
          break;
        case 'post_live_feed':
          _postLiveFeed = false;
          break;
      }
    }
  }
}

/// Widget pour afficher les contrôles de features en développement
class FeatureControls extends StatelessWidget {
  const FeatureControls({Key? key}) : super(key: key);
  
  @override
  Widget build(BuildContext context) {
    if (!kDebugMode) {
      return const SizedBox.shrink();
    }
    
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.8),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🎛️ Feature Controls (Debug Only)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _buildFeatureToggle('Bloomberg Mode', 'bloomberg', FeatureFlags.bloombergMode),
          _buildFeatureToggle('Live Arena', 'live_arena', FeatureFlags.liveArena),
          _buildFeatureToggle('Social Sharing', 'social_sharing', FeatureFlags.socialSharing),
          _buildFeatureToggle('Economic Data', 'economic_data', FeatureFlags.economicData),
          _buildFeatureToggle('Adaptive AI', 'adaptive_ai', FeatureFlags.adaptiveAI),
          _buildFeatureToggle('Post-Live Feed', 'post_live_feed', FeatureFlags.postLiveFeed),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    FeatureFlags.enableAllFeatures();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Enable All'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    FeatureFlags.disableAllFeatures();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Disable All'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  
  Widget _buildFeatureToggle(String label, String feature, bool isEnabled) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 200,
            child: Text(
              label,
              style: TextStyle(
                color: isEnabled ? Colors.green : Colors.white,
                fontSize: 14,
              ),
            ),
          ),
          Switch(
            value: isEnabled,
            onChanged: (value) {
              switch (feature) {
                case 'bloomberg':
                  FeatureFlags.bloombergMode = value;
                  break;
                case 'live_arena':
                  FeatureFlags.liveArena = value;
                  break;
                case 'social_sharing':
                  FeatureFlags.socialSharing = value;
                  break;
                case 'economic_data':
                  FeatureFlags.economicData = value;
                  break;
                case 'adaptive_ai':
                  FeatureFlags.adaptiveAI = value;
                  break;
                case 'post_live_feed':
                  FeatureFlags.postLiveFeed = value;
                  break;
              }
            },
            activeColor: Colors.green,
          ),
        ],
      ),
    );
  }
}
