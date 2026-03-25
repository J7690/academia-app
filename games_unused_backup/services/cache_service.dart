import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:hive/hive.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

/// Service pour la gestion du cache intelligent mobile first
class CacheService {
  static late Box _cacheBox;
  static late SharedPreferences _prefs;
  static final Map<String, CacheItem> _memoryCache = {};
  static final Uuid _uuid = Uuid();
  static const String _cacheVersionKey = 'cache_version';
  static const int _maxCacheSize = 100 * 1024 * 1024; // 100MB
  static const Duration _defaultExpiration = Duration(hours: 1);
  
  /// Initialiser le service de cache
  static Future<void> initialize() async {
    try {
      // Initialiser Hive
      final appDocumentDir = await getApplicationDocumentsDirectory();
      Hive.init(appDocumentDir.path);
      
      // Ouvrir la box de cache
      _cacheBox = await Hive.openBox('app_cache');
      
      // Initialiser SharedPreferences
      _prefs = await SharedPreferences.getInstance();
      
      // Vérifier la version du cache
      await _checkCacheVersion();
      
      // Nettoyer le cache expiré
      await _cleanupExpiredCache();
      
      print('CacheService initialisé avec succès');
    } catch (e) {
      print('Erreur initialisation CacheService: $e');
      rethrow;
    }
  }
  
