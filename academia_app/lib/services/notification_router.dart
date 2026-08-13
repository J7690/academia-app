import 'dart:async';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app_navigator.dart';

import '../features/admin/admin_applications_screen.dart';
import '../features/admin/admin_audience_screen.dart';
import '../features/commercial/commercial_manager_info_screen.dart';
import '../features/admin/admin_challenges_screen.dart';
import '../features/admin/admin_communities_screen.dart';
import '../features/admin/admin_dashboard_screen.dart';
import '../features/admin/admin_marketplace_control_tower_screen.dart';
import '../features/admin/admin_opportunities_screen.dart';
import '../features/admin/admin_payments_screen.dart';
import '../features/admin/admin_support_screen.dart';
import '../features/commercial/commercial_dashboard_screen.dart';
import '../features/instructor/instructor_dashboard_screen.dart';
import '../features/live/session_summary_screen.dart';
import '../features/student/student_dashboard_screen.dart';
import '../features/student/student_payments_screen.dart';
import '../features/university/university_applications_screen.dart';
import '../features/university/university_dashboard_screen.dart';
import '../features/university/university_payments_screen.dart';

/// Routeur central « clic sur notification → écran concerné » (phase N1).
///
/// Reçoit le `data` d'un message FCM (qui contient toujours `domain` et
/// `event_type`, plus les identifiants du payload) et pousse l'écran
/// correspondant via la clé de navigation globale.
///
/// Robustesse :
/// - si l'app démarre (navigator pas prêt) ou si l'utilisateur n'est pas
///   encore authentifié, la route est mise en attente et rejouée (retries) ;
/// - domaine inconnu → aucun crash, l'app s'ouvre normalement ;
/// - le domaine `student_applications` est laissé au mécanisme historique
///   (AuthWrapper -> StudentDashboard initialApplicationId) pour ne pas
///   régresser un flux qui fonctionne déjà.
class NotificationRouter {
  NotificationRouter._();

  static Map<String, String>? _pending;
  static Timer? _retryTimer;
  static int _retryCount = 0;
  static const int _maxRetries = 15;

  /// Point d'entrée : à appeler avec `message.data`.
  static void open(Map<String, dynamic> data) {
    final domain = data['domain']?.toString() ?? '';
    if (domain.isEmpty) return;

    // Flux historique conservé tel quel (géré par PushNotificationService).
    if (domain == 'student_applications') return;

    _pending = data.map((k, v) => MapEntry(k, v?.toString() ?? ''));
    _retryCount = 0;
    _tryNavigate();
  }

  static void _tryNavigate() {
    _retryTimer?.cancel();

    final data = _pending;
    if (data == null) return;

    final navigator = AppNavigator.key.currentState;
    final session = Supabase.instance.client.auth.currentSession;

    if (navigator == null || session == null) {
      // App en cours de démarrage ou utilisateur pas encore connecté :
      // on réessaie (la route sera rejouée après l'authentification).
      if (_retryCount >= _maxRetries) {
        debugPrint('[NotifRouter] abandon après $_maxRetries tentatives');
        _pending = null;
        return;
      }
      _retryCount++;
      _retryTimer = Timer(const Duration(seconds: 2), _tryNavigate);
      return;
    }

    _pending = null;
    final domain = data['domain'] ?? '';
    final screen = _screenForData(data) ?? _screenForDomain(domain);
    if (screen == null) {
      debugPrint('[NotifRouter] domaine sans destination: $domain');
      return;
    }

    debugPrint('[NotifRouter] navigation -> $domain');
    try {
      navigator.push(MaterialPageRoute(builder: (_) => screen));
    } catch (e) {
      debugPrint('[NotifRouter] navigation error: $e');
    }
  }

  /// Table de correspondance domaine → écran.
  /// Écrans vérifiés : constructeurs const sans argument obligatoire.
  static Widget? _screenForDomain(String domain) {
    switch (domain) {
      // --- Étudiant ---
      case 'student_payments':
        return const StudentPaymentsScreen();

      // --- Admin (écrans dédiés) ---
      case 'admin_payments':
        return const AdminPaymentsScreen();
      case 'admin_applications':
        return const AdminApplicationsScreen();
      case 'admin_support':
        return const AdminSupportScreen();
      case 'admin_communities':
        return const AdminCommunitiesScreen();
      case 'admin_marketplace':
        return const AdminMarketplaceControlTowerScreen();
      case 'admin_challenges':
        return const AdminChallengesScreen();
      case 'admin_opportunities':
        return const AdminOpportunitiesScreen();
      case 'admin_audience':
        return Scaffold(
          appBar: AppBar(title: const Text('Audience — parcours utilisateurs')),
          body: const AdminAudienceScreen(),
        );

      // --- Université (écrans dédiés) ---
      case 'university_applications':
        return const UniversityApplicationsScreen();
      case 'university_payments':
        return const UniversityPaymentsScreen();
    }

    // Diffusion manager/admin -> espace commercial (infos + médiathèque).
    if (domain == 'commercial_broadcast') {
      return const CommercialManagerInfoScreen();
    }

    // --- Fallbacks par rôle (couvre tous les autres domaines) ---
    if (domain.startsWith('commercial_')) {
      return const CommercialDashboardScreen();
    }
    if (domain.startsWith('instructor_')) {
      return const InstructorDashboardScreen();
    }
    if (domain.startsWith('university_')) {
      return const UniversityDashboardScreen();
    }
    if (domain.startsWith('admin_')) {
      return const AdminDashboardScreen();
    }
    if (domain.startsWith('student_')) {
      return const StudentDashboardScreen();
    }
    return null;
  }
}
