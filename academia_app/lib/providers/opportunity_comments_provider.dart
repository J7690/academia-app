import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les commentaires sur les opportunités
/// Utilise les RPC: app_opportunity_add_comment, app_opportunity_list_comments, app_opportunity_delete_comment
class OpportunityCommentsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;

  // Cache des commentaires par opportunité: opportunity_id → List<comment>
  final Map<String, List<Map<String, dynamic>>> _comments = {};

  // Cache des totaux par opportunité
  final Map<String, int> _totals = {};

  // Cache has_more par opportunité
  final Map<String, bool> _hasMore = {};

  bool get isLoading => _isLoading;
  String? get error => _error;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    if (value != null) {
      notifyListeners();
    }
  }

  /// Récupère les commentaires d'une opportunité (depuis le cache)
  List<Map<String, dynamic>> getComments(String opportunityId) {
    return _comments[opportunityId] ?? [];
  }

  /// Récupère le total de commentaires pour une opportunité
  int getTotal(String opportunityId) {
    return _totals[opportunityId] ?? 0;
  }

  /// Vérifie s'il y a plus de commentaires à charger
  bool hasMore(String opportunityId) {
    return _hasMore[opportunityId] ?? true;
  }

  /// Met à jour le compteur local depuis les données d'une opportunité
  void updateCountFromOpportunityData(Map<String, dynamic> opportunity) {
    final id = opportunity['id']?.toString();
    if (id == null) return;

    final commentsCount = opportunity['comments_count'] as int? ?? 0;
    _totals[id] = commentsCount;
  }

  /// Charge les commentaires d'une opportunité
  Future<void> loadComments(
    String opportunityId, {
    bool refresh = false,
    int limit = 20,
  }) async {
    if (refresh) {
      _comments[opportunityId] = [];
      _hasMore[opportunityId] = true;
    }

    final currentComments = _comments[opportunityId] ?? [];
    final offset = refresh ? 0 : currentComments.length;

    // Ne pas charger si on sait qu'il n'y a plus de commentaires
    if (!refresh && _hasMore[opportunityId] == false) {
      return;
    }

    _setLoading(true);
    _setError(null);

    try {
      final response = await _client.rpc(
        'app_opportunity_list_comments',
        params: {
          'p_opportunity_id': opportunityId,
          'p_limit': limit,
          'p_offset': offset,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        final newComments = (response['comments'] as List<dynamic>? ?? [])
            .cast<Map<String, dynamic>>();
        final total = response['total'] as int? ?? 0;
        final hasMoreData = response['has_more'] as bool? ?? false;

        if (refresh) {
          _comments[opportunityId] = newComments;
        } else {
          _comments[opportunityId] = [...currentComments, ...newComments];
        }

        _totals[opportunityId] = total;
        _hasMore[opportunityId] = hasMoreData;
        notifyListeners();
      } else {
        _setError(response['error']?.toString() ?? 'Erreur lors du chargement des commentaires');
      }
    } catch (e) {
      _setError(e.toString());
      debugPrint('[OpportunityCommentsProvider] loadComments error: $e');
    } finally {
      _setLoading(false);
    }
  }

  /// Ajoute un commentaire
  Future<bool> addComment(String opportunityId, String content) async {
    final trimmedContent = content.trim();
    if (trimmedContent.isEmpty || trimmedContent.length < 2) {
      _setError('Le commentaire est trop court');
      return false;
    }

    if (trimmedContent.length > 1000) {
      _setError('Le commentaire est trop long (max 1000 caractères)');
      return false;
    }

    _setLoading(true);
    _setError(null);

    try {
      final response = await _client.rpc(
        'app_opportunity_add_comment',
        params: {
          'p_opportunity_id': opportunityId,
          'p_content': trimmedContent,
        },
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        final newCount = response['comments_count'] as int? ?? (_totals[opportunityId] ?? 0) + 1;
        _totals[opportunityId] = newCount;

        // Recharger les commentaires pour avoir le nouveau en haut
        await loadComments(opportunityId, refresh: true);
        return true;
      } else {
        _setError(response['error']?.toString() ?? 'Erreur lors de l\'ajout du commentaire');
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      debugPrint('[OpportunityCommentsProvider] addComment error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Supprime un commentaire
  Future<bool> deleteComment(String commentId, String opportunityId) async {
    _setLoading(true);
    _setError(null);

    // Optimistic update: retirer le commentaire du cache
    final currentComments = List<Map<String, dynamic>>.from(_comments[opportunityId] ?? []);
    final commentIndex = currentComments.indexWhere((c) => c['id'] == commentId);
    Map<String, dynamic>? removedComment;

    if (commentIndex != -1) {
      removedComment = currentComments.removeAt(commentIndex);
      _comments[opportunityId] = currentComments;
      _totals[opportunityId] = (_totals[opportunityId] ?? 1) - 1;
      notifyListeners();
    }

    try {
      final response = await _client.rpc(
        'app_opportunity_delete_comment',
        params: {'p_comment_id': commentId},
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        final newCount = response['comments_count'] as int? ?? _totals[opportunityId];
        _totals[opportunityId] = newCount ?? 0;
        notifyListeners();
        return true;
      } else {
        // Rollback
        if (removedComment != null && commentIndex != -1) {
          currentComments.insert(commentIndex, removedComment);
          _comments[opportunityId] = currentComments;
          _totals[opportunityId] = (_totals[opportunityId] ?? 0) + 1;
          notifyListeners();
        }
        _setError(response['error']?.toString() ?? 'Erreur lors de la suppression');
        return false;
      }
    } catch (e) {
      // Rollback
      if (removedComment != null && commentIndex != -1) {
        currentComments.insert(commentIndex, removedComment);
        _comments[opportunityId] = currentComments;
        _totals[opportunityId] = (_totals[opportunityId] ?? 0) + 1;
        notifyListeners();
      }
      _setError(e.toString());
      debugPrint('[OpportunityCommentsProvider] deleteComment error: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Nettoie le cache pour une opportunité
  void clearCache(String opportunityId) {
    _comments.remove(opportunityId);
    _totals.remove(opportunityId);
    _hasMore.remove(opportunityId);
  }

  /// Nettoie tout le cache
  void clearAllCache() {
    _comments.clear();
    _totals.clear();
    _hasMore.clear();
    notifyListeners();
  }
}
