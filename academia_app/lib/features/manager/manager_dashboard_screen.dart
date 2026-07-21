import 'package:flutter/material.dart';

import '../../services/analytics_tracking_service.dart';
import '../student/student_settings_screen.dart';
import 'manager_team_tab.dart';
import 'manager_announcements_tab.dart';
import 'manager_media_tab.dart';
import 'manager_campaigns_tab.dart';

/// Tableau de bord du rôle Manager — délégation du pilotage commercial.
///
/// Le Manager coordonne son équipe de commerciaux :
///  - Mon équipe / Statistiques (M1/M2)
///  - Coordination : diffusions notifiées aux commerciaux (M3)
///  - Médiathèque : visuels/affiches/vidéos mis à disposition (M4)
///  - Campagnes de communication (M5)
///
/// Les mêmes écrans servent à l'admin (portée globale) via le dashboard admin.
class ManagerDashboardScreen extends StatefulWidget {
  const ManagerDashboardScreen({super.key});

  @override
  State<ManagerDashboardScreen> createState() => _ManagerDashboardScreenState();
}

class _ManagerDashboardScreenState extends State<ManagerDashboardScreen> {
  @override
  void initState() {
    super.initState();
    AnalyticsTrackingService.instance.init();
    AnalyticsTrackingService.instance.trackScreen('manager_dashboard');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Espace Manager'),
          actions: [
            IconButton(
              icon: const Icon(Icons.settings),
              tooltip: 'Paramètres',
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    // Même écran que l'étudiant : déconnexion + suppression de
                    // compte (conformité Play Store). Pas de profil étudiant.
                    builder: (_) => const StudentSettingsScreen(showProfile: false),
                  ),
                );
              },
            ),
          ],
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(icon: Icon(Icons.groups), text: 'Mon équipe'),
              Tab(icon: Icon(Icons.campaign), text: 'Coordination'),
              Tab(icon: Icon(Icons.perm_media), text: 'Médiathèque'),
              Tab(icon: Icon(Icons.stacked_bar_chart), text: 'Campagnes'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            ManagerTeamTab(),
            ManagerAnnouncementsTab(isAdmin: false),
            ManagerMediaTab(isAdmin: false),
            ManagerCampaignsTab(isAdmin: false),
          ],
        ),
      ),
    );
  }
}
