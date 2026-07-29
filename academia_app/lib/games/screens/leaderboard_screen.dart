import 'package:flutter/material.dart';

import '../services/game_results_service.dart';
import '../utils/game_constants.dart';

/// Classement des joueurs.
///
/// Remplace (29/07/2026) un écran qui annonçait « Leaderboard Coming Soon » :
/// il ne pouvait rien afficher puisque aucune partie n'était enregistrée. Les
/// parties sont désormais conservées (`game_results`), et ce classement retient
/// le MEILLEUR score de chaque joueur — pas le cumul, pour qu'enchaîner les
/// parties ne suffise pas à dépasser un meilleur joueur.
class LeaderboardScreen extends StatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  State<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends State<LeaderboardScreen> {
  static const _periodes = <String, String>{
    'day': 'Aujourd\'hui',
    'week': 'Cette semaine',
    'month': 'Ce mois',
    'all': 'Depuis toujours',
  };

  /// `null` = tous les jeux confondus.
  static const _jeux = <String?>[
    null,
    GameConstants.marketMaster,
    GameConstants.consumerChoice,
    GameConstants.firmTycoon,
    GameConstants.marketStructures,
    'Défi 10 Secondes',
  ];

  String _periode = 'week';
  String? _jeu;
  late Future<List<Map<String, dynamic>>> _classement;

  @override
  void initState() {
    super.initState();
    _classement = _charger();
  }

  Future<List<Map<String, dynamic>>> _charger() {
    return GameResultsService.leaderboard(gameType: _jeu, period: _periode);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Classement'),
        backgroundColor: const Color(0xFF1EA75C),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          _filtres(),
          const Divider(height: 1),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async {
                setState(() => _classement = _charger());
                await _classement;
              },
              child: FutureBuilder<List<Map<String, dynamic>>>(
                future: _classement,
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final lignes = snap.data ?? const <Map<String, dynamic>>[];
                  if (lignes.isEmpty) return _vide();
                  return ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: lignes.length,
                    separatorBuilder: (_, __) =>
                        const Divider(height: 1, indent: 68),
                    itemBuilder: (_, i) => _ligne(lignes[i]),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _filtres() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _periodes.entries.map((e) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(e.value),
                    selected: e.key == _periode,
                    onSelected: (_) => setState(() {
                      _periode = e.key;
                      _classement = _charger();
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _jeux.map((g) {
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(g ?? 'Tous les jeux'),
                    selected: g == _jeu,
                    onSelected: (_) => setState(() {
                      _jeu = g;
                      _classement = _charger();
                    }),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  /// Une liste vide n'est pas une erreur : c'est le cas normal tant que personne
  /// n'a joué sur la période choisie. On le dit, et on propose la seule action
  /// utile. Reste défilable pour que « tirer pour rafraîchir » fonctionne.
  Widget _vide() {
    return ListView(
      children: [
        const SizedBox(height: 80),
        Icon(Icons.emoji_events_outlined, size: 64, color: Colors.grey.shade400),
        const SizedBox(height: 16),
        const Center(
          child: Text(
            'Personne n\'a encore joué ici',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 6),
        Center(
          child: Text(
            'Lance une partie : ton score ouvrira le classement.',
            style: TextStyle(color: Colors.grey.shade600),
          ),
        ),
        const SizedBox(height: 20),
        Center(
          child: OutlinedButton.icon(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.sports_esports),
            label: const Text('Choisir un jeu'),
          ),
        ),
      ],
    );
  }

  Widget _ligne(Map<String, dynamic> l) {
    final rang = l['rank'] is int ? l['rank'] as int : 0;
    final moi = l['is_me'] == true;
    final nom = (l['player_name'] ?? 'Joueur').toString();
    final score = l['score'] is int ? l['score'] as int : 0;
    final parties = l['games_played'] is int ? l['games_played'] as int : 0;

    return Container(
      color: moi ? const Color(0xFF1EA75C).withValues(alpha: 0.08) : null,
      child: ListTile(
        leading: _medaille(rang),
        title: Text(
          moi ? '$nom (toi)' : nom,
          style: TextStyle(fontWeight: moi ? FontWeight.w700 : FontWeight.w500),
        ),
        subtitle: Text('$parties ${parties > 1 ? 'parties' : 'partie'}'),
        trailing: Text(
          '$score',
          style: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }

  /// Les trois premiers sont distingués ; au-delà, le numéro suffit.
  Widget _medaille(int rang) {
    const couleurs = <int, Color>{
      1: Color(0xFFD4AF37),
      2: Color(0xFF9EA7AD),
      3: Color(0xFFB07A3C),
    };
    final couleur = couleurs[rang];
    return Container(
      width: 40,
      height: 40,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: (couleur ?? Colors.grey.shade300)
            .withValues(alpha: couleur != null ? 0.18 : 0.5),
      ),
      child: Text(
        '$rang',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: couleur ?? Colors.grey.shade700,
        ),
      ),
    );
  }
}
