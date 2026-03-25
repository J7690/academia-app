import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'tiktok_sharing_service.dart';
import 'post_live_feed_service.dart';

/// Service pour TikTok Creator Fund et revenus créateurs
class TikTokCreatorFundService {
  static const String _tiktokCreatorApiBaseUrl = 'https://open-api.tiktok.com';
  static final Map<String, CreatorFundProfile> _profiles = {};
  static final Uuid _uuid = Uuid();
  
  /// Initialiser le profil Creator Fund
  static Future<CreatorFundProfile> initializeCreatorFund({
    required String tiktokCreatorId,
    required String payoutMethod,
    Map<String, dynamic>? payoutInfo,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');
      
      // Vérifier si le profil existe déjà
      final existingProfile = await getCreatorFundProfile(userId);
      if (existingProfile != null) {
        return existingProfile;
      }
      
      // Créer le profil
      final profile = CreatorFundProfile(
        id: _uuid.v4(),
        userId: userId,
        tiktokCreatorId: tiktokCreatorId,
        fundLevel: CreatorFundLevel.bronze,
        monthlyViews: 0,
        monthlyLikes: 0,
        monthlyShares: 0,
        monthlyEngagementRate: 0.0,
        monthlyRevenue: 0.0,
        totalRevenue: 0.0,
        payoutMethod: payoutMethod,
        payoutInfo: payoutInfo ?? {},
        isEligible: false,
        isActive: true,
        lastCalculatedAt: DateTime.now(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Sauvegarder dans la base
      await Supabase.instance.client
          .from('tiktok_creator_fund')
          .insert(profile.toJson());
      
      _profiles[userId] = profile;
      return profile;
    } catch (e) {
      print('Erreur initialisation Creator Fund: $e');
      rethrow;
    }
  }
  
  /// Obtenir le profil Creator Fund
  static Future<CreatorFundProfile?> getCreatorFundProfile(String userId) async {
    try {
      if (_profiles.containsKey(userId)) {
        return _profiles[userId];
      }
      
      final result = await Supabase.instance.client
          .from('tiktok_creator_fund')
          .select()
          .eq('user_id', userId)
          .maybeSingle();
      
      if (result != null) {
        final profile = CreatorFundProfile.fromJson(result);
        _profiles[userId] = profile;
        return profile;
      }
      return null;
    } catch (e) {
      print('Erreur récupération profil Creator Fund: $e');
      return null;
    }
  }
  
  /// Mettre à jour les métriques mensuelles
  static Future<void> updateMonthlyMetrics({
    required String userId,
    int? views,
    int? likes,
    int? shares,
  }) async {
    try {
      final profile = await getCreatorFundProfile(userId);
      if (profile == null) throw Exception('Profil non trouvé');
      
      // Mettre à jour les métriques
      if (views != null) profile.monthlyViews = views;
      if (likes != null) profile.monthlyLikes = likes;
      if (shares != null) profile.monthlyShares = shares;
      
      // Calculer l'engagement rate
      if (profile.monthlyViews > 0) {
        profile.monthlyEngagementRate = ((profile.monthlyLikes + profile.monthlyShares) / profile.monthlyViews) * 100;
      }
      
      // Calculer le niveau de fund
      profile.fundLevel = _calculateFundLevel(profile);
      
      // Calculer le revenu mensuel
      profile.monthlyRevenue = _calculateMonthlyRevenue(profile);
      
      // Mettre à jour l'éligibilité
      profile.isEligible = _checkEligibility(profile);
      
      // Mettre à jour dans la base
      await Supabase.instance.client
          .from('tiktok_creator_fund')
          .update({
            'monthly_views': profile.monthlyViews,
            'monthly_likes': profile.monthlyLikes,
            'monthly_shares': profile.monthlyShares,
            'monthly_engagement_rate': profile.monthlyEngagementRate,
            'fund_level': profile.fundLevel.toString(),
            'monthly_revenue': profile.monthlyRevenue,
            'total_revenue': profile.totalRevenue,
            'is_eligible': profile.isEligible,
            'last_calculated_at': DateTime.now().toIso8601String(),
          })
          .eq('user_id', userId);
      
      _profiles[userId] = profile;
    } catch (e) {
      print('Erreur mise à jour métriques: $e');
      rethrow;
    }
  }
  
  /// Calculer le niveau de fund
  static CreatorFundLevel _calculateFundLevel(CreatorFundProfile profile) {
    final engagementRate = profile.monthlyEngagementRate;
    final views = profile.monthlyViews;
    
    if (engagementRate >= 10.0 && views >= 1000000) {
      return CreatorFundLevel.platinum;
    } else if (engagementRate >= 7.0 && views >= 500000) {
      return CreatorFundLevel.gold;
    } else if (engagementRate >= 5.0 && views >= 100000) {
      return CreatorFundLevel.silver;
    } else {
      return CreatorFundLevel.bronze;
    }
  }
  
  /// Calculer le revenu mensuel
  static double _calculateMonthlyRevenue(CreatorFundProfile profile) {
    double baseRevenue = 0.0;
    
    switch (profile.fundLevel) {
      case CreatorFundLevel.bronze:
        baseRevenue = 100.0; // 100$ minimum
        break;
      case CreatorFundLevel.silver:
        baseRevenue = 500.0; // 500$ minimum
        break;
      case CreatorFundLevel.gold:
        baseRevenue = 2000.0; // 2000$ minimum
        break;
      case CreatorFundLevel.platinum:
        baseRevenue = 5000.0; // 5000$ minimum
        break;
    }
    
    // Bonus basé sur l'engagement
    final engagementBonus = profile.monthlyEngagementRate * 10.0; // 10$ par % d'engagement
    
    // Bonus basé sur les vues
    final viewsBonus = (profile.monthlyViews / 10000) * 5.0; // 5$ par 10k vues
    
    return baseRevenue + engagementBonus + viewsBonus;
  }
  
  /// Vérifier l'éligibilité
  static bool _checkEligibility(CreatorFundProfile profile) {
    return profile.monthlyViews >= 10000 && // Minimum 10k vues
           profile.monthlyEngagementRate >= 2.0 && // Minimum 2% engagement
           profile.monthlyLikes >= 1000 && // Minimum 1k likes
           profile.isActive; // Profil actif
  }
  
  /// Demander un paiement
  static Future<String> requestPayout(String userId) async {
    try {
      final profile = await getCreatorFundProfile(userId);
      if (profile == null) throw Exception('Profil non trouvé');
      
      if (!profile.isEligible) {
        throw Exception('Non éligible au paiement');
      }
      
      if (profile.monthlyRevenue <= 0) {
        throw Exception('Aucun revenu à payer');
      }
      
      // Créer une demande de paiement
      final payoutId = _uuid.v4();
      
      await Supabase.instance.client
          .from('revenue_analytics')
          .insert({
            'id': payoutId,
            'user_id': userId,
            'revenue_source': 'tiktok_fund',
            'revenue_type': 'fixed',
            'amount': profile.monthlyRevenue,
            'currency': 'USD',
            'reference_id': profile.id,
            'reference_type': 'creator_fund',
            'period_start': DateTime.now().subtract(const Duration(days: 30)).toIso8601String(),
            'period_end': DateTime.now().toIso8601String(),
            'status': 'pending',
          });
      
      return payoutId;
    } catch (e) {
      print('Erreur demande paiement: $e');
      rethrow;
    }
  }
  
  /// Obtenir les revenus totaux
  static Future<double> getTotalRevenue(String userId) async {
    try {
      final profile = await getCreatorFundProfile(userId);
      if (profile == null) return 0.0;
      
      return profile.totalRevenue;
    } catch (e) {
      print('Erreur revenus totaux: $e');
      return 0.0;
    }
  }
  
  /// Obtenir l'historique des paiements
  static Future<List<RevenueRecord>> getPayoutHistory(String userId) async {
    try {
      final result = await Supabase.instance.client
          .from('revenue_analytics')
          .select()
          .eq('user_id', userId)
          .eq('revenue_source', 'tiktok_fund')
          .order('period_end', ascending: false);
      
      return result.map((json) => RevenueRecord.fromJson(json)).toList();
    } catch (e) {
      print('Erreur historique paiements: $e');
      return [];
    }
  }
  
  /// Synchroniser avec TikTok API
  static Future<void> syncWithTikTokAPI(String userId) async {
    try {
      final profile = await getCreatorFundProfile(userId);
      if (profile == null) throw Exception('Profil non trouvé');
      
      // Obtenir les tokens TikTok
      final tokens = await TikTokSharingService._getTikTokTokens();
      if (tokens == null) throw Exception('Non connecté à TikTok');
      
      // Récupérer les statistiques TikTok
      final response = await http.get(
        Uri.parse('$_tiktokCreatorApiBaseUrl/creator/stats/'),
        headers: {
          'Authorization': 'Bearer ${tokens['accessToken']!}',
        },
      );
      
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final stats = data['stats'];
        
        // Mettre à jour les métriques
        await updateMonthlyMetrics(
          userId: userId,
          views: stats['views'],
          likes: stats['likes'],
          shares: stats['shares'],
        );
      } else {
        throw Exception('Erreur API TikTok: ${response.body}');
      }
    } catch (e) {
      print('Erreur synchronisation TikTok: $e');
      rethrow;
    }
  }
  
  /// Obtenir les statistiques détaillées
  static Future<CreatorStats> getDetailedStats(String userId) async {
    try {
      final profile = await getCreatorFundProfile(userId);
      if (profile == null) throw Exception('Profil non trouvé');
      
      // Obtenir les partages TikTok
      final tiktokShares = await TikTokSharingService.getUserTikTokShares();
      
      // Obtenir les Post-Live Feeds
      final postLiveFeeds = await PostLiveFeedService.getAllPostLiveFeeds();
      
      // Calculer les statistiques
      final totalViews = profile.monthlyViews;
      final totalLikes = profile.monthlyLikes;
      final totalShares = profile.monthlyShares;
      final totalVideos = tiktokShares.length;
      final totalFeeds = postLiveFeeds.length;
      
      return CreatorStats(
        totalViews: totalViews,
        totalLikes: totalLikes,
        totalShares: totalShares,
        totalVideos: totalVideos,
        totalFeeds: totalFeeds,
        engagementRate: profile.monthlyEngagementRate,
        monthlyRevenue: profile.monthlyRevenue,
        totalRevenue: profile.totalRevenue,
        fundLevel: profile.fundLevel,
        isEligible: profile.isEligible,
      );
    } catch (e) {
      print('Erreur statistiques détaillées: $e');
      rethrow;
    }
  }
  
  /// Mettre à jour les informations de paiement
  static Future<void> updatePayoutInfo(String userId, String payoutMethod, Map<String, dynamic> payoutInfo) async {
    try {
      await Supabase.instance.client
          .from('tiktok_creator_fund')
          .update({
            'payout_method': payoutMethod,
            'payout_info': jsonEncode(payoutInfo),
          })
          .eq('user_id', userId);
      
      // Mettre à jour le profil en cache
      final profile = _profiles[userId];
      if (profile != null) {
        profile.payoutMethod = payoutMethod;
        profile.payoutInfo = payoutInfo;
      }
    } catch (e) {
      print('Erreur mise à jour infos paiement: $e');
      rethrow;
    }
  }
  
  /// Obtenir les créateurs tendance
  static Future<List<CreatorFundProfile>> getTrendingCreators({int limit = 10}) async {
    try {
      final result = await Supabase.instance.client
          .from('tiktok_creator_fund')
          .select()
          .eq('is_eligible', true)
          .eq('is_active', true)
          .order('monthly_revenue', ascending: false)
          .order('monthly_engagement_rate', ascending: false)
          .limit(limit);
      
      return result.map((json) => CreatorFundProfile.fromJson(json)).toList();
    } catch (e) {
      print('Erreur créateurs tendance: $e');
      return [];
    }
  }
}

/// Profil Creator Fund
class CreatorFundProfile {
  final String id;
  final String userId;
  final String tiktokCreatorId;
  CreatorFundLevel fundLevel;
  int monthlyViews;
  int monthlyLikes;
  int monthlyShares;
  double monthlyEngagementRate;
  double monthlyRevenue;
  double totalRevenue;
  String payoutMethod;
  Map<String, dynamic> payoutInfo;
  bool isEligible;
  bool isActive;
  DateTime lastCalculatedAt;
  DateTime createdAt;
  DateTime updatedAt;
  
