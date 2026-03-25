import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'tiktok_sharing_service.dart';
import 'post_live_feed_service.dart';

/// Service pour la gestion des sponsorships et partenariats
class SponsorshipService {
  static final Map<String, Sponsorship> _activeSponsorships = {};
  static final Map<String, BrandPartnership> _brands = {};
  static final Uuid _uuid = Uuid();
  
  /// Obtenir les marques partenaires disponibles
  static Future<List<BrandPartnership>> getAvailableBrands({
    String? industry,
    double? minBudget,
    double? maxBudget,
  }) async {
    try {
      var query = Supabase.instance.client
          .from('brand_partnerships')
          .select()
          .eq('is_active', true)
          .eq('is_verified', true);
      
      // Filtrer par industrie
      if (industry != null) {
        query = query.eq('industry', industry);
      }
      
      // Filtrer par budget
      if (minBudget != null) {
        query = query.gte('budget_range_max', minBudget);
      }
      
      if (maxBudget != null) {
        query = query.lte('budget_range_min', maxBudget);
      }
      
      final result = await query.order('budget_range_max', ascending: false);
      
      final brands = result.map((json) => BrandPartnership.fromJson(json)).toList();
      
      // Mettre en cache
      for (final brand in brands) {
        _brands[brand.id] = brand;
      }
      
      return brands;
    } catch (e) {
      print('Erreur marques partenaires: $e');
      return [];
    }
  }
  
