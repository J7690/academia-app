import 'package:flutter/material.dart';

import '../manager/manager_team_tab.dart';
import '../manager/manager_announcements_tab.dart';
import '../manager/manager_media_tab.dart';
import '../manager/manager_campaigns_tab.dart';
import 'admin_managers_tab.dart';

/// Miroir admin de l'espace Manager — portée GLOBALE.
///
/// L'admin voit et pilote la coordination commerciale exactement comme un
/// manager, mais sur l'ensemble des commerciaux (les RPC sous-jacentes
/// détectent le rôle admin et élargissent automatiquement le périmètre).
/// C'est la « délégation » : l'admin garde la main partout, le manager gère
/// son équipe.
class AdminCommercialCoordinationScreen extends StatelessWidget {
  const AdminCommercialCoordinationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Column(
        children: [
          const TabBar(
            isScrollable: true,
            labelColor: Colors.indigo,
            unselectedLabelColor: Colors.grey,
            tabs: [
              Tab(icon: Icon(Icons.manage_accounts), text: 'Managers'),
              Tab(icon: Icon(Icons.groups), text: 'Commerciaux'),
              Tab(icon: Icon(Icons.campaign), text: 'Coordination'),
              Tab(icon: Icon(Icons.perm_media), text: 'Médiathèque'),
              Tab(icon: Icon(Icons.stacked_bar_chart), text: 'Campagnes'),
            ],
          ),
          const Expanded(
            child: TabBarView(
              children: [
                AdminManagersTab(),
                ManagerTeamTab(),
                ManagerAnnouncementsTab(isAdmin: true),
                ManagerMediaTab(isAdmin: true),
                ManagerCampaignsTab(isAdmin: true),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