  CreatorFundProfile({
    required this.id,
    required this.userId,
    required this.tiktokCreatorId,
    required this.fundLevel,
    required this.monthlyViews,
    required this.monthlyLikes,
    required this.monthlyShares,
    required this.monthlyEngagementRate,
    required this.monthlyRevenue,
    required this.totalRevenue,
    required this.payoutMethod,
    required this.payoutInfo,
    required this.isEligible,
    required this.isActive,
    required this.lastCalculatedAt,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory CreatorFundProfile.fromJson(Map<String, dynamic> json) {
    return CreatorFundProfile(
      id: json['id'],
      userId: json['user_id'],
      tiktokCreatorId: json['tiktok_creator_id'],
      fundLevel: CreatorFundLevel.values.firstWhere(
        (level) => level.toString() == 'CreatorFundLevel.${json['fund_level']}',
        orElse: () => CreatorFundLevel.bronze,
      ),
      monthlyViews: json['monthly_views'] ?? 0,
      monthlyLikes: json['monthly_likes'] ?? 0,
      monthlyShares: json['monthly_shares'] ?? 0,
      monthlyEngagementRate: json['monthly_engagement_rate']?.toDouble() ?? 0.0,
      monthlyRevenue: json['monthly_revenue']?.toDouble() ?? 0.0,
      totalRevenue: json['total_revenue']?.toDouble() ?? 0.0,
      payoutMethod: json['payout_method'],
      payoutInfo: jsonDecode(json['payout_info'] ?? '{}'),
      isEligible: json['is_eligible'] ?? false,
      isActive: json['is_active'] ?? true,
      lastCalculatedAt: DateTime.parse(json['last_calculated_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'tiktok_creator_id': tiktokCreatorId,
      'fund_level': fundLevel.toString(),
      'monthly_views': monthlyViews,
      'monthly_likes': monthlyLikes,
      'monthly_shares': monthlyShares,
      'monthly_engagement_rate': monthlyEngagementRate,
      'monthly_revenue': monthlyRevenue,
      'total_revenue': totalRevenue,
      'payout_method': payoutMethod,
      'payout_info': jsonEncode(payoutInfo),
      'is_eligible': isEligible,
      'is_active': isActive,
      'last_calculated_at': lastCalculatedAt.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Niveaux de Creator Fund
enum CreatorFundLevel {
  bronze,
  silver,
  gold,
  platinum,
}

/// Enregistrement de revenu
class RevenueRecord {
  final String id;
  final String userId;
  final String revenueSource;
  final String revenueType;
  final double amount;
  final String currency;
  final String referenceId;
  final String referenceType;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String status;
  final DateTime? payoutDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  RevenueRecord({
    required this.id,
    required this.userId,
    required this.revenueSource,
    required this.revenueType,
    required this.amount,
    required this.currency,
    required this.referenceId,
    required this.referenceType,
    required this.periodStart,
    required this.periodEnd,
    required this.status,
    this.payoutDate,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory RevenueRecord.fromJson(Map<String, dynamic> json) {
    return RevenueRecord(
      id: json['id'],
      userId: json['user_id'],
      revenueSource: json['revenue_source'],
      revenueType: json['revenue_type'],
      amount: json['amount']?.toDouble() ?? 0.0,
      currency: json['currency'],
      referenceId: json['reference_id'],
      referenceType: json['reference_type'],
      periodStart: DateTime.parse(json['period_start']),
      periodEnd: DateTime.parse(json['period_end']),
      status: json['status'],
      payoutDate: json['payout_date'] != null ? DateTime.parse(json['payout_date']) : null,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

/// Statistiques créateur
class CreatorStats {
  final int totalViews;
  final int totalLikes;
  final int totalShares;
  final int totalVideos;
  final int totalFeeds;
  final double engagementRate;
  final double monthlyRevenue;
  final double totalRevenue;
  final CreatorFundLevel fundLevel;
  final bool isEligible;
  
  CreatorStats({
    required this.totalViews,
    required this.totalLikes,
    required this.totalShares,
    required this.totalVideos,
    required this.totalFeeds,
    required this.engagementRate,
    required this.monthlyRevenue,
    required this.totalRevenue,
    required this.fundLevel,
    required this.isEligible,
  });
}
