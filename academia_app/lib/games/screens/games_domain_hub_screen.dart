import 'package:flutter/material.dart';
import 'games_hub_screen.dart';
import 'tournament_list_screen.dart';
import 'leaderboard_screen.dart';

/// Hub principal multi-domaines des jeux Academia.
/// Accessible depuis le bouton "Jeux" dans l'onglet Challenge.
class GamesDomainHubScreen extends StatelessWidget {
  const GamesDomainHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Jeux Academia'),
        backgroundColor: const Color(0xFF1EA75C),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.leaderboard),
            tooltip: 'Classement',
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const LeaderboardScreen()),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _DomainCard(
            title: 'Economie',
            subtitle: '4 jeux disponibles',
            icon: Icons.trending_up,
            color: const Color(0xFF1EA75C),
            isAvailable: true,
            chips: const ['Maître du Marché', 'Choix Consommateur', 'Magnat Entreprise', 'Structures Marché'],
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const GamesHubScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _DomainCard(
            title: 'Tournois & Competitions',
            subtitle: 'Défie tes camarades',
            icon: Icons.emoji_events,
            color: Colors.orange,
            isAvailable: true,
            chips: const ['Tournois', 'Ligues'],
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const TournamentListScreen()),
              );
            },
          ),
          const SizedBox(height: 16),
          _DomainCard(
            title: 'Mathematiques',
            subtitle: 'Bientôt disponible',
            icon: Icons.calculate,
            color: Colors.blue,
            isAvailable: false,
            chips: const ['Calcul mental', 'Équations', 'Géométrie'],
            onTap: null,
          ),
          const SizedBox(height: 16),
          _DomainCard(
            title: 'Medecine',
            subtitle: 'Bientôt disponible',
            icon: Icons.local_hospital,
            color: Colors.red,
            isAvailable: false,
            chips: const ['Diagnostic', 'Anatomie', 'Pharmacologie'],
            onTap: null,
          ),
          const SizedBox(height: 16),
          _DomainCard(
            title: 'Sciences',
            subtitle: 'Bientôt disponible',
            icon: Icons.science,
            color: Colors.purple,
            isAvailable: false,
            chips: const ['Physique', 'Chimie', 'Biologie'],
            onTap: null,
          ),
        ],
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool isAvailable;
  final List<String> chips;
  final VoidCallback? onTap;

  const _DomainCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.isAvailable,
    required this.chips,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: isAvailable ? 1.0 : 0.5,
      child: Card(
        elevation: isAvailable ? 3 : 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: isAvailable ? onTap : null,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(icon, color: color, size: 28),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            subtitle,
                            style: TextStyle(
                              fontSize: 13,
                              color: isAvailable ? color : Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (isAvailable)
                      Icon(Icons.chevron_right, color: Colors.grey[400]),
                    if (!isAvailable)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.grey[200],
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Bientôt',
                          style: TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: chips
                      .map(
                        (chip) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: color.withValues(alpha: 0.2)),
                          ),
                          child: Text(
                            chip,
                            style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w500),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
