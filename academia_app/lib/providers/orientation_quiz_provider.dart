import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Test d'orientation.
///
/// Le test raisonne en **domaines** et en **profils** : aucun établissement,
/// aucune école, aucun concours public n'est nommé — ni ici, ni en base.
///
/// Trois états, qui déterminent l'affichage de l'onglet Orientation :
///   * aucune tentative           → accroche « Commencer le test »
///   * tentative en cours         → « Reprendre », avec la progression
///   * tentative terminée         → carte de résultat
class OrientationQuizProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;

  List<Map<String, dynamic>> _questions = const [];
  Map<String, dynamic>? _attempt;
  Map<String, dynamic>? _result;
  int _total = 0;

  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  List<Map<String, dynamic>> get questions => List.unmodifiable(_questions);
  Map<String, dynamic>? get attempt => _attempt;
  Map<String, dynamic>? get result => _result;

  int get total => _total;

  /// Nombre de questions déjà répondues dans la tentative courante.
  int get answered {
    final value = _attempt?['answered'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  bool get hasStarted => _attempt != null && answered > 0 && !isCompleted;
  bool get isCompleted => _result != null;

  double get progress => _total == 0 ? 0 : (answered / _total).clamp(0, 1);

  /// Réponses déjà enregistrées : `question_id` → `option_id`.
  Map<String, String> get answers {
    final raw = _attempt?['answers'];
    if (raw is Map) {
      return raw.map((k, v) => MapEntry('$k', '$v'));
    }
    return const {};
  }

  /// Index de la première question sans réponse — le point de reprise.
  int get resumeIndex {
    final saved = answers;
    for (var i = 0; i < _questions.length; i++) {
      if (!saved.containsKey('${_questions[i]['id']}')) return i;
    }
    return 0;
  }

  // ─── Chargement ─────────────────────────────────────────────────────

  Future<void> load() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client.rpc('app_orientation_quiz_get');
      if (res is Map<String, dynamic> && res['success'] == true) {
        final data = res['questions'];
        _questions = data is List
            ? data
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList(growable: false)
            : const [];
        _total = (res['total'] as num?)?.toInt() ?? _questions.length;
        final attempt = res['attempt'];
        _attempt =
            attempt is Map ? Map<String, dynamic>.from(attempt) : null;
        final result = res['result'];
        _result = result is Map ? Map<String, dynamic>.from(result) : null;
      } else {
        _error = _messageFrom(res, 'Test indisponible.');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[OrientationQuiz] load: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Déroulé ────────────────────────────────────────────────────────

  /// Enregistre une réponse. Retourne `true` si le test est complet.
  Future<bool> answer({
    required String questionId,
    required String optionId,
  }) async {
    _isSaving = true;
    notifyListeners();
    try {
      final res = await _client.rpc('app_orientation_quiz_answer', params: {
        'p_question_id': questionId,
        'p_option_id': optionId,
      });
      if (res is Map<String, dynamic> && res['success'] == true) {
        // On tient l'état à jour localement : le test doit rester fluide
        // même sur une connexion lente.
        final updated = Map<String, dynamic>.from(_attempt ?? {});
        final saved = Map<String, dynamic>.from(updated['answers'] as Map? ?? {});
        saved[questionId] = optionId;
        updated['answers'] = saved;
        updated['answered'] = (res['answered'] as num?)?.toInt() ?? saved.length;
        _attempt = updated;
        _total = (res['total'] as num?)?.toInt() ?? _total;
        notifyListeners();
        return res['done'] == true;
      }
      _error = _messageFrom(res, 'Réponse non enregistrée.');
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('[OrientationQuiz] answer: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Clôture la tentative et calcule le profil.
  Future<bool> submit() async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client.rpc('app_orientation_quiz_submit');
      if (res is Map<String, dynamic> && res['success'] == true) {
        final result = res['result'];
        _result = result is Map ? Map<String, dynamic>.from(result) : null;
        notifyListeners();
        return _result != null;
      }
      _error = _messageFrom(res, 'Calcul du résultat impossible.');
      return false;
    } catch (e) {
      _error = e.toString();
      debugPrint('[OrientationQuiz] submit: $e');
      return false;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  /// Repart de zéro. L'historique des tentatives terminées est conservé.
  Future<void> reset() async {
    _isSaving = true;
    _error = null;
    notifyListeners();
    try {
      await _client.rpc('app_orientation_quiz_reset');
      _attempt = null;
      _result = null;
    } catch (e) {
      _error = e.toString();
      debugPrint('[OrientationQuiz] reset: $e');
    } finally {
      _isSaving = false;
      notifyListeners();
    }
    await load();
  }

  // ─── Utilitaires ────────────────────────────────────────────────────

  static String _messageFrom(dynamic res, String fallback) {
    if (res is Map && res['error'] != null) return res['error'].toString();
    return fallback;
  }

  /// Options d'une question, triées.
  static List<Map<String, dynamic>> optionsOf(Map<String, dynamic> question) {
    final raw = question['options'];
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);
  }
}
