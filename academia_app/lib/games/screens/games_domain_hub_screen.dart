import 'package:flutter/material.dart';
import 'auto_record_game_wrapper.dart';
import 'brain_type_game.dart';
import 'speed_challenge_game.dart';
import 'student_type_game.dart';
import 'games_hub_screen.dart';
import 'tournament_list_screen.dart';
import 'leaderboard_screen.dart';
import 'duel_home_screen.dart';
import 'memory_game_screen.dart';
import 'pharmacy_game_screen.dart';
import '../widgets/live_game_feed_card.dart';

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
          // --- En direct maintenant ---
          const LiveGameFeedSection(),
          // --- Duel de Concours : le seul jeu adossé aux matières réellement
          // préparées par les étudiants (147 QCM de concours en base). Placé en
          // tête pour cette raison.
          const _SectionTitle(title: 'Affronter quelqu\'un', icon: Icons.sports_kabaddi, color: Color(0xFF1EA75C)),
          const SizedBox(height: 8),
          _MiniGameCard(
            title: 'Duel de Concours',
            subtitle: 'Cinq questions de concours, un adversaire',
            icon: Icons.flash_on,
            color: const Color(0xFF1EA75C),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const DuelHomeScreen()),
            ),
          ),
          const SizedBox(height: 8),
          // Mémoire éclair : aucune filière requise, aucun contenu à produire.
          // C'est le jeu qui peut s'adresser d'emblée aux 155 programmes.
          _MiniGameCard(
            title: 'Mémoire éclair',
            subtitle: 'Mémorise une suite de chiffres, restitue-la',
            icon: Icons.psychology_alt,
            color: const Color(0xFF2563a8),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const MemoryGameScreen()),
            ),
          ),
          const SizedBox(height: 16),
          // --- Santé : s'adresse aux formations paramédicales du catalogue
          // (auxiliaire de pharmacie, délégué médical).
          const _SectionTitle(title: 'Santé', icon: Icons.local_pharmacy, color: Color(0xFF0D8B8B)),
          const SizedBox(height: 8),
          _MiniGameCard(
            title: 'Le comptoir',
            subtitle: 'Sers les clients d\'une officine sans te tromper',
            icon: Icons.storefront,
            color: const Color(0xFF0D8B8B),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const PharmacyGameScreen()),
            ),
          ),
          const SizedBox(height: 16),
          // --- Défis Rapides (jeux viraux) ---
          const _SectionTitle(title: 'Défis Rapides', icon: Icons.bolt, color: Color(0xFF6C63FF)),
          const SizedBox(height: 8),
          _MiniGameCard(
            title: 'Type de Cerveau',
            subtitle: 'Découvre ton profil cognitif',
            icon: Icons.psychology,
            color: const Color(0xFF6C63FF),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AutoRecordGameWrapper(
                gameType: 'Type de Cerveau',
                child: BrainTypeGameScreen(),
              )),
            ),
          ),
          const SizedBox(height: 8),
          _MiniGameCard(
            title: 'Défi 10 Secondes',
            subtitle: 'Quiz chrono par matière',
            icon: Icons.bolt,
            color: const Color(0xFFE53935),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AutoRecordGameWrapper(
                gameType: 'Défi 10 Secondes',
                child: SpeedChallengeGameScreen(),
              )),
            ),
          ),
          const SizedBox(height: 8),
          _MiniGameCard(
            title: 'Quel Étudiant Es-Tu ?',
            subtitle: 'Ton profil étudiant + conseils',
            icon: Icons.school,
            color: const Color(0xFFFF6B35),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AutoRecordGameWrapper(
                gameType: 'Quel Étudiant Es-Tu',
                child: StudentTypeGameScreen(),
              )),
            ),
          ),
          const SizedBox(height: 16),
          // --- Économie ---
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

class _SectionTitle extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;

  const _SectionTitle({required this.title, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
        ),
      ],
    );
  }
}

class _MiniGameCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _MiniGameCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(subtitle, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text('Jouer', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
