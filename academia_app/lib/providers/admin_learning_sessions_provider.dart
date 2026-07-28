import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Supervision administrateur du Studio Live.
///
/// Voit ce que voit l'enseignant, mais sur **toutes** les séances de la
/// plateforme, brouillons compris, avec les pouvoirs de modération :
/// changement de statut et interruption d'une séance en cours.
///
/// Toutes les RPC appelées ici vérifient le rôle administrateur côté base.
/// Le contrôle n'est jamais laissé à l'interface.
class AdminLearningSessionsProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isActing = false;
  String? _error;
  List<Map<String, dynamic>> _sessions = [];
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _participants = [];

  bool get isLoading => _isLoading;
  bool get isActing => _isActing;
  String? get error => _error;
  List<Map<String, dynamic>> get sessions => List.unmodifiable(_sessions);
  Map<String, dynamic> get stats => Map.unmodifiable(_stats);
  List<Map<String, dynamic>> get participants => List.unmodifiable(_participants);

  void clearError() {
    _error = null;
    notifyListeners();
  }

  // ─── Chargement ─────────────────────────────────────────────────────

  Future<void> load({
    String? status,
    String? sessionType,
    String? search,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final results = await Future.wait([
        _client.rpc('app_admin_learning_list_sessions', params: {
          'p_status': status,
          'p_session_type': sessionType,
          'p_host_id': null,
          'p_search': search,
          'p_limit': 200,
          'p_offset': 0,
        }),
        _client.rpc('app_admin_learning_overview'),
      ]);

      final listRes = results[0];
      if (listRes is Map<String, dynamic> && listRes['success'] == true) {
        final data = listRes['sessions'];
        _sessions = data is List
            ? data.whereType<Map<String, dynamic>>().toList(growable: false)
            : const [];
      } else if (listRes is Map<String, dynamic>) {
        _error = listRes['error']?.toString();
        _sessions = const [];
      }

      final statsRes = results[1];
      if (statsRes is Map<String, dynamic> && statsRes['success'] == true) {
        final s = statsRes['stats'];
        _stats = s is Map<String, dynamic> ? s : const {};
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[AdminLearningSessions] load error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> loadParticipants(String sessionId) async {
    try {
      final res = await _client.rpc('app_admin_learning_presence_list',
          params: {'p_session_id': sessionId});
      if (res is Map<String, dynamic> && res['success'] == true) {
        final data = res['participants'];
        _participants = data is List
            ? data.whereType<Map<String, dynamic>>().toList(growable: false)
            : const [];
      } else {
        _participants = const [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[AdminLearningSessions] loadParticipants error: $e');
      _participants = const [];
      notifyListeners();
    }
  }

  // ─── Actions de modération ──────────────────────────────────────────

  Future<bool> updateStatus(String sessionId, String newStatus) async {
    _isActing = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client.rpc('app_admin_learning_update_session_status',
          params: {'p_session_id': sessionId, 'p_new_status': newStatus});
      if (res is Map<String, dynamic> && res['success'] == true) return true;
      _error = res is Map<String, dynamic>
          ? res['error']?.toString()
          : 'Réponse invalide.';
      return false;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _isActing = false;
      notifyListeners();
    }
  }

  /// Interrompt une séance en cours et déconnecte ses participants.
  /// L'action est tracée dans `app.admin_audit_log`.
  Future<int?> forceEnd(String sessionId, {String? reason}) async {
    _isActing = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client.rpc('app_admin_learning_force_end_session',
          params: {'p_session_id': sessionId, 'p_reason': reason});
      if (res is Map<String, dynamic> && res['success'] == true) {
        final n = res['participants_deconnectes'];
        return n is int ? n : int.tryParse('$n') ?? 0;
      }
      _error = res is Map<String, dynamic>
          ? res['error']?.toString()
          : 'Réponse invalide.';
      return null;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isActing = false;
      notifyListeners();
    }
  }
}
