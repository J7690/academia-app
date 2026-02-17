import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Provider pour le calendrier académique côté étudiant.
/// Consomme les RPC :
/// - app_list_academic_events_for_student
/// - app_list_my_followed_academic_events
/// - app_follow_academic_event
/// - app_unfollow_academic_event
/// - app_get_academic_events_summary
class StudentAcademicCalendarProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoadingEvents = false;
  bool _isLoadingFollowed = false;
  bool _isUpdatingFollow = false;
  String? _error;

  List<Map<String, dynamic>> _events = <Map<String, dynamic>>[];
  List<Map<String, dynamic>> _followedEvents = <Map<String, dynamic>>[];
  int _upcomingFollowedCount = 0;

  bool get isLoadingEvents => _isLoadingEvents;
  bool get isLoadingFollowed => _isLoadingFollowed;
  bool get isUpdatingFollow => _isUpdatingFollow;
  String? get error => _error;
  List<Map<String, dynamic>> get events =>
      List<Map<String, dynamic>>.unmodifiable(_events);
  List<Map<String, dynamic>> get followedEvents =>
      List<Map<String, dynamic>>.unmodifiable(_followedEvents);
  int get upcomingFollowedCount => _upcomingFollowedCount;

  void _setLoadingEvents(bool value) {
    _isLoadingEvents = value;
    notifyListeners();
  }

  void _setLoadingFollowed(bool value) {
    _isLoadingFollowed = value;
    notifyListeners();
  }

  void _setUpdatingFollow(bool value) {
    _isUpdatingFollow = value;
    notifyListeners();
  }

  void _setError(String? value) {
    _error = value;
    notifyListeners();
  }

  Future<void> loadEvents({
    DateTime? from,
    DateTime? to,
  }) async {
    _setLoadingEvents(true);
    _setError(null);
    try {
      final Map<String, dynamic> params = <String, dynamic>{};
      if (from != null) {
        params['p_from'] = from.toUtc().toIso8601String();
      }
      if (to != null) {
        params['p_to'] = to.toUtc().toIso8601String();
      }

      final dynamic response = await _client.rpc(
        'app_list_academic_events_for_student',
        params: params.isEmpty ? null : params,
      );

      if (response is Map<String, dynamic> && response['success'] == true) {
        final List<dynamic> rawList =
            (response['events'] as List<dynamic>? ?? <dynamic>[]);
        _events = rawList
            .whereType<Map>()
            .map((dynamic e) => Map<String, dynamic>.from(
                  e as Map<dynamic, dynamic>,
                ))
            .toList(growable: false);
      } else {
        _events = <Map<String, dynamic>>[];
        if (response is Map<String, dynamic>) {
          _setError(
            response['error']?.toString() ??
                'Erreur lors du chargement du calendrier académique.',
          );
        }
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoadingEvents(false);
    }
  }

  Future<void> loadFollowedEvents() async {
    _setLoadingFollowed(true);
    _setError(null);
    try {
      final dynamic response =
          await _client.rpc('app_list_my_followed_academic_events');
      if (response is Map<String, dynamic> && response['success'] == true) {
        final List<dynamic> rawList =
            (response['events'] as List<dynamic>? ?? <dynamic>[]);
        _followedEvents = rawList
            .whereType<Map>()
            .map((dynamic e) => Map<String, dynamic>.from(
                  e as Map<dynamic, dynamic>,
                ))
            .toList(growable: false);
      } else {
        _followedEvents = <Map<String, dynamic>>[];
      }
      notifyListeners();
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setLoadingFollowed(false);
    }
  }

  Future<void> loadSummary() async {
    try {
      final dynamic response =
          await _client.rpc('app_get_academic_events_summary');
      if (response is Map<String, dynamic> && response['success'] == true) {
        _upcomingFollowedCount =
            response['upcoming_followed_count'] as int? ?? 0;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[StudentAcademicCalendarProvider] loadSummary error: $e');
    }
  }

  Future<bool> followEvent(
    String eventId, {
    String followMode = 'normal',
  }) async {
    _setUpdatingFollow(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_follow_academic_event',
        params: <String, dynamic>{
          'p_event_id': eventId,
          'p_follow_mode': followMode,
        },
      );

      if (response is! Map<String, dynamic> || response['success'] != true) {
        if (response is Map<String, dynamic>) {
          _setError(
            response['error']?.toString() ??
                'Erreur lors du suivi de l\'événement académique.',
          );
        }
        return false;
      }

      _updateEventFollowState(eventId, isFollowed: true, followMode: followMode);
      await loadFollowedEvents();
      await loadSummary();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setUpdatingFollow(false);
    }
  }

  Future<bool> unfollowEvent(String eventId) async {
    _setUpdatingFollow(true);
    _setError(null);
    try {
      final dynamic response = await _client.rpc(
        'app_unfollow_academic_event',
        params: <String, dynamic>{
          'p_event_id': eventId,
        },
      );

      if (response is! Map<String, dynamic> || response['success'] != true) {
        if (response is Map<String, dynamic>) {
          _setError(
            response['error']?.toString() ??
                'Erreur lors de l\'annulation du suivi de l\'événement.',
          );
        }
        return false;
      }

      _updateEventFollowState(eventId, isFollowed: false, followMode: null);
      await loadFollowedEvents();
      await loadSummary();
      return true;
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setUpdatingFollow(false);
    }
  }

  void _updateEventFollowState(
    String eventId, {
    required bool isFollowed,
    String? followMode,
  }) {
    final int index = _events.indexWhere(
      (Map<String, dynamic> e) => e['id'] == eventId,
    );
    if (index != -1) {
      final Map<String, dynamic> updated =
          Map<String, dynamic>.from(_events[index]);
      updated['is_followed'] = isFollowed;
      if (followMode != null) {
        updated['follow_mode'] = followMode;
      } else {
        updated.remove('follow_mode');
      }
      _events[index] = updated;
    }
    notifyListeners();
  }
}
