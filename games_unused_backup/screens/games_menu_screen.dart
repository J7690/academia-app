import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class GamesMenuScreen extends StatelessWidget {
  const GamesMenuScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Economia Challenge')),
      body: GridView.count(
        crossAxisCount: 2,
        padding: EdgeInsets.all(16),
        children: [
          _GameCard(
            title: 'Market Master',
            subtitle: 'Offre & Demande',
            icon: Icons.trending_up,
            onTap: () => context.go('/games/market_master'),
          ),
          _GameCard(
            title: 'Consumer Choice',
            subtitle: 'Théorie Consommateur',
            icon: Icons.person,
            onTap: () => context.go('/games/consumer_choice'),
          ),
          _GameCard(
            title: 'Firm Tycoon',
            subtitle: 'Gestion Entreprise',
            icon: Icons.business,
            onTap: () => context.go('/games/firm_tycoon'),
          ),
          _GameCard(
            title: 'Market Structures',
            subtitle: 'Structures Marché',
            icon: Icons.account_tree,
            onTap: () => context.go('/games/market_structures'),
          ),
          _GameCard(
            title: 'Multiplayer Battle',
            subtitle: '1v1 Temps Réel',
            icon: Icons.people,
            onTap: () => context.go('/multiplayer'),
          ),
          _GameCard(
            title: 'Tournaments',
            subtitle: 'Compétitions',
            icon: Icons.emoji_events,
            onTap: () => context.go('/tournaments'),
          ),
          _GameCard(
            title: 'Leaderboard',
            subtitle: 'Classements',
            icon: Icons.leaderboard,
            onTap: () => context.go('/leaderboard'),
          ),
          _GameCard(
            title: 'Practice',
            subtitle: 'Entraînement',
            icon: Icons.school,
            onTap: () => context.go('/games/practice'),
          ),
        ],
      ),
    );
  }
}

class _GameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _GameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      margin: EdgeInsets.all(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 48,
                color: Theme.of(context).primaryColor,
              ),
              SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: 8),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
