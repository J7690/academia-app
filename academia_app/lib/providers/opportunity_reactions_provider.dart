import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour les réactions sur les listings marketplace (like/love)
/// Utilise les RPC: app_listing_toggle_reaction, app_listing_get_reactions
class OpportunityReactionsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  String? _error;

  // Cache des réactions par opportunité: opportunity_id → reaction_type (ou null)
  final Map<String, String?> _myReactions = {};

  // Cache des compteurs par opportunité: opportunity_id → {likes: n, loves: m, total: t}
  final Map<String, Map<String, int>> _reactionCounts = {};

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

  /// Récupère ma réaction sur une opportunité (depuis le cache ou le serveur)
  String? getMyReaction(String opportunityId) {
    return _myReactions[opportunityId];
  }

  /// Récupère les compteurs de réactions pour une opportunité
  Map<String, int> getReactionCounts(String opportunityId) {
    return _reactionCounts[opportunityId] ?? {'likes': 0, 'loves': 0, 'total': 0};
  }

  /// Met à jour le cache local avec les données d'une opportunité
  void updateFromOpportunityData(Map<String, dynamic> opportunity) {
    final id = opportunity['id']?.toString();
    if (id == null) return;

    final myReaction = opportunity['my_reaction']?.toString();
    final reactionsCount = opportunity['reactions_count'] as int? ?? 0;

    _myReactions[id] = myReaction;
    _reactionCounts[id] = {
      'likes': 0,
      'loves': 0,
      'total': reactionsCount,
    };
  }

  /// Charge ma réaction pour une opportunité spécifique
  Future<void> loadMyReaction(String opportunityId) async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_listing_get_reactions',
        params: {'p_listing_id': opportunityId},
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        _myReactions[opportunityId] = response['my_reaction']?.toString();
        _reactionCounts[opportunityId] = {
          'likes': response['likes'] as int? ?? 0,
          'loves': response['loves'] as int? ?? 0,
          'total': response['total'] as int? ?? 0,
        };
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[OpportunityReactionsProvider] loadMyReaction error: $e');
    }
  }

  /// Charge les compteurs détaillés de réactions pour une opportunité
  Future<void> loadReactionCounts(String opportunityId) async {
    _setError(null);
    try {
      final response = await _client.rpc(
        'app_listing_get_reactions',
        params: {'p_listing_id': opportunityId},
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        _reactionCounts[opportunityId] = {
          'likes': response['likes'] as int? ?? 0,
          'loves': response['loves'] as int? ?? 0,
          'total': response['total'] as int? ?? 0,
        };
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[OpportunityReactionsProvider] loadReactionCounts error: $e');
    }
  }

  /// Toggle une réaction (like ou love)
  /// Si l'utilisateur a déjà cette réaction, elle est supprimée
  /// Si l'utilisateur a une autre réaction, elle est remplacée
  /// Si l'utilisateur n'a pas de réaction, elle est ajoutée
  Future<bool> toggleReaction(String opportunityId, String reactionType) async {
    if (reactionType != 'like' && reactionType != 'love') {
      _setError('Type de réaction invalide');
      return false;
    }

    _setLoading(true);
    _setError(null);

    // Optimistic update
    final previousReaction = _myReactions[opportunityId];
    final previousCounts = Map<String, int>.from(_reactionCounts[opportunityId] ?? {'likes': 0, 'loves': 0, 'total': 0});

    // Calculer le nouvel état optimiste
    if (previousReaction == reactionType) {
      // Toggle off
      _myReactions[opportunityId] = null;
      _reactionCounts[opportunityId] = {
        ...previousCounts,
        'total': (previousCounts['total'] ?? 0) - 1,
      };
    } else if (previousReaction != null) {
      // Change reaction type
      _myReactions[opportunityId] = reactionType;
      // Total reste le même
    } else {
      // Add new reaction
      _myReactions[opportunityId] = reactionType;
      _reactionCounts[opportunityId] = {
        ...previousCounts,
        'total': (previousCounts['total'] ?? 0) + 1,
      };
    }
    notifyListeners();

    try {
      final response = await _client.rpc(
        'app_listing_toggle_reaction',
        params: {
          'p_listing_id': opportunityId,
          'p_reaction_type': reactionType,
        },
      );

      if (response is Map<String, dynamic>) {
        if (response['success'] == true) {
          // Mettre à jour avec les vraies valeurs du serveur
          _myReactions[opportunityId] = response['my_reaction']?.toString();
          final newCount = response['reactions_count'] as int? ?? 0;
          _reactionCounts[opportunityId] = {
            ...(_reactionCounts[opportunityId] ?? {}),
            'total': newCount,
          };
          notifyListeners();
          return true;
        } else {
          // Rollback
          _myReactions[opportunityId] = previousReaction;
          _reactionCounts[opportunityId] = previousCounts;
          _setError(response['error']?.toString() ?? 'Erreur lors de la réaction');
          notifyListeners();
          return false;
        }
      }

      // Rollback si réponse invalide
      _myReactions[opportunityId] = previousReaction;
      _reactionCounts[opportunityId] = previousCounts;
      notifyListeners();
      return false;
    } catch (e) {
      // Rollback
      _myReactions[opportunityId] = previousReaction;
      _reactionCounts[opportunityId] = previousCounts;
      _setError(e.toString());
      notifyListeners();
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Nettoie le cache pour une opportunité
  void clearCache(String opportunityId) {
    _myReactions.remove(opportunityId);
    _reactionCounts.remove(opportunityId);
  }

  /// Nettoie tout le cache
  void clearAllCache() {
    _myReactions.clear();
    _reactionCounts.clear();
    notifyListeners();
  }
}
