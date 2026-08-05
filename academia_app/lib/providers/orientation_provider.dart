import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Conseil d'orientation — recherche, créneaux, réservation, fiche.
///
/// L'orientation n'emprunte plus le formulaire de séance de cours. Elle a son
/// propre parcours :
///
/// ```
/// test psychotechnique  →  choix d'un conseiller  →  créneau
///        →  consultation en Studio (mode orientation)
///        →  fiche d'orientation partagée à l'élève
/// ```
///
/// Le dépliage des créneaux — récurrence hebdomadaire moins ce qui est déjà
/// réservé — est fait côté base par `app_orientation_available_slots`. Aucune
/// interface ne doit refaire ce calcul.
class OrientationProvider extends ChangeNotifier {
  final SupabaseClient _client = Supabase.instance.client;

  bool _isLoading = false;
  bool _isBooking = false;
  String? _error;
  bool _isCounselor = false;

  List<Map<String, dynamic>> _counselors = const [];
  List<DateTime> _slots = const [];
  int _slotDuration = 45;
  List<Map<String, dynamic>> _bookings = const [];
  Map<String, dynamic>? _studentFile;
  Map<String, dynamic>? _record;
  String? _recordStatus;
  Map<String, dynamic>? _myProfile;
  List<Map<String, dynamic>> _myAvailability = const [];

  bool get isLoading => _isLoading;
  bool get isBooking => _isBooking;
  String? get error => _error;
  bool get isCounselor => _isCounselor;
  List<Map<String, dynamic>> get counselors => List.unmodifiable(_counselors);
  List<DateTime> get slots => List.unmodifiable(_slots);
  int get slotDuration => _slotDuration;
  List<Map<String, dynamic>> get bookings => List.unmodifiable(_bookings);
  Map<String, dynamic>? get studentFile => _studentFile;
  Map<String, dynamic>? get record => _record;

  /// Pourquoi `record` est nul, quand il l'est : `'absente'` (jamais écrite),
  /// `'en_redaction'` (écrite mais pas encore partagée par le conseiller),
  /// `'erreur'` (appel échoué), `'disponible'` (la fiche est là), ou `null`
  /// tant que rien n'a été chargé. Sans cette distinction, l'écran ne peut que
  /// mentir — voir `loadRecord`.
  String? get recordStatus => _recordStatus;
  Map<String, dynamic>? get myProfile => _myProfile;
  List<Map<String, dynamic>> get myAvailability =>
      List.unmodifiable(_myAvailability);

  /// Un conseiller sans créneau n'apparaît dans aucune recherche d'élève :
  /// son compte existe, mais personne ne peut le réserver.
  bool get isBookable => _myAvailability.isNotEmpty;

