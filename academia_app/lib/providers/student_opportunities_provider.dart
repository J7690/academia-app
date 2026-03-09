import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les opportunités (stages, emplois, autres) côté étudiant
/// Utilise uniquement les RPC validées dans .windsurf (module opportunités)
/// Supporte la pagination et les interactions sociales (réactions, commentaires)
class StudentOpportunitiesProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isLoadingMore = false;
  String? _error;
  List<Map<String, dynamic>> _opportunities = [];
  List<Map<String, dynamic>> _applications = [];
  List<Map<String, dynamic>> _types = [];

  // Pagination
  int _total = 0;
  bool _hasMore = true;
  int _currentOffset = 0;
  static const int _pageSize = 20;

  // Filtres actuels (pour refresh)
  String? _currentType;
  String? _currentSearch;
  String _currentSort = 'newest';
  bool _currentVerifiedOnly = false;
  bool _currentReadyToShipOnly = false;

  bool get isLoading => _isLoading;
  bool get isLoadingMore => _isLoadingMore;
  String? get error => _error;
  List<Map<String, dynamic>> get opportunities => _opportunities;
  List<Map<String, dynamic>> get applications => _applications;
  List<Map<String, dynamic>> get types => _types;
  int get total => _total;
  bool get hasMore => _hasMore;

  // Badge notifications
  int _newCount = 0;
  int get newCount => _newCount;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  /// Charge les opportunités avec pagination
  /// Si refresh=true, recharge depuis le début
  Future<void> loadOpportunities({
    String? type,
    String? search,
    String? sort,
    bool? verifiedOnly,
    bool? readyToShipOnly,
    bool refresh = true,
  }) async {
    if (refresh) {
      _currentOffset = 0;
      _hasMore = true;
      _currentType = type;
      _currentSearch = search;
      _currentSort = sort ?? _currentSort;
      _currentVerifiedOnly = verifiedOnly ?? _currentVerifiedOnly;
      _currentReadyToShipOnly = readyToShipOnly ?? _currentReadyToShipOnly;
      _setLoading(true);
    } else {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_opportunities',
        params: {
          'p_type': type ?? _currentType,
          'p_search': search ?? _currentSearch,
          'p_limit': _pageSize,
          'p_offset': _currentOffset,
          'p_sort': sort ?? _currentSort,
          'p_verified_only': verifiedOnly ?? _currentVerifiedOnly,
          'p_ready_to_ship_only': readyToShipOnly ?? _currentReadyToShipOnly,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        final data = (response['opportunities'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _total = response['total'] as int? ?? 0;
        _hasMore = response['has_more'] as bool? ?? false;

        if (refresh) {
          _opportunities = data;
        } else {
          _opportunities = [..._opportunities, ...data];
        }
        _currentOffset += data.length;
      } else if (response is List<dynamic>) {
        // Fallback pour ancienne version de la RPC
        final data = response.cast<Map<String, dynamic>>();
        if (refresh) {
          _opportunities = data;
        } else {
          _opportunities = [..._opportunities, ...data];
        }
        _hasMore = false;
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
      _isLoadingMore = false;
    }
  }

  /// Charge uniquement les opportunités marquées en favoris (bookmarks)
  /// Utilise la RPC app_student_list_bookmarked_opportunities avec la même
  /// structure de réponse que app_student_list_opportunities
  Future<void> loadBookmarkedOpportunities({
    String? type,
    String? search,
    String? sort,
    bool? verifiedOnly,
    bool? readyToShipOnly,
    bool refresh = true,
  }) async {
    if (refresh) {
      _currentOffset = 0;
      _hasMore = true;
      _currentType = type;
      _currentSearch = search;
      _currentSort = sort ?? _currentSort;
      _currentVerifiedOnly = verifiedOnly ?? _currentVerifiedOnly;
      _currentReadyToShipOnly = readyToShipOnly ?? _currentReadyToShipOnly;
      _setLoading(true);
    } else {
      if (!_hasMore || _isLoadingMore) return;
      _isLoadingMore = true;
      notifyListeners();
    }

    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_list_bookmarked_opportunities',
        params: {
          'p_type': type ?? _currentType,
          'p_search': search ?? _currentSearch,
          'p_limit': _pageSize,
          'p_offset': _currentOffset,
          'p_sort': sort ?? _currentSort,
          'p_verified_only': verifiedOnly ?? _currentVerifiedOnly,
          'p_ready_to_ship_only': readyToShipOnly ?? _currentReadyToShipOnly,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        final data = (response['opportunities'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        _total = response['total'] as int? ?? 0;
        _hasMore = response['has_more'] as bool? ?? false;

        if (refresh) {
          _opportunities = data;
        } else {
          _opportunities = [..._opportunities, ...data];
        }
        _currentOffset += data.length;
      } else if (response is List<dynamic>) {
        // Fallback de sécurité si la RPC renvoie un tableau brut
        final data = response.cast<Map<String, dynamic>>();
        if (refresh) {
          _opportunities = data;
        } else {
          _opportunities = [..._opportunities, ...data];
        }
        _hasMore = false;
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
      _isLoadingMore = false;
    }
  }

  /// Charge plus d'opportunités (pagination)
  Future<void> loadMore() async {
    await loadOpportunities(
      type: _currentType,
      search: _currentSearch,
      sort: _currentSort,
      verifiedOnly: _currentVerifiedOnly,
      readyToShipOnly: _currentReadyToShipOnly,
      refresh: false,
    );
  }

  /// Rafraîchit le feed (pull-to-refresh)
  Future<void> refreshFeed() async {
    await loadOpportunities(
      type: _currentType,
      search: _currentSearch,
      sort: _currentSort,
      verifiedOnly: _currentVerifiedOnly,
      readyToShipOnly: _currentReadyToShipOnly,
      refresh: true,
    );
  }

  /// Met à jour les compteurs d'une opportunité localement
  /// (appelé après une réaction ou un commentaire)
  void updateOpportunityCounters(String opportunityId, {
    int? reactionsCount,
    int? commentsCount,
    String? myReaction,
  }) {
    final index = _opportunities.indexWhere((o) => o['id'] == opportunityId);
    if (index != -1) {
      final updated = Map<String, dynamic>.from(_opportunities[index]);
      if (reactionsCount != null) {
        updated['reactions_count'] = reactionsCount;
      }
      if (commentsCount != null) {
        updated['comments_count'] = commentsCount;
      }
      if (myReaction != null) {
        updated['my_reaction'] = myReaction;
      }
      _opportunities[index] = updated;
      notifyListeners();
    }
  }

  /// Met à jour localement le flag is_bookmarked d'une opportunité
  void updateOpportunityBookmark(String opportunityId, bool isBookmarked) {
    final index = _opportunities.indexWhere((o) => o['id'] == opportunityId);
    if (index != -1) {
      final updated = Map<String, dynamic>.from(_opportunities[index]);
      updated['is_bookmarked'] = isBookmarked;
      _opportunities[index] = updated;
      notifyListeners();
    }
  }

  /// Charge le nombre de nouvelles opportunités (pour badge)
  Future<void> loadNewCount() async {
    try {
      final response = await _client.rpc('app_opportunity_count_new');
      if (response is Map<String, dynamic> && response['success'] == true) {
        _newCount = response['count'] as int? ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[StudentOpportunitiesProvider] loadNewCount error: $e');
    }
  }

  /// Active/désactive le favori (bookmark) pour une opportunité
  /// Ne modifie pas les indicateurs de chargement globaux pour rester léger
  Future<bool> toggleBookmark(String opportunityId) async {
    try {
      final dynamic response = await _client.rpc(
        'app_opportunity_toggle_bookmark',
        params: {
          'p_opportunity_id': opportunityId,
        },
      );

      if (response is! Map<String, dynamic>) {
        return false;
      }

      if (response['success'] == true) {
        final bool isBookmarked = response['is_bookmarked'] == true;
        updateOpportunityBookmark(opportunityId, isBookmarked);
        return true;
      }

      return false;
    } catch (e) {
      debugPrint('[StudentOpportunitiesProvider] toggleBookmark error: $e');
      return false;
    }
  }

  /// Marque les opportunités comme vues (reset le badge)
  Future<void> markAsViewed() async {
    try {
      await _client.rpc('app_opportunity_mark_viewed');
      _newCount = 0;
      notifyListeners();
    } catch (e) {
      debugPrint('[StudentOpportunitiesProvider] markAsViewed error: $e');
    }
  }

  Future<void> loadTypes() async {
    _setError(null);
    try {
      final dynamic response = await _client.rpc('app_list_opportunity_types');
      final data = response as List<dynamic>? ?? [];
      _types = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    }
  }

  Future<void> loadMyApplications() async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response =
          await _client.rpc('app_student_list_my_opportunity_applications');
      final data = response as List<dynamic>? ?? [];
      _applications = data.cast<Map<String, dynamic>>();
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoading(false);
    }
  }

  Future<bool> applyForOpportunity({
    required String opportunityId,
    String? message,
    String? cvUrl,
  }) async {
    _setLoading(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_student_apply_for_opportunity',
        params: {
          'p_opportunity_id': opportunityId,
          'p_message': message,
          'p_cv_url': cvUrl,
          'p_extra_data': null,
        },
      );
      if (response is! Map<String, dynamic>) {
        _setError(
          "Réponse invalide du serveur lors de la création de la candidature.",
        );
        return false;
      }
      if (response['success'] != true) {
        final errorCode = response['error']?.toString() ?? '';
        String errorMessage;
        if (errorCode == 'already_applied') {
          errorMessage = 'Vous avez déjà postulé à cette opportunité.';
        } else if (errorCode == 'opportunity_not_found') {
          errorMessage = 'Cette opportunité n\'existe plus.';
        } else if (errorCode == 'opportunity_closed') {
          errorMessage = 'Cette opportunité n\'accepte plus de candidatures.';
        } else {
          errorMessage = errorCode.isNotEmpty 
              ? errorCode 
              : "Erreur lors de la création de la candidature.";
        }
        _setError(errorMessage);
        return false;
      }
      await loadMyApplications();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setLoading(false);
    }
  }

  Future<String?> uploadCvFile({
    required String opportunityId,
    required Uint8List bytes,
    required String fileName,
    String? mimeType,
  }) async {
    _setError(null);
    try {
      final user = _client.auth.currentUser;
      if (user == null) {
        _setError('Utilisateur non authentifié');
        return null;
      }

      final storagePath = '${user.id}/opportunities/$opportunityId/$fileName';

      await _client.storage.from('application-files').uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(
              contentType: _normalizeMimeType(mimeType),
              upsert: true,
            ),
          );

      return storagePath;
    } catch (e) {
      _setError(e.toString());
      return null;
    }
  }

  String _normalizeMimeType(String? extensionOrMime) {
    if (extensionOrMime == null || extensionOrMime.isEmpty) {
      return 'application/octet-stream';
    }

    final value = extensionOrMime.toLowerCase();

    if (value.contains('/')) {
      return value;
    }

    switch (value) {
      case 'pdf':
        return 'application/pdf';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'png':
        return 'image/png';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }
}
