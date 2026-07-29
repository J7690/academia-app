import 'package:flutter/material.dart';

import '../services/duel_service.dart';
import 'duel_play_screen.dart';

/// Accueil du Duel de Concours.
///
/// Deux entrées : relever un défi déjà lancé par quelqu'un (on affronte
/// directement son score), ou en lancer un sur la matière de son choix.
class DuelHomeScreen extends StatefulWidget {
  const DuelHomeScreen({super.key});

  @override
  State<DuelHomeScreen> createState() => _DuelHomeScreenState();
}

class _DuelHomeScreenState extends State<DuelHomeScreen> {
  static const _vert = Color(0xFF1EA75C);

  late Future<_Accueil> _donnees;
  bool _lancement = false;

  @override
  void initState() {
    super.initState();
    _donnees = _charger();
  }

  Future<_Accueil> _charger() async {
    final resultats = await Future.wait([
      DuelService.subjects(),
      DuelService.openDuels(),
      DuelService.myHistory(),
    ]);
    return _Accueil(
      matieres: resultats[0] as List<DuelSubject>,
      defisOuverts: resultats[1] as List<Map<String, dynamic>>,
      historique: resultats[2] as List<Map<String, dynamic>>,
    );
  }

  void _rafraichir() => setState(() => _donnees = _charger());

  Future<void> _lancer({String? matiere}) async {
    if (_lancement) return;
    setState(() => _lancement = true);
    final manche = await DuelService.start(subject: matiere);
    if (!mounted) return;
    setState(() => _lancement = false);

    if (manche == null || manche.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pas assez de questions dans cette matière pour le moment.')),
      );
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DuelPlayScreen(round: manche)),
    );
    if (mounted) _rafraichir();
  }

  Future<void> _relever(String duelId) async {
    if (_lancement) return;
    setState(() => _lancement = true);
    final manche = await DuelService.join(duelId);
    if (!mounted) return;
    setState(() => _lancement = false);

    if (manche == null || manche.questions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Ce défi vient d\'être relevé par quelqu\'un d\'autre.')),
      );
      _rafraichir();
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => DuelPlayScreen(round: manche)),
    );
    if (mounted) _rafraichir();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Duel de Concours'),
        backgroundColor: _vert,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<_Accueil>(
        future: _donnees,
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: _vert));
          }
          final d = snap.data;
          if (d == null) {
            return _messageCentre(
              'Impossible de charger les duels.',
              'Vérifie ta connexion puis réessaie.',
            );
          }
          if (d.matieres.isEmpty) {
            return _messageCentre(
              'Aucune matière disponible',
              'Il faut au moins cinq questions publiées dans une matière pour ouvrir un duel.',
            );
          }

          return RefreshIndicator(
            onRefresh: () async => _rafraichir(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (d.defisOuverts.isNotEmpty) ...[
                  const _Titre('Défis à relever'),
                  const SizedBox(height: 8),
                  ...d.defisOuverts.map(_carteDefi),
                  const SizedBox(height: 22),
                ],
                const _Titre('Lancer un duel'),
                const SizedBox(height: 4),
                const Text(
                  'Cinq questions. Ton adversaire répondra exactement aux mêmes.',
                  style: TextStyle(color: Colors.black54, fontSize: 13.5),
                ),
                const SizedBox(height: 10),
                _carteMatiere(
                  titre: 'Toutes matières',
                  sousTitre: 'Tirage au sort dans les ${d.totalQuestions} questions',
                  onTap: () => _lancer(),
                  vedette: true,
                ),
                ...d.matieres.map(
                  (m) => _carteMatiere(
                    titre: m.name,
                    sousTitre: '${m.questionCount} questions disponibles',
                    onTap: () => _lancer(matiere: m.name),
                  ),
                ),
                if (d.historique.isNotEmpty) ...[
                  const SizedBox(height: 22),
                  const _Titre('Mes duels'),
                  const SizedBox(height: 8),
                  ...d.historique.take(10).map(_ligneHistorique),
                ],
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _messageCentre(String titre, String detail) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.sports_kabaddi, size: 56, color: Colors.grey.shade400),
              const SizedBox(height: 14),
              Text(titre,
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                  textAlign: TextAlign.center),
              const SizedBox(height: 6),
              Text(detail,
                  style: TextStyle(color: Colors.grey.shade600),
                  textAlign: TextAlign.center),
            ],
          ),
        ),
      );

  Widget _carteDefi(Map<String, dynamic> d) {
    final nom = d['creator_name']?.toString() ?? 'Un étudiant';
    final matiere = d['subject']?.toString() ?? 'Toutes matières';
    final score = d['creator_score'];
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _vert.withValues(alpha: 0.15),
          child: const Icon(Icons.flash_on, color: _vert),
        ),
        title: Text(nom, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          score is int ? '$matiere · a fait $score / 5' : matiere,
        ),
        trailing: TextButton(
          onPressed: _lancement ? null : () => _relever(d['duel_id']?.toString() ?? ''),
          child: const Text('Relever'),
        ),
      ),
    );
  }

  Widget _carteMatiere({
    required String titre,
    required String sousTitre,
    required VoidCallback onTap,
    bool vedette = false,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: vedette ? 2 : 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: vedette ? const BorderSide(color: _vert, width: 1.5) : BorderSide.none,
      ),
      child: ListTile(
        onTap: _lancement ? null : onTap,
        leading: Icon(
          vedette ? Icons.shuffle : Icons.menu_book_outlined,
          color: vedette ? _vert : Colors.black45,
        ),
        title: Text(titre, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(sousTitre),
        trailing: const Icon(Icons.chevron_right),
      ),
    );
  }

  Widget _ligneHistorique(Map<String, dynamic> d) {
    final termine = d['status']?.toString() == 'completed';
    final gagne = d['is_winner'] == true;
    final mien = d['my_score'];
    final sien = d['their_score'];

    final (IconData icone, Color couleur, String etat) = !termine
        ? (Icons.hourglass_empty, const Color(0xFF2D9CDB), 'En attente')
        : gagne
            ? (Icons.emoji_events, _vert, 'Gagné')
            : (Icons.close, const Color(0xFFB23A2B), 'Perdu');

    return ListTile(
      dense: true,
      leading: Icon(icone, color: couleur, size: 22),
      title: Text(d['subject']?.toString() ?? '—'),
      subtitle: Text(d['opponent_name']?.toString() ?? '—'),
      trailing: Text(
        termine && mien is int && sien is int ? '$mien — $sien' : etat,
        style: TextStyle(color: couleur, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _Accueil {
  const _Accueil({
    required this.matieres,
    required this.defisOuverts,
    required this.historique,
  });

  final List<DuelSubject> matieres;
  final List<Map<String, dynamic>> defisOuverts;
  final List<Map<String, dynamic>> historique;

  int get totalQuestions =>
      matieres.fold<int>(0, (somme, m) => somme + m.questionCount);
}

class _Titre extends StatelessWidget {
  const _Titre(this.texte);
  final String texte;

  @override
  Widget build(BuildContext context) => Text(
        texte,
        style: const TextStyle(fontSize: 16.5, fontWeight: FontWeight.w700),
      );
}