  /// Créer une demande de sponsorship
  static Future<String> createSponsorshipRequest({
    required String brandId,
    required String title,
    required String description,
    required SponsorshipType type,
    required CompensationType compensationType,
    required double compensationAmount,
    required DateTime startDate,
    DateTime? endDate,
    List<String>? requirements,
    List<String>? deliverables,
  }) async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) throw Exception('Utilisateur non connecté');
      
      // Vérifier si la marque existe
      final brand = _brands[brandId] ?? await _getBrandById(brandId);
      if (brand == null) throw Exception('Marque non trouvée');
      
      // Créer le sponsorship
      final sponsorshipId = _uuid.v4();
      final sponsorship = Sponsorship(
        id: sponsorshipId,
        userId: userId,
        brandId: brandId,
        title: title,
        description: description,
        type: type,
        requirements: requirements ?? [],
        compensationType: compensationType,
        compensationAmount: compensationAmount,
        compensationCurrency: 'USD',
        startDate: startDate,
        endDate: endDate,
        status: SponsorshipStatus.pending,
        deliverables: deliverables ?? [],
        metricsTracked: {},
        actualPerformance: {},
        payoutStatus: 'pending',
        payoutAmount: 0.0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      
      // Sauvegarder dans la base
      await Supabase.instance.client
          .from('sponsorships')
          .insert(sponsorship.toJson());
      
      _activeSponsorships[sponsorshipId] = sponsorship;
      
      // Notifier la marque (simulation)
      await _notifyBrand(brandId, sponsorshipId);
      
      return sponsorshipId;
    } catch (e) {
      print('Erreur création sponsorship: $e');
      rethrow;
    }
  }
  
  /// Obtenir les sponsorships d'un utilisateur
  static Future<List<Sponsorship>> getUserSponsorships() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return [];
      
      final result = await Supabase.instance.client
          .from('sponsorships')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      
      return result.map((json) => Sponsorship.fromJson(json)).toList();
    } catch (e) {
      print('Erreur sponsorships utilisateur: $e');
      return [];
    }
  }
  
  /// Mettre à jour les métriques d'un sponsorship
  static Future<void> updateSponsorshipMetrics({
    required String sponsorshipId,
    Map<String, dynamic>? metrics,
    Map<String, dynamic>? performance,
  }) async {
    try {
      final sponsorship = _activeSponsorships[sponsorshipId];
      if (sponsorship == null) throw Exception('Sponsorship non trouvé');
      
      // Mettre à jour les métriques
      if (metrics != null) {
        sponsorship.metricsTracked.addAll(metrics);
      }
      
      if (performance != null) {
        sponsorship.actualPerformance.addAll(performance);
      }
      
      // Calculer le montant du paiement
      final payoutAmount = _calculatePayoutAmount(sponsorship);
      sponsorship.payoutAmount = payoutAmount;
      
      // Mettre à jour dans la base
      await Supabase.instance.client
          .from('sponsorships')
          .update({
            'metrics_tracked': jsonEncode(sponsorship.metricsTracked),
            'actual_performance': jsonEncode(sponsorship.actualPerformance),
            'payout_amount': payoutAmount,
          })
          .eq('id', sponsorshipId);
      
      _activeSponsorships[sponsorshipId] = sponsorship;
    } catch (e) {
      print('Erreur mise à jour métriques: $e');
      rethrow;
    }
  }
  
  /// Calculer le montant du paiement
  static double _calculatePayoutAmount(Sponsorship sponsorship) {
    switch (sponsorship.compensationType) {
      case CompensationType.fixed:
        return sponsorship.compensationAmount;
      case CompensationType.cpm:
        final impressions = sponsorship.actualPerformance['impressions'] ?? 0;
        return (impressions / 1000) * sponsorship.compensationAmount;
      case CompensationType.cpc:
        final clicks = sponsorship.actualPerformance['clicks'] ?? 0;
        return clicks * sponsorship.compensationAmount;
      case CompensationType.revenueShare:
        final revenue = sponsorship.actualPerformance['revenue'] ?? 0.0;
        return revenue * (sponsorship.compensationAmount / 100);
    }
  }
  
  /// Accepter un sponsorship
  static Future<void> acceptSponsorship(String sponsorshipId) async {
    try {
      await Supabase.instance.client
          .from('sponsorships')
          .update({
            'status': 'active',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sponsorshipId);
      
      // Mettre à jour le cache
      final sponsorship = _activeSponsorships[sponsorshipId];
      if (sponsorship != null) {
        sponsorship.status = SponsorshipStatus.active;
      }
    } catch (e) {
      print('Erreur acceptation sponsorship: $e');
      rethrow;
    }
  }
  
  /// Refuser un sponsorship
  static Future<void> rejectSponsorship(String sponsorshipId, String reason) async {
    try {
      await Supabase.instance.client
          .from('sponsorships')
          .update({
            'status': 'cancelled',
            'cancellation_reason': reason,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sponsorshipId);
      
      // Mettre à jour le cache
      final sponsorship = _activeSponsorships[sponsorshipId];
      if (sponsorship != null) {
        sponsorship.status = SponsorshipStatus.cancelled;
      }
    } catch (e) {
      print('Erreur refus sponsorship: $e');
      rethrow;
    }
  }
  
  /// Compléter un sponsorship
  static Future<void> completeSponsorship(String sponsorshipId) async {
    try {
      await Supabase.instance.client
          .from('sponsorships')
          .update({
            'status': 'completed',
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', sponsorshipId);
      
      // Mettre à jour le cache
      final sponsorship = _activeSponsorships[sponsorshipId];
      if (sponsorship != null) {
        sponsorship.status = SponsorshipStatus.completed;
        await _createRevenueRecord(sponsorship);
      }
    } catch (e) {
      print('Erreur complétion sponsorship: $e');
      rethrow;
    }
  }
  
  /// Créer un enregistrement de revenu
  static Future<void> _createRevenueRecord(Sponsorship sponsorship) async {
    try {
      await Supabase.instance.client
          .from('revenue_analytics')
          .insert({
            'user_id': sponsorship.userId,
            'revenue_source': 'sponsorship',
            'revenue_type': sponsorship.compensationType.toString(),
            'amount': sponsorship.payoutAmount,
            'currency': sponsorship.compensationCurrency,
            'reference_id': sponsorship.id,
            'reference_type': 'sponsorship',
            'period_start': sponsorship.startDate.toIso8601String(),
            'period_end': sponsorship.endDate?.toIso8601String() ?? DateTime.now().toIso8601String(),
            'status': 'pending',
          });
    } catch (e) {
      print('Erreur création revenu: $e');
    }
  }
  
  /// Obtenir les sponsorships tendance
  static Future<List<Sponsorship>> getTrendingSponsorships({int limit = 10}) async {
    try {
      final result = await Supabase.instance.client
          .from('sponsorships')
          .select()
          .eq('status', 'active')
          .order('compensation_amount', ascending: false)
          .limit(limit);
      
      return result.map((json) => Sponsorship.fromJson(json)).toList();
    } catch (e) {
      print('Erreur sponsorships tendance: $e');
      return [];
    }
  }
  
  /// Obtenir les statistiques de sponsorship
  static Future<SponsorshipStats> getSponsorshipStats(String userId) async {
    try {
      final sponsorships = await getUserSponsorships();
      
      int totalSponsorships = sponsorships.length;
      int activeSponsorships = sponsorships.where((s) => s.status == SponsorshipStatus.active).length;
      int completedSponsorships = sponsorships.where((s) => s.status == SponsorshipStatus.completed).length;
      double totalRevenue = sponsorships.fold(0.0, (sum, s) => sum + s.payoutAmount);
      double pendingRevenue = sponsorships
          .where((s) => s.status == SponsorshipStatus.active)
          .fold(0.0, (sum, s) => sum + s.payoutAmount);
      
      // Regrouper par type
      final byType = <SponsorshipType, int>{};
      for (final sponsorship in sponsorships) {
        byType[sponsorship.type] = (byType[sponsorship.type] ?? 0) + 1;
      }
      
      return SponsorshipStats(
        totalSponsorships: totalSponsorships,
        activeSponsorships: activeSponsorships,
        completedSponsorships: completedSponsorships,
        totalRevenue: totalRevenue,
        pendingRevenue: pendingRevenue,
        byType: byType,
      );
    } catch (e) {
      print('Erreur statistiques sponsorship: $e');
      rethrow;
    }
  }
  
  /// Obtenir une marque par ID
  static Future<BrandPartnership?> _getBrandById(String brandId) async {
    try {
      final result = await Supabase.instance.client
          .from('brand_partnerships')
          .select()
          .eq('id', brandId)
          .maybeSingle();
      
      if (result != null) {
        return BrandPartnership.fromJson(result);
      }
      return null;
    } catch (e) {
      print('Erreur marque par ID: $e');
      return null;
    }
  }
  
  /// Notifier une marque (simulation)
  static Future<void> _notifyBrand(String brandId, String sponsorshipId) async {
    try {
      // Simuler une notification à la marque
      print('Notification envoyée à la marque $brandId pour le sponsorship $sponsorshipId');
      
      // Dans une vraie implémentation, cela pourrait envoyer un email, une notification push, etc.
    } catch (e) {
      print('Erreur notification marque: $e');
    }
  }
  
  /// Rechercher des sponsorships
  static Future<List<Sponsorship>> searchSponsorships(String query) async {
    try {
      final result = await Supabase.instance.client
          .from('sponsorships')
          .select()
          .or('title.ilike.%$query%,description.ilike.%$query%')
          .order('created_at', ascending: false);
      
      return result.map((json) => Sponsorship.fromJson(json)).toList();
    } catch (e) {
      print('Erreur recherche sponsorships: $e');
      return [];
    }
  }
}

/// Sponsorship
class Sponsorship {
  final String id;
  final String userId;
  final String brandId;
  final String title;
  final String description;
  final SponsorshipType type;
  final List<String> requirements;
  final CompensationType compensationType;
  final double compensationAmount;
  final String compensationCurrency;
  final DateTime startDate;
  final DateTime? endDate;
  SponsorshipStatus status;
  final List<String> deliverables;
  final Map<String, dynamic> metricsTracked;
  final Map<String, dynamic> actualPerformance;
  final String payoutStatus;
  double payoutAmount;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  Sponsorship({
    required this.id,
    required this.userId,
    required this.brandId,
    required this.title,
    required this.description,
    required this.type,
    required this.requirements,
    required this.compensationType,
    required this.compensationAmount,
    required this.compensationCurrency,
    required this.startDate,
    this.endDate,
    required this.status,
    required this.deliverables,
    required this.metricsTracked,
    required this.actualPerformance,
    required this.payoutStatus,
    required this.payoutAmount,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory Sponsorship.fromJson(Map<String, dynamic> json) {
    return Sponsorship(
      id: json['id'],
      userId: json['user_id'],
      brandId: json['brand_id'],
      title: json['title'],
      description: json['description'],
      type: SponsorshipType.values.firstWhere(
        (type) => type.toString() == 'SponsorshipType.${json['sponsorship_type']}',
        orElse: () => SponsorshipType.battle,
      ),
      requirements: List<String>.from(jsonDecode(json['requirements'] ?? '[]')),
      compensationType: CompensationType.values.firstWhere(
        (type) => type.toString() == 'CompensationType.${json['compensation_type']}',
        orElse: () => CompensationType.fixed,
      ),
      compensationAmount: json['compensation_amount']?.toDouble() ?? 0.0,
      compensationCurrency: json['compensation_currency'],
      startDate: DateTime.parse(json['start_date']),
      endDate: json['end_date'] != null ? DateTime.parse(json['end_date']) : null,
      status: SponsorshipStatus.values.firstWhere(
        (status) => status.toString() == 'SponsorshipStatus.${json['status']}',
        orElse: () => SponsorshipStatus.pending,
      ),
      deliverables: List<String>.from(jsonDecode(json['deliverables'] ?? '[]')),
      metricsTracked: jsonDecode(json['metrics_tracked'] ?? '{}'),
      actualPerformance: jsonDecode(json['actual_performance'] ?? '{}'),
      payoutStatus: json['payout_status'],
      payoutAmount: json['payout_amount']?.toDouble() ?? 0.0,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'brand_id': brandId,
      'title': title,
      'description': description,
      'sponsorship_type': type.toString(),
      'requirements': jsonEncode(requirements),
      'compensation_type': compensationType.toString(),
      'compensation_amount': compensationAmount,
      'compensation_currency': compensationCurrency,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate?.toIso8601String(),
      'status': status.toString(),
      'deliverables': jsonEncode(deliverables),
      'metrics_tracked': jsonEncode(metricsTracked),
      'actual_performance': jsonEncode(actualPerformance),
      'payout_status': payoutStatus,
      'payout_amount': payoutAmount,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

/// Partenariat de marque
class BrandPartnership {
  final String id;
  final String brandName;
  final String brandDescription;
  final String brandLogoUrl;
  final String brandWebsite;
  final String industry;
  final List<String> targetAudience;
  final double budgetRangeMin;
  final double budgetRangeMax;
  final String budgetCurrency;
  final String contactEmail;
  final String contactPhone;
  final List<String> partnershipTypes;
  final List<String> requirements;
  final bool isActive;
  final bool isVerified;
  final DateTime createdAt;
  final DateTime updatedAt;
  
  BrandPartnership({
    required this.id,
    required this.brandName,
    required this.brandDescription,
    required this.brandLogoUrl,
    required this.brandWebsite,
    required this.industry,
    required this.targetAudience,
    required this.budgetRangeMin,
    required this.budgetRangeMax,
    required this.budgetCurrency,
    required this.contactEmail,
    required this.contactPhone,
    required this.partnershipTypes,
    required this.requirements,
    required this.isActive,
    required this.isVerified,
    required this.createdAt,
    required this.updatedAt,
  });
  
  factory BrandPartnership.fromJson(Map<String, dynamic> json) {
    return BrandPartnership(
      id: json['id'],
      brandName: json['brand_name'],
      brandDescription: json['brand_description'],
      brandLogoUrl: json['brand_logo_url'],
      brandWebsite: json['brand_website'],
      industry: json['industry'],
      targetAudience: List<String>.from(jsonDecode(json['target_audience'] ?? '[]')),
      budgetRangeMin: json['budget_range_min']?.toDouble() ?? 0.0,
      budgetRangeMax: json['budget_range_max']?.toDouble() ?? 0.0,
      budgetCurrency: json['budget_currency'],
      contactEmail: json['contact_email'],
      contactPhone: json['contact_phone'],
      partnershipTypes: List<String>.from(jsonDecode(json['partnership_types'] ?? '[]')),
      requirements: List<String>.from(jsonDecode(json['requirements'] ?? '[]')),
      isActive: json['is_active'] ?? true,
      isVerified: json['is_verified'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }
}

/// Types de sponsorship
enum SponsorshipType {
  battle,
  postLive,
  clip,
  general,
}

/// Types de compensation
enum CompensationType {
  fixed,
  cpm,
  cpc,
  revenueShare,
}

/// Statuts de sponsorship
enum SponsorshipStatus {
  pending,
  active,
  completed,
  cancelled,
}

/// Statistiques de sponsorship
class SponsorshipStats {
  final int totalSponsorships;
  final int activeSponsorships;
  final int completedSponsorships;
  final double totalRevenue;
  final double pendingRevenue;
  final Map<SponsorshipType, int> byType;
  
  SponsorshipStats({
    required this.totalSponsorships,
    required this.activeSponsorships,
    required this.completedSponsorships,
    required this.totalRevenue,
    required this.pendingRevenue,
    required this.byType,
  });
}