  /// Ce qui manque encore au profil pour être présentable aux élèves.
  List<String> get profileGaps {
    final p = _myProfile;
    if (p == null) return const [];
    final gaps = <String>[];
    final specialites = (p['specialites'] as List?) ?? const [];
    if (specialites.isEmpty) gaps.add('Aucune spécialité renseignée');
    if ((p['bio'] ?? '').toString().trim().isEmpty) {
      gaps.add('Aucune présentation');
    }
    if (_myAvailability.isEmpty) gaps.add('Aucun créneau de disponibilité');
    return gaps;
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  void _fail(dynamic res, String fallback) {
    _error = res is Map ? (res['error']?.toString() ?? fallback) : fallback;
  }

  // ─── Recherche ──────────────────────────────────────────────────────

  Future<void> searchCounselors({
    String? kind,
    String? speciality,
    String? langue,
  }) async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      // v2 : mêmes champs que v1, plus `prochains_creneaux`. Afficher les
      // premiers créneaux sur la carte évite un appel par conseiller.
      final res = await _client.rpc(
        'app_orientation_search_counselors_v2',
        params: {
          'p_kind': kind,
          'p_speciality': speciality,
          'p_langue': langue,
          'p_slots': 3,
        },
      );
      if (res is Map<String, dynamic> && res['success'] == true) {
        final data = res['counselors'];
        _counselors = data is List
            ? data.whereType<Map<String, dynamic>>().toList(growable: false)
            : const [];
      } else {
        _fail(res, 'Recherche impossible.');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[Orientation] searchCounselors: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Créneaux ───────────────────────────────────────────────────────

  Future<void> loadSlots(String counselorId, {int days = 14}) async {
    _isLoading = true;
    _error = null;
    _slots = const [];
    notifyListeners();
    try {
      final res = await _client.rpc('app_orientation_available_slots', params: {
        'p_counselor_id': counselorId,
        'p_from': DateTime.now().toIso8601String().substring(0, 10),
        'p_days': days,
      });
      if (res is Map<String, dynamic> && res['success'] == true) {
        _slotDuration = (res['duree_minutes'] as num?)?.toInt() ?? 45;
        final data = res['slots'];
        _slots = data is List
            ? data
                .map((e) => DateTime.tryParse('$e'))
                .whereType<DateTime>()
                .toList(growable: false)
            : const [];
      } else {
        _fail(res, 'Créneaux indisponibles.');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[Orientation] loadSlots: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Réserve un créneau. Retourne l'identifiant de séance, ou `null`.
  ///
  /// La séance du Studio est créée par la base en même temps que le
  /// rendez-vous, avec les capacités du mode orientation : ni quiz, ni
  /// tableau blanc, ni enregistrement.
  Future<String?> book({
    required String counselorId,
    required DateTime slot,
    String? motif,
    Map<String, dynamic>? context,
    bool consentRecording = false,
  }) async {
    _isBooking = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client.rpc('app_orientation_book', params: {
        'p_counselor_id': counselorId,
        'p_scheduled_at': slot.toUtc().toIso8601String(),
        'p_motif': motif,
        'p_context': context ?? <String, dynamic>{},
        'p_consent_recording': consentRecording,
      });
      if (res is Map<String, dynamic> && res['success'] == true) {
        return res['session_id']?.toString();
      }
      _fail(res, 'Réservation impossible.');
      return null;
    } catch (e) {
      _error = e.toString();
      return null;
    } finally {
      _isBooking = false;
      notifyListeners();
    }
  }

  // ─── Mes rendez-vous ────────────────────────────────────────────────

  Future<void> loadMyBookings() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client.rpc('app_orientation_my_bookings');
      if (res is Map<String, dynamic> && res['success'] == true) {
        _isCounselor = res['is_counselor'] == true;
        final data = res['bookings'];
        _bookings = data is List
            ? data.whereType<Map<String, dynamic>>().toList(growable: false)
            : const [];
      } else {
        _fail(res, 'Chargement impossible.');
      }
    } catch (e) {
      _error = e.toString();
      debugPrint('[Orientation] loadMyBookings: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // ─── Mon profil de conseiller ───────────────────────────────────────

  Future<void> loadMyProfile() async {
    try {
      final res = await _client.rpc('app_orientation_get_my_profile');
      if (res is Map<String, dynamic> && res['success'] == true) {
        _isCounselor = res['is_counselor'] == true;
        _myProfile = res['profile'] as Map<String, dynamic>?;
        final av = res['availability'];
        _myAvailability = av is List
            ? av.whereType<Map<String, dynamic>>().toList(growable: false)
            : const [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Orientation] loadMyProfile: $e');
    }
  }

  Future<String?> updateMyProfile({
    String? fullName,
    String? kind,
    List<String>? specialites,
    List<String>? niveaux,
    List<String>? langues,
    String? bio,
    int? tarifFcfa,
    int? dureeMinutes,
  }) async {
    _isBooking = true;
    notifyListeners();
    try {
      final res = await _client.rpc('app_orientation_update_my_profile', params: {
        'p_full_name': fullName,
        'p_kind': kind,
        'p_specialites': specialites,
        'p_niveaux': niveaux,
        'p_langues': langues,
        'p_bio': bio,
        'p_tarif_fcfa': tarifFcfa,
        'p_duree_minutes': dureeMinutes,
      });
      if (res is Map<String, dynamic> && res['success'] == true) {
        await loadMyProfile();
        return null;
      }
      return res is Map ? res['error']?.toString() : 'Enregistrement impossible.';
    } catch (e) {
      return e.toString();
    } finally {
      _isBooking = false;
      notifyListeners();
    }
  }

  /// Remplace l'agenda hebdomadaire complet.
  ///
  /// Chaque plage : `{weekday: 0..6, start_time: 'HH:mm', end_time: 'HH:mm'}`.
  /// La base découpe ensuite ces plages en créneaux de la durée du conseiller
  /// et retire ce qui est déjà réservé — aucun calcul côté application.
  Future<String?> setMyAvailability(List<Map<String, dynamic>> slots) async {
    _isBooking = true;
    notifyListeners();
    try {
      final res = await _client.rpc('app_orientation_set_my_availability',
          params: {'p_slots': slots});
      if (res is Map<String, dynamic> && res['success'] == true) {
        await loadMyProfile();
        return null;
      }
      return res is Map ? res['error']?.toString() : 'Enregistrement impossible.';
    } catch (e) {
      return e.toString();
    } finally {
      _isBooking = false;
      notifyListeners();
    }
  }

  // ─── Revenus, fiches et statistiques ────────────────────────────────

  Map<String, dynamic> _balance = const {};
  Map<String, dynamic> _stats = const {};
  List<Map<String, dynamic>> _records = const [];

  Map<String, dynamic> get balance => Map.unmodifiable(_balance);
  Map<String, dynamic> get stats => Map.unmodifiable(_stats);
  List<Map<String, dynamic>> get records => List.unmodifiable(_records);

  Future<void> loadCounselorWorkspace() async {
    try {
      final results = await Future.wait([
        _client.rpc('app_orientation_get_my_balance'),
        _client.rpc('app_orientation_my_stats'),
        _client.rpc('app_orientation_my_records'),
      ]);

      final b = results[0];
      if (b is Map<String, dynamic> && b['success'] == true) {
        _balance = Map<String, dynamic>.from(b)..remove('success');
      }
      final s = results[1];
      if (s is Map<String, dynamic> && s['success'] == true) {
        _stats = (s['stats'] as Map<String, dynamic>?) ?? const {};
      }
      final r = results[2];
      if (r is Map<String, dynamic> && r['success'] == true) {
        final data = r['records'];
        _records = data is List
            ? data.whereType<Map<String, dynamic>>().toList(growable: false)
            : const [];
      }
      notifyListeners();
    } catch (e) {
      debugPrint('[Orientation] loadCounselorWorkspace: $e');
    }
  }

  Future<String?> requestPayout(String phone) async {
    _isBooking = true;
    notifyListeners();
    try {
      final res = await _client
          .rpc('app_orientation_request_payout', params: {'p_phone': phone});
      if (res is Map<String, dynamic> && res['success'] == true) {
        await loadCounselorWorkspace();
        return null;
      }
      return res is Map ? res['error']?.toString() : 'Demande impossible.';
    } catch (e) {
      return e.toString();
    } finally {
      _isBooking = false;
      notifyListeners();
    }
  }

  /// Clôture une consultation : le rendez-vous passe en « terminé » et la
  /// salle du Studio est fermée. C'est ce qui débloque la rédaction de la
  /// fiche et fait entrer la consultation dans l'historique.
  Future<String?> completeBooking(String bookingId) async {
    try {
      final res = await _client.rpc('app_orientation_complete_booking',
          params: {'p_booking_id': bookingId});
      if (res is Map<String, dynamic> && res['success'] == true) {
        await loadMyBookings();
        await loadCounselorWorkspace();
        return null;
      }
      return res is Map ? res['error']?.toString() : 'Clôture impossible.';
    } catch (e) {
      return e.toString();
    }
  }

  // ─── Dossier de l'élève ─────────────────────────────────────────────

  /// Charge ce que la plateforme sait déjà de l'élève, profil
  /// psychotechnique compris. C'est ce qui permet au conseiller d'arriver
  /// informé plutôt que de commencer par « alors, c'était quoi ta question ? ».
  Future<void> loadStudentFile(String bookingId) async {
    try {
      final res = await _client.rpc('app_orientation_student_file',
          params: {'p_booking_id': bookingId});
      _studentFile = res is Map<String, dynamic> && res['success'] == true
          ? (res['file'] as Map<String, dynamic>?)
          : null;
      notifyListeners();
    } catch (e) {
      debugPrint('[Orientation] loadStudentFile: $e');
    }
  }

  // ─── Fiche d'orientation ────────────────────────────────────────────

  /// Charge la fiche d'un rendez-vous et CONSERVE la raison d'une absence.
  ///
  /// `app_orientation_get_record` distingue trois absences très différentes :
  /// aucune fiche écrite, une fiche que le conseiller n'a pas encore partagée
  /// (`status: 'en_redaction'`), et un refus d'accès. La version précédente ne
  /// gardait que `res['record']` : les trois devenaient un même `null`, et
  /// l'élève n'avait aucun moyen de savoir laquelle. C'est le défaut de famille
  /// du projet — déduire un état d'une absence.
  Future<void> loadRecord(String bookingId) async {
    // Remis à zéro AVANT l'appel : sans cela, ouvrir une fiche puis une autre
    // dont le chargement échoue affichait le contenu de la première.
    _record = null;
    _recordStatus = null;
    notifyListeners();
    try {
      final res = await _client.rpc('app_orientation_get_record',
          params: {'p_booking_id': bookingId});
      if (res is! Map<String, dynamic> || res['success'] != true) {
        _recordStatus = 'erreur';
      } else if (res['record'] is Map) {
        _record = (res['record'] as Map).cast<String, dynamic>();
        _recordStatus = 'disponible';
      } else {
        // `en_redaction` quand le conseiller n'a pas partagé, sinon la fiche
        // n'a simplement jamais été commencée.
        _recordStatus = res['status']?.toString() ?? 'absente';
      }
    } catch (e) {
      debugPrint('[Orientation] loadRecord: $e');
      _recordStatus = 'erreur';
    }
    notifyListeners();
  }

  /// Enregistre la fiche. `share` la rend visible à l'élève.
  Future<String?> saveRecord(
    String bookingId,
    Map<String, dynamic> content, {
    bool share = false,
  }) async {
    try {
      final res = await _client.rpc('app_orientation_upsert_record', params: {
        'p_booking_id': bookingId,
        'p_content': content,
        'p_share': share,
      });
      if (res is Map<String, dynamic> && res['success'] == true) {
        await loadRecord(bookingId);
        return null;
      }
      return res is Map ? res['error']?.toString() : 'Enregistrement impossible.';
    } catch (e) {
      return e.toString();
    }
  }

  // ─── Séances ouvertes par le conseiller lui-même ────────────────────
  //
  // Jusqu'ici une salle n'existait que si un élève avait réservé. Le
  // conseiller peut désormais ouvrir sa propre séance — entretien individuel
  // hors rendez-vous, ou séance collective d'orientation.
  //
  // Le cycle de vie (publier, démarrer, terminer) reste celui du studio
  // commun : `AcademiaSessionProvider` s'appuie sur `host_id`, et le
  // conseiller est l'hôte. Rien n'est dupliqué ici.

  List<Map<String, dynamic>> _mySessions = const [];
  bool _isSavingSession = false;

  List<Map<String, dynamic>> get mySessions => List.unmodifiable(_mySessions);
  bool get isSavingSession => _isSavingSession;

  /// Séances à venir ou en cours, celles qui méritent d'être mises en avant.
  List<Map<String, dynamic>> get upcomingSessions => _mySessions
      .where((s) => s['status'] == 'scheduled' || s['status'] == 'running')
      .toList();

  Future<void> loadMySessions() async {
    try {
      final res = await _client.rpc('app_orientation_my_sessions');
      if (res is Map<String, dynamic> && res['success'] == true) {
        final data = res['sessions'];
        _mySessions = data is List
            ? data
                .whereType<Map>()
                .map((e) => Map<String, dynamic>.from(e))
                .toList()
            : const [];
      } else {
        _fail(res, 'Impossible de charger vos séances.');
      }
    } catch (e) {
      _error = e.toString();
    }
    notifyListeners();
  }

  /// Clôture une séance collective et crédite le conseiller au nombre de
  /// participants réellement entrés. Les rendez-vous se clôturent par
  /// [completeBooking] : deux chemins créditeraient deux fois.
  Future<String?> closeSession(String sessionId) async {
    try {
      final res = await _client.rpc('app_orientation_close_session',
          params: {'p_session_id': sessionId});
      if (res is Map<String, dynamic> && res['success'] == true) {
        await loadMySessions();
        await loadCounselorWorkspace();
        return null;
      }
      return res is Map ? res['error']?.toString() : 'Clôture impossible.';
    } catch (e) {
      return e.toString();
    }
  }

  /// Accord à l'enregistrement. L'enregistrement ne s'active que si le
  /// conseiller et l'élève ont tous deux consenti.
  Future<Map<String, dynamic>?> setRecordingConsent(
      String sessionId, bool consent) async {
    try {
      final res = await _client.rpc('app_orientation_set_recording_consent',
          params: {'p_session_id': sessionId, 'p_consent': consent});
      return res is Map<String, dynamic> ? res : null;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<Map<String, dynamic>?> recordingState(String sessionId) async {
    try {
      final res = await _client.rpc('app_orientation_recording_state',
          params: {'p_session_id': sessionId});
      return res is Map<String, dynamic> ? res : null;
    } catch (_) {
      return null;
    }
  }

  /// Crée ou met à jour une séance. Renvoie `null` si tout s'est bien passé,
  /// sinon le message d'erreur — même convention que le reste du provider.
  Future<String?> saveSession({
    String? sessionId,
    required String titre,
    String? description,
    required String format, // individuelle | collective
    String? theme,
    String? niveau,
    DateTime? scheduledAt,
    int dureeMinutes = 45,
    int? maxPlaces,
    int tarifPlace = 0,
    bool tableau = true,
    bool enregistrement = false,
  }) async {
    _isSavingSession = true;
    _error = null;
    notifyListeners();
    try {
      final res = await _client.rpc('app_orientation_create_session', params: {
        'p_session_id': sessionId,
        'p_titre': titre,
        'p_description': description,
        'p_format': format,
        'p_theme': theme,
        'p_niveau': niveau,
        'p_scheduled_at': scheduledAt?.toUtc().toIso8601String(),
        'p_duree_minutes': dureeMinutes,
        'p_max_places': maxPlaces,
        'p_tarif_place': tarifPlace,
        'p_tableau': tableau,
        'p_enregistrement': enregistrement,
      });
      if (res is Map<String, dynamic> && res['success'] == true) {
        await loadMySessions();
        return null;
      }
      return res is Map
          ? res['error']?.toString() ?? 'Enregistrement impossible.'
          : 'Enregistrement impossible.';
    } catch (e) {
      return e.toString();
    } finally {
      _isSavingSession = false;
      notifyListeners();
    }
  }
}
