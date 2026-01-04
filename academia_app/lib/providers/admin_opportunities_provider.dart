import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminOpportunitiesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;
  List<Map<String, dynamic>> _opportunities = [];
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _types = [];

  bool get isLoading => _isLoading;
  String? get error => _error;
  List<Map<String, dynamic>> get opportunities => List.unmodifiable(_opportunities);
  List<Map<String, dynamic>> get applications => List.unmodifiable(_applications);
  List<Map<String, dynamic>> get types => List.unmodifiable(_types);

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadOpportunities() async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_opportunities');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            "Erreur lors du chargement des opportunités.");
        return;
      }
      final data = response['opportunities'];
      if (data is List) {
        _opportunities = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _opportunities = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadTypes() async {
    _setError(null);
    try {
      final response = await _client.rpc('app_admin_list_opportunity_types');
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les types.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors du chargement des types d\'opportunités.');
        return;
      }
      final data = response['types'];
      if (data is List) {
        _types = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _types = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<bool> upsertOpportunity({
    String? opportunityId,
    required String title,
    required String shortDescription,
    String? description,
    required String type,
    String? category,
    required String organizationName,
    String? organizationLogoUrl,
    required String country,
    required String city,
    bool? isRemotePossible,
    String? contractType,
    int? durationMonths,
    DateTime? startDate,
    DateTime? applicationDeadline,
    String? status,
    bool? isFeatured,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_opportunity',
        params: {
          'p_opportunity_id': opportunityId,
          'p_title': title,
          'p_short_description': shortDescription,
          'p_description': description,
          'p_type': type,
          'p_category': category,
          'p_organization_name': organizationName,
          'p_organization_logo_url': organizationLogoUrl,
          'p_country': country,
          'p_city': city,
          'p_is_remote_possible': isRemotePossible,
          'p_contract_type': contractType,
          'p_duration_months': durationMonths,
          'p_start_date': startDate?.toIso8601String(),
          'p_application_deadline': applicationDeadline?.toIso8601String(),
          'p_status': status,
          'p_is_featured': isFeatured,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la sauvegarde de l\'opportunité.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            "Erreur lors de la sauvegarde de l'opportunité.");
        return false;
      }
      await loadOpportunities();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> updateOpportunityStatus({
    required String opportunityId,
    String? status,
    bool? isFeatured,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_opportunity_status',
        params: {
          'p_opportunity_id': opportunityId,
          'p_status': status,
          'p_is_featured': isFeatured,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic> || response['success'] != true) {
        _setError(
          response is Map<String, dynamic>
              ? response['error']?.toString() ??
                  "Erreur lors de la mise à jour de l'opportunité."
              : "Erreur lors de la mise à jour de l'opportunité.",
        );
        return false;
      }
      await loadOpportunities();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<void> loadApplicationsForOpportunity(String opportunityId) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_list_opportunity_applications',
        params: {
          'p_opportunity_id': opportunityId,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError('Réponse invalide du serveur pour les candidatures.');
        return;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors du chargement des candidatures.');
        return;
      }
      final data = response['applications'];
      if (data is List) {
        _applications = data
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList(growable: false);
      } else {
        _applications = [];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> upsertType({
    String? typeId,
    required String code,
    required String label,
    int? sortOrder,
    bool? isActive,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_opportunity_type',
        params: {
          'p_type_id': typeId,
          'p_code': code,
          'p_label': label,
          'p_sort_order': sortOrder,
          'p_is_active': isActive,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la sauvegarde du type.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la sauvegarde du type d\'opportunité.');
        return false;
      }
      await loadTypes();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> createCvSignedUrl(String cvUrl) async {
    _setError(null);
    try {
      final trimmed = cvUrl.trim();
      if (trimmed.isEmpty) {
        return null;
      }
      if (trimmed.startsWith('http://') || trimmed.startsWith('https://')) {
        return trimmed;
      }
      final url = await _client.storage
          .from('application-files')
          .createSignedUrl(trimmed, 60 * 60);
      return url;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  /// Met à jour le statut d'une candidature (pending, submitted, accepted, rejected)
  Future<bool> updateApplicationStatus({
    required String applicationId,
    required String status,
    String? adminNotes,
    String? opportunityId,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_update_application_status',
        params: {
          'p_application_id': applicationId,
          'p_status': status,
          'p_admin_notes': adminNotes,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la mise à jour du statut.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            'Erreur lors de la mise à jour du statut de la candidature.');
        return false;
      }
      // Recharger les candidatures si on a l'ID de l'opportunité
      if (opportunityId != null) {
        await loadApplicationsForOpportunity(opportunityId);
      }
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Met à jour une opportunité avec le nouveau champ price
  Future<bool> upsertOpportunityWithPrice({
    String? opportunityId,
    required String title,
    required String shortDescription,
    String? description,
    required String type,
    String? category,
    required String organizationName,
    String? organizationLogoUrl,
    required String country,
    required String city,
    bool? isRemotePossible,
    String? contractType,
    int? durationMonths,
    DateTime? startDate,
    DateTime? applicationDeadline,
    String? status,
    bool? isFeatured,
    bool? isActive,
    double? price,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_admin_upsert_opportunity',
        params: {
          'p_opportunity_id': opportunityId,
          'p_title': title,
          'p_short_description': shortDescription,
          'p_description': description,
          'p_type': type,
          'p_category': category,
          'p_organization_name': organizationName,
          'p_organization_logo_url': organizationLogoUrl,
          'p_country': country,
          'p_city': city,
          'p_is_remote_possible': isRemotePossible,
          'p_contract_type': contractType,
          'p_duration_months': durationMonths,
          'p_start_date': startDate?.toIso8601String(),
          'p_application_deadline': applicationDeadline?.toIso8601String(),
          'p_status': status,
          'p_is_featured': isFeatured,
          'p_is_active': isActive,
          'p_price': price,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          'Réponse invalide du serveur lors de la sauvegarde de l\'opportunité.',
        );
        return false;
      }
      if (response['success'] != true) {
        _setError(response['error']?.toString() ??
            "Erreur lors de la sauvegarde de l'opportunité.");
        return false;
      }
      await loadOpportunities();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }
}
