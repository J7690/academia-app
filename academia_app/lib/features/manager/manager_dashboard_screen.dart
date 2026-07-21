import 'package:flutter/material.dart';

import '../../services/analytics_tracking_service.dart';

/// Tableau de bord du rôle Manager (M0 — squelette).
///
/// Le Manager encadre une équipe de commerciaux. Les fonctionnalités
/// arrivent par phases :
///  - M1 : création de comptes commerciaux rattachés
///  - M2 : suivi statistiques de l'équipe (lecture des taux)
///  - M3 : messagerie manager ↔ commerciaux
///  - M4 : médiathèque sécurisée (visuels partenaires)
///  - M5 : campagnes de communication
///
/// Cet écran pose la structure en onglets ; chaque onglet affiche un
/// état « à venir » tant que sa phase n'est pas livrée, ce qui permet de
/// livrer et tester le rôle progressivement sans casser la navigation.
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
    const tabs = <_ManagerTab>[
      _ManagerTab('Mon équipe', Icons.groups, 'M1',
          'Créer et gérer vos commerciaux'),
      _ManagerTab('Statistiques', Icons.bar_chart, 'M2',
          'Suivre les performances de votre équipe'),
      _ManagerTab('Messages', Icons.chat_bubble, 'M3',
          'Échanger avec vos commerciaux'),
      _ManagerTab('Médiathèque', Icons.perm_media, 'M4',
          'Mettre à disposition visuels, affiches et vidéos'),
      _ManagerTab('Campagnes', Icons.campaign, 'M5',
          'Coordonner les campagnes de communication'),
    ];

    return DefaultTabController(
      length: tabs.length,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Espace Manager'),
          bottom: TabBar(
            isScrollable: true,
            tabs: [
              for (final t in tabs) Tab(icon: Icon(t.icon), text: t.label),
            ],
          ),
        ),
        body: TabBarView(
          children: [for (final t in tabs) _ComingSoon(tab: t)],
        ),
      ),
    );
  }
}

class _ManagerTab {
  final String label;
  final IconData icon;
  final String phase;
  final String subtitle;
  const _ManagerTab(this.label, this.icon, this.phase, this.subtitle);
}

class _ComingSoon extends StatelessWidget {
  final _ManagerTab tab;
  const _ComingSoon({required this.tab});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(tab.icon, size: 56, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            Text(tab.label,
                style: const TextStyle(
                    fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(tab.subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 16),
            Chip(
              label: Text('Bientôt disponible · ${tab.phase}'),
              backgroundColor: Colors.indigo.shade50,
            ),
          ],
        ),
      ),
    );
  }
}