  /// Stocker une valeur dans le cache
  static Future<void> set(
    String key,
    dynamic value, {
    CacheType type = CacheType.userData,
    Duration? expiration,
    bool encrypt = false,
  }) async {
    try {
      final expiresAt = expiration ?? _defaultExpiration;
      final cacheItem = CacheItem(
        id: _uuid.v4(),
        userId: encrypt ? 'encrypted' : null,
        key: key,
        value: value,
        type: type,
        expiresAt: DateTime.now().add(expiresAt),
        sizeBytes: _calculateSize(value),
        accessCount: 0,
        lastAccessedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Stocker dans Hive (persistant)
      await _cacheBox.put(key, cacheItem.toJson());
      
      // Stocker en mémoire (accès rapide)
      _memoryCache[key] = cacheItem;
      
      // Nettoyer si nécessaire
      await _checkCacheSize();
    } catch (e) {
      print('Erreur stockage cache: $e');
    }
  }
  
  /// Récupérer une valeur du cache
  static Future<T?> get<T>(
    String key, {
    T? defaultValue,
    CacheType? type,
  }) async {
    try {
      // Vérifier d'abord en mémoire
      final memoryItem = _memoryCache[key];
      if (memoryItem != null) {
        if (memoryItem.isExpired) {
          await remove(key);
          return defaultValue;
        }
        
        // Mettre à jour les stats d'accès
        memoryItem.accessCount++;
        memoryItem.lastAccessedAt = DateTime.now();
        _memoryCache[key] = memoryItem;
        
        return memoryItem.value as T?;
      }
      
      // Vérifier dans Hive (persistant)
      final hiveItem = _cacheBox.get(key);
      if (hiveItem != null) {
        final cacheItem = CacheItem.fromJson(hiveItem);
        
        if (cacheItem.isExpired) {
          await remove(key);
          return defaultValue;
        }
        
        // Mettre à jour les stats d'accès
        cacheItem.accessCount++;
        cacheItem.lastAccessedAt = DateTime.now();
        await _cacheBox.put(key, cacheItem.toJson());
        
        // Mettre en mémoire pour accès rapide
        _memoryCache[key] = cacheItem;
        
        return cacheItem.value as T?;
      }
      
      return defaultValue;
    } catch (e) {
      print('Erreur récupération cache: $e');
      return defaultValue;
    }
  }
  
  /// Supprimer une valeur du cache
  static Future<void> remove(String key) async {
    try {
      // Supprimer de la mémoire
      _memoryCache.remove(key);
      
      // Supprimer de Hive
      await _cacheBox.delete(key);
    } catch (e) {
      print('Erreur suppression cache: $e');
    }
  }
  
  /// Vider le cache
  static Future<void> clear() async {
    try {
      // Vider la mémoire
      _memoryCache.clear();
      
      // Vider Hive
      await _cacheBox.clear();
      
      // Vider SharedPreferences
      await _prefs.clear();
      
      print('Cache vidé');
    } catch (e) {
      print('Erreur vidange cache: $e');
    }
  }
  
  /// Vider le cache expiré
  static Future<void> cleanupExpired() async {
    await _cleanupExpiredCache();
  }
  
  /// Obtenir les statistiques du cache
  static Future<CacheStats> getStats() async {
    try {
      final totalItems = _cacheBox.length;
      final memoryItems = _memoryCache.length;
      
      int totalSize = 0;
      int expiredCount = 0;
      
      // Calculer la taille totale et les items expirés
      for (final key in _cacheBox.keys) {
        final item = CacheItem.fromJson(_cacheBox.get(key));
        totalSize += item.sizeBytes;
        if (item.isExpired) {
          expiredCount++;
        }
      }
      
      // Obtenir les items les plus utilisés
      final mostAccessed = <CacheItem>[];
      for (final item in _memoryCache.values) {
        mostAccessed.add(item);
      }
      mostAccessed.sort((a, b) => b.accessCount.compareTo(a.accessCount));
      
      return CacheStats(
        totalItems: totalItems,
        memoryItems: memoryItems,
        totalSize: totalSize,
        expiredCount: expiredCount,
        hitRate: _calculateHitRate(),
        mostAccessed: mostAccessed.take(10),
      );
    } catch (e) {
      print('Erreur statistiques cache: $e');
      rethrow;
    }
  }
  
  /// Précharger des données
  static Future<void> preload(List<String> keys) async {
    try {
      final futures = keys.map((key) => get(key)).toList();
      await Future.wait(futures);
      print('Préchargement de ${keys.length} items terminé');
    } catch (e) {
      print('Erreur préchargement: $e');
    }
  }
  
  /// Mettre en cache une image
  static Future<void> cacheImage(
    String url,
    Uint8List imageData, {
    Duration? expiration,
  }) async {
    await set(
      url,
      imageData,
      type: CacheType.image,
      expiration: expiration ?? const Duration(days: 7),
    );
  }
  
  /// Récupérer une image du cache
  static Future<Uint8List?> getImage(String url) async {
    return get<Uint8List>(url, type: CacheType.image);
  }
  
  /// Mettre en cache une réponse API
  static Future<void> cacheApiResponse(
    String url,
    Map<String, dynamic> response, {
    Duration? expiration,
  }) async {
      await set(
        url,
        response,
        type: CacheType.apiResponse,
        expiration: expiration ?? const Duration(minutes: 15),
      );
    }
  
  /// Récupérer une réponse API du cache
  static Future<Map<String, dynamic>?> getApiResponse(String url) async {
    return get<Map<String, dynamic>>(url, type: CacheType.apiResponse);
  }
  
  /// Mettre en cache des données utilisateur
  static Future<void> cacheUserData(
    String userId,
    Map<String, dynamic> data, {
    Duration? expiration,
  }) async {
      await set(
        'user_data_$userId',
        data,
        type: CacheType.userData,
        expiration: expiration ?? const Duration(hours: 24),
      );
    }
  
  /// Récupérer des données utilisateur du cache
  static Future<Map<String, dynamic>?> getUserData(String userId) async {
    return get<Map<String, dynamic>>('user_data_$userId', type: CacheType.userData);
  }
  
  /// Vérifier si une clé existe dans le cache
  static bool contains(String key) {
    return _memoryCache.containsKey(key) || _cacheBox.containsKey(key);
  }
  
  /// Obtenir la taille actuelle du cache
  static int getCacheSize() {
    int size = 0;
    for (final item in _memoryCache.values) {
      size += item.sizeBytes;
    }
    return size;
  }
  
  /// Obtenir le nombre d'items dans le cache
  static int getCacheCount() {
    return _memoryCache.length;
  }
  
  /// Méthodes privées
  
  static Future<void> _checkCacheVersion() async {
    final currentVersion = 1;
    final savedVersion = _prefs.getInt(_cacheVersionKey);
    
    if (savedVersion != currentVersion) {
      // La version a changé, vider le cache
      await clear();
      await _prefs.setInt(_cacheVersionKey, currentVersion);
      print('Cache version mise à jour: $currentVersion');
    }
  }
  
  static Future<void> _cleanupExpiredCache() async {
    final keysToDelete = <String>[];
    
    // Vérifier les items en mémoire
    for (final entry in _memoryCache.entries) {
      if (entry.value.isExpired) {
        keysToDelete.add(entry.key);
      }
    }
    
    // Vérifier les items dans Hive
    for (final key in _cacheBox.keys) {
      final item = CacheItem.fromJson(_cacheBox.get(key));
      if (item.isExpired) {
        keysToDelete.add(key);
      }
    }
    
    // Supprimer les items expirés
    for (final key in keysToDelete) {
      await remove(key);
    }
    
    if (keysToDelete.isNotEmpty) {
      print('Nettoyé ${keysToDelete.length} items expirés');
    }
  }
  
  static Future<void> _checkCacheSize() async {
    final currentSize = getCacheSize();
    
    if (currentSize > _maxCacheSize) {
      // Trier par dernier accès et supprimer les plus anciens
      final sortedItems = _memoryCache.values.toList()
        ..sort((a, b) => a.lastAccessedAt.compareTo(b.lastAccessedAt));
      
      int sizeToFree = currentSize - _maxCacheSize;
      int itemsToRemove = 0;
      
      while (sizeToFree > 0 && itemsToRemove < sortedItems.length) {
        final item = sortedItems[itemsToRemove];
        await remove(item.key);
        sizeToFree -= item.sizeBytes;
        itemsToRemove++;
      }
      
      print('Nettoyé $itemsToRemove items pour libérer de l\'espace');
    }
  }
  
  static int _calculateSize(dynamic value) {
    if (value is String) {
      return (value as String).length;
    } else if (value is Map) {
      return jsonEncode(value).length;
    } else if (value is List) {
      return jsonEncode(value).length;
    } else if (value is Uint8List) {
      return (value as Uint8List).length;
    } else {
      return 0;
    }
  }
  
  static double _calculateHitRate() {
    // Calculer le taux de hit basé sur les accès
    int totalAccess = 0;
    int hits = 0;
    
    for (final item in _memoryCache.values) {
      totalAccess += item.accessCount;
      if (item.accessCount > 0) hits++;
    }
    
    return totalAccess > 0 ? (hits / totalAccess) * 100 : 0.0;
  }
}

/// Item de cache
class CacheItem {
  final String id;
  final String? userId;
  final String key;
  final dynamic value;
  final CacheType type;
  final DateTime expiresAt;
  final int sizeBytes;
  int accessCount;
  DateTime lastAccessedAt;
  final DateTime createdAt;
  DateTime updatedAt;
  
