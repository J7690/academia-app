import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';
import 'auto_record_game_wrapper.dart';
import '../services/game_results_service.dart';

/// Jeu viral "Quel Étudiant Es-Tu ?"
/// 10 questions → 6 profils étudiants → résultat partageable + CTA Academia.
class StudentTypeGameScreen extends StatefulWidget {
  const StudentTypeGameScreen({super.key});

  @override
  State<StudentTypeGameScreen> createState() => _StudentTypeGameScreenState();
}

enum _StudentType { strategist, hardWorker, social, creative, competitor, autodidact }

class _Choice {
  final String text;
  final IconData icon;
  final _StudentType type;
  const _Choice(this.text, this.icon, this.type);
}

class _Question {
  final String question;
  final List<_Choice> choices;
  const _Question(this.question, this.choices);
}

const _questions = <_Question>[
  _Question('Comment tu prépares un examen ?', [
    _Choice('Je fais un planning détaillé', Icons.calendar_month, _StudentType.strategist),
    _Choice('Je révise sans relâche', Icons.local_fire_department, _StudentType.hardWorker),
    _Choice('Je révise en groupe', Icons.groups, _StudentType.social),
  ]),
  _Question('Ton point fort en cours ?', [
    _Choice('L\'analyse et la réflexion', Icons.psychology, _StudentType.strategist),
    _Choice('La persévérance', Icons.fitness_center, _StudentType.hardWorker),
    _Choice('Les présentations orales', Icons.campaign, _StudentType.social),
  ]),
  _Question('Un projet de groupe, tu...', [
    _Choice('Organises et délègues', Icons.task_alt, _StudentType.strategist),
    _Choice('Fais le plus gros du travail', Icons.construction, _StudentType.hardWorker),
    _Choice('Motives l\'équipe', Icons.favorite, _StudentType.social),
  ]),
  _Question('Ton rêve après les études ?', [
    _Choice('Diriger une entreprise', Icons.business_center, _StudentType.strategist),
    _Choice('Être expert reconnu', Icons.workspace_premium, _StudentType.hardWorker),
    _Choice('Créer quelque chose de nouveau', Icons.lightbulb, _StudentType.creative),
  ]),
  _Question('Face à un échec, tu...', [
    _Choice('Analyses ce qui n\'a pas marché', Icons.search, _StudentType.strategist),
    _Choice('Redoubles d\'efforts', Icons.replay, _StudentType.hardWorker),
    _Choice('Cherches une autre voie créative', Icons.palette, _StudentType.creative),
  ]),
  _Question('Ton temps libre, tu...', [
    _Choice('Lis et apprends en solo', Icons.auto_stories, _StudentType.autodidact),
    _Choice('Crées des projets perso', Icons.build, _StudentType.creative),
    _Choice('Participes à des compétitions', Icons.emoji_events, _StudentType.competitor),
  ]),
  _Question('Ce qui te motive le plus ?', [
    _Choice('Être le meilleur', Icons.leaderboard, _StudentType.competitor),
    _Choice('Comprendre en profondeur', Icons.school, _StudentType.autodidact),
    _Choice('L\'ambiance et les gens', Icons.people, _StudentType.social),
  ]),
  _Question('Comment tu apprends une nouvelle compétence ?', [
    _Choice('Tutoriels YouTube seul', Icons.ondemand_video, _StudentType.autodidact),
    _Choice('En compétition avec d\'autres', Icons.sports_score, _StudentType.competitor),
    _Choice('En créant un projet concret', Icons.rocket_launch, _StudentType.creative),
  ]),
  _Question('Ton rapport avec les notes ?', [
    _Choice('C\'est un indicateur stratégique', Icons.analytics, _StudentType.strategist),
    _Choice('Je veux toujours la meilleure', Icons.star, _StudentType.competitor),
    _Choice('Moins important que comprendre', Icons.lightbulb_outline, _StudentType.autodidact),
  ]),
  _Question('Ta qualité principale ?', [
    _Choice('Organisation', Icons.folder, _StudentType.strategist),
    _Choice('Discipline', Icons.alarm, _StudentType.hardWorker),
    _Choice('Curiosité', Icons.explore, _StudentType.autodidact),
  ]),
];