  CacheItem({
    required this.id,
    this.userId,
    required this.key,
    required this.value,
    required this.type,
    required this.expiresAt,
    required this.sizeBytes,
    required this.accessCount,
    required this.lastAccessedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory CacheItem.fromJson(Map<String, dynamic> json) {
    return CacheItem(
      id: json['id'],
      userId: json['user_id'],
      key: json['cache_key'],
      value: jsonDecode(json['cache_value']),
      type: CacheType.values.firstWhere(
        (type) => type.toString() == 'CacheType.${json['cache_type']}',
        orElse: () => CacheType.userData,
      ),
      expiresAt: DateTime.parse(json['expires_at']),
      sizeBytes: json['size_bytes'] ?? 0,
      accessCount: json['access_count'] ?? 0,
      lastAccessedAt: DateTime.parse(json['last_accessed_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'cache_key': key,
      'cache_value': jsonEncode(value),
      'cache_type': type.toString(),
      'expires_at': expiresAt.toIso8601String(),
      'size_bytes': sizeBytes,
      'access_count': accessCount,
      'last_accessed_at': lastAccessedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
  
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt);
  }
}

/// Types de cache
enum CacheType {
  userData,
  apiResponse,
  image,
  video,
  config,
  other,
}

/// Statistiques du cache
class CacheStats {
  final int totalItems;
  final int memoryItems;
  final int totalSize;
  final int expiredCount;
  final double hitRate;
  final List<CacheItem> mostAccessed;
  
  CacheStats({
    required this.totalItems,
    required this.memoryItems,
    required this.totalSize,
    required this.expiredCount,
    required this.hitRate,
    required this.mostAccessed,
  });
}