class _StudentTypeGameScreenState extends State<StudentTypeGameScreen> {
  int _currentQ = 0;
  final Map<_StudentType, int> _scores = {
    for (final t in _StudentType.values) t: 0,
  };
  bool _showResult = false;
  late _StudentType _result;
  final GlobalKey _resultKey = GlobalKey();

  void _answer(_StudentType type) {
    _scores[type] = (_scores[type] ?? 0) + 1;
    if (_currentQ + 1 >= _questions.length) {
      _result = _scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      setState(() => _showResult = true);
      GameRecordController.of(context)?.onGameFinished();
      // Conserver la partie. Comme « Type de Cerveau », ce jeu donne un PROFIL :
      // le profil part dans `details`, le score reste neutre.
      GameResultsService.record(
        gameType: 'Quel Étudiant Es-Tu',
        score: 0,
        details: {'profil': _result.name},
      );
    } else {
      setState(() => _currentQ++);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Quel Étudiant Es-Tu ?'),
        backgroundColor: const Color(0xFFFF6B35),
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: _showResult ? _buildResult() : _buildQuestion(),
      ),
    );
  }

  Widget _buildQuestion() {
    final q = _questions[_currentQ];
    final progress = (_currentQ + 1) / _questions.length;

    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth < 380 || constraints.maxHeight < 650;
      final titleFs = isSmall ? 16.0 : 20.0;
      final choiceFs = isSmall ? 13.0 : 15.0;
      final pad = isSmall ? 12.0 : 20.0;

      return SingleChildScrollView(
        padding: EdgeInsets.all(pad),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: progress, minHeight: 6,
                backgroundColor: Colors.grey[200],
                color: const Color(0xFFFF6B35),
              ),
            ),
            SizedBox(height: isSmall ? 4 : 8),
            Text(
              'Question ${_currentQ + 1}/${_questions.length}',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
            SizedBox(height: isSmall ? 12 : 24),
            Text(
              q.question,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: titleFs, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: isSmall ? 16 : 28),
            ...q.choices.map((c) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Material(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                elevation: 1,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => _answer(c.type),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: pad, vertical: isSmall ? 12 : 16),
                    child: Row(
                      children: [
                        Icon(c.icon, color: const Color(0xFFFF6B35), size: 24),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Text(c.text, style: TextStyle(fontSize: choiceFs, fontWeight: FontWeight.w500)),
                        ),
                        const Icon(Icons.chevron_right, color: Colors.grey, size: 20),
                      ],
                    ),
                  ),
                ),
              ),
            )),
          ],
        ),
      );
    });
  }

  Widget _buildResult() {
    final p = _profileData(_result);
    final pct = ((_scores[_result] ?? 0) / _questions.length * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          RepaintBoundary(
            key: _resultKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [p.color, p.color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(p.icon, size: 52, color: Colors.white),
                  const SizedBox(height: 10),
                  Text('Tu es', style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85))),
                  const SizedBox(height: 4),
                  Text(p.title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.white)),
                  const SizedBox(height: 8),
                  Text('$pct% de correspondance', style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8))),
                  const SizedBox(height: 14),
                  _chip(p.description),
                  const SizedBox(height: 6),
                  _chip('Conseil : ${p.advice}'),
                  const SizedBox(height: 10),
                  Text('Academia', style: TextStyle(fontSize: 11, color: Colors.white.withValues(alpha: 0.5), fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // CTA Academia
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: p.color.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.color.withValues(alpha: 0.2)),
            ),
            child: Column(
              children: [
                Text(p.ctaTitle, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                const SizedBox(height: 4),
                Text(p.ctaDesc, textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: Colors.grey[700])),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareResult,
              icon: const Icon(Icons.share, size: 20),
              label: const Text('Partager mon profil'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _replay,
              icon: const Icon(Icons.replay, size: 20),
              label: const Text('Rejouer'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(text, style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.3)),
    );
  }

  Future<void> _shareResult() async {
    try {
      final boundary = _resultKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 2.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (byteData == null) return;
      final bytes = byteData.buffer.asUint8List();
      final xFile = XFile.fromData(bytes, mimeType: 'image/png', name: 'quel_etudiant_academia.png');
      final p = _profileData(_result);
      await Share.shareXFiles(
        [xFile],
        text: 'Je suis ${p.title} ! Et toi, quel étudiant es-tu ? '
            'Découvre-le sur Academia 🎓🔥',
        subject: 'Quel Étudiant Es-Tu - Academia',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  void _replay() {
    setState(() {
      _currentQ = 0;
      _scores.updateAll((_, __) => 0);
      _showResult = false;
    });
  }
}

class _ProfileData {
  final String title;
  final IconData icon;
  final Color color;
  final String description;
  final String advice;
  final String ctaTitle;
  final String ctaDesc;
  const _ProfileData({
    required this.title, required this.icon, required this.color,
    required this.description, required this.advice,
    required this.ctaTitle, required this.ctaDesc,
  });
}

_ProfileData _profileData(_StudentType type) {
  switch (type) {
    case _StudentType.strategist:
      return const _ProfileData(
        title: 'LE STRATÈGE', icon: Icons.psychology, color: Color(0xFF1565C0),
        description: 'Tu planifies tout, analyses avant d\'agir et optimises ton temps.',
        advice: 'Utilise des outils de planification et des mind maps pour exceller.',
        ctaTitle: 'Sur Academia pour toi', ctaDesc: 'Les TD organisés et la préparation concours structurée.',
      );
    case _StudentType.hardWorker:
      return const _ProfileData(
        title: 'LE BOSSEUR', icon: Icons.local_fire_department, color: Color(0xFFE65100),
        description: 'Tu ne lâches jamais, ta discipline est ta plus grande force.',
        advice: 'Prends des pauses stratégiques pour éviter le burnout.',
        ctaTitle: 'Sur Academia pour toi', ctaDesc: 'Les exercices intensifs et les quiz de révision.',
      );
    case _StudentType.social:
      return const _ProfileData(
        title: 'LE SOCIAL', icon: Icons.people, color: Color(0xFF00897B),
        description: 'Tu brilles en groupe, tu motives les autres et tu apprends en échangeant.',
        advice: 'Rejoins des groupes d\'étude et participe aux lives.',
        ctaTitle: 'Sur Academia pour toi', ctaDesc: 'Les communautés étudiantes et les TD en groupe.',
      );
    case _StudentType.creative:
      return const _ProfileData(
        title: 'LE CRÉATIF', icon: Icons.lightbulb, color: Color(0xFFAD1457),
        description: 'Tu trouves toujours des solutions originales et tu penses différemment.',
        advice: 'Transforme tes idées en projets concrets pour les valoriser.',
        ctaTitle: 'Sur Academia pour toi', ctaDesc: 'Les challenges créatifs et les projets vidéo.',
      );
    case _StudentType.competitor:
      return const _ProfileData(
        title: 'LE COMPÉTITEUR', icon: Icons.emoji_events, color: Color(0xFFFF6F00),
        description: 'Tu veux être le meilleur, les classements te motivent à fond.',
        advice: 'Fixe-toi des objectifs mesurables et participe aux tournois.',
        ctaTitle: 'Sur Academia pour toi', ctaDesc: 'Les défis chronométrés et les leaderboards.',
      );
    case _StudentType.autodidact:
      return const _ProfileData(
        title: 'L\'AUTODIDACTE', icon: Icons.explore, color: Color(0xFF4527A0),
        description: 'Tu apprends seul, par curiosité, tu n\'attends pas qu\'on te dise quoi faire.',
        advice: 'Structure tes apprentissages pour aller encore plus loin.',
        ctaTitle: 'Sur Academia pour toi', ctaDesc: 'Les cours en ligne et les fiches de révision autonome.',
      );
  }
}
