import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'auto_record_game_wrapper.dart';
import '../services/game_results_service.dart';

/// Jeu viral "Découvre ton Type de Cerveau"
/// 8 questions → 4 profils (Visuel, Auditif, Kinesthésique, Analytique)
/// Résultat partageable avec CTA Academia.
class BrainTypeGameScreen extends StatefulWidget {
  const BrainTypeGameScreen({super.key});

  @override
  State<BrainTypeGameScreen> createState() => _BrainTypeGameScreenState();
}

enum _BrainType { visual, auditory, kinesthetic, analytical }

class _Choice {
  final String text;
  final IconData icon;
  final _BrainType type;
  const _Choice(this.text, this.icon, this.type);
}

class _Question {
  final String question;
  final List<_Choice> choices;
  const _Question(this.question, this.choices);
}

const _questions = <_Question>[
  _Question('Tu retiens mieux avec...', [
    _Choice('Des images et schémas', Icons.image, _BrainType.visual),
    _Choice('Des explications orales', Icons.headphones, _BrainType.auditory),
    _Choice('La pratique et le geste', Icons.pan_tool, _BrainType.kinesthetic),
    _Choice('Des listes et tableaux', Icons.table_chart, _BrainType.analytical),
  ]),
  _Question('Devant un problème complexe, tu...', [
    _Choice('Dessines un schéma', Icons.draw, _BrainType.visual),
    _Choice('En parles à quelqu\'un', Icons.chat, _BrainType.auditory),
    _Choice('Essayes directement', Icons.rocket_launch, _BrainType.kinesthetic),
    _Choice('Analyses étape par étape', Icons.checklist, _BrainType.analytical),
  ]),
  _Question('Ton style de révision préféré ?', [
    _Choice('Vidéos et mind maps', Icons.ondemand_video, _BrainType.visual),
    _Choice('Podcasts et discussions', Icons.mic, _BrainType.auditory),
    _Choice('Exercices pratiques', Icons.fitness_center, _BrainType.kinesthetic),
    _Choice('Fiches résumées', Icons.note_alt, _BrainType.analytical),
  ]),
  _Question('En cours, tu es plus attentif quand...', [
    _Choice('Le prof utilise le tableau', Icons.tv, _BrainType.visual),
    _Choice('Le prof explique bien', Icons.record_voice_over, _BrainType.auditory),
    _Choice('Il y a des TP/travaux', Icons.build, _BrainType.kinesthetic),
    _Choice('Il y a des données chiffrées', Icons.analytics, _BrainType.analytical),
  ]),
  _Question('Quand tu lis, tu...', [
    _Choice('Visualises les scènes', Icons.visibility, _BrainType.visual),
    _Choice('Lis à voix haute', Icons.volume_up, _BrainType.auditory),
    _Choice('Bouges ou marches', Icons.directions_walk, _BrainType.kinesthetic),
    _Choice('Prends des notes', Icons.edit_note, _BrainType.analytical),
  ]),
  _Question('Tu préfères apprendre...', [
    _Choice('Avec des couleurs/graphiques', Icons.palette, _BrainType.visual),
    _Choice('En groupe de discussion', Icons.groups, _BrainType.auditory),
    _Choice('En faisant des projets', Icons.construction, _BrainType.kinesthetic),
    _Choice('Avec des quiz/tests', Icons.quiz, _BrainType.analytical),
  ]),
  _Question('Devant un examen, tu...', [
    _Choice('Revois tes schémas', Icons.photo_library, _BrainType.visual),
    _Choice('Révises avec un ami', Icons.people, _BrainType.auditory),
    _Choice('Fais des exercices', Icons.sports_score, _BrainType.kinesthetic),
    _Choice('Organises un planning', Icons.calendar_month, _BrainType.analytical),
  ]),
  _Question('Ton point fort ?', [
    _Choice('Bonne mémoire visuelle', Icons.remove_red_eye, _BrainType.visual),
    _Choice('Bon à l\'oral', Icons.campaign, _BrainType.auditory),
    _Choice('Débrouillard en pratique', Icons.handyman, _BrainType.kinesthetic),
    _Choice('Logique et rigoureux', Icons.psychology, _BrainType.analytical),
  ]),
];

class _BrainTypeGameScreenState extends State<BrainTypeGameScreen> {
  int _currentQ = 0;
  final Map<_BrainType, int> _scores = {
    _BrainType.visual: 0,
    _BrainType.auditory: 0,
    _BrainType.kinesthetic: 0,
    _BrainType.analytical: 0,
  };
  bool _showResult = false;
  late _BrainType _result;
  final GlobalKey _resultKey = GlobalKey();

  void _answer(_BrainType type) {
    _scores[type] = (_scores[type] ?? 0) + 1;
    if (_currentQ + 1 >= _questions.length) {
      _result = _scores.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      setState(() => _showResult = true);
      // Signaler au wrapper que le jeu est terminé → arrêter enregistrement
      GameRecordController.of(context)?.onGameFinished();
      // Conserver la partie. Ce jeu donne un PROFIL, pas un score de performance :
      // on garde le profil obtenu dans `details` et un score neutre, pour qu'il
      // compte dans « parties jouées » sans polluer le classement.
      GameResultsService.record(
        gameType: 'Type de Cerveau',
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
        title: const Text('Type de Cerveau'),
        backgroundColor: const Color(0xFF6C63FF),
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

    return LayoutBuilder(
      builder: (context, constraints) {
        final isSmall = constraints.maxWidth < 380 || constraints.maxHeight < 650;
        final titleFs = isSmall ? 16.0 : 20.0;
        final choiceFs = isSmall ? 13.0 : 15.0;
        final pad = isSmall ? 12.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  color: const Color(0xFF6C63FF),
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
                style: TextStyle(
                  fontSize: titleFs,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
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
                      padding: EdgeInsets.symmetric(
                        horizontal: pad,
                        vertical: isSmall ? 12 : 16,
                      ),
                      child: Row(
                        children: [
                          Icon(c.icon, color: const Color(0xFF6C63FF), size: 24),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Text(
                              c.text,
                              style: TextStyle(fontSize: choiceFs, fontWeight: FontWeight.w500),
                            ),
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
      },
    );
  }

  Widget _buildResult() {
    final profile = _profileData(_result);
    final pct = ((_scores[_result] ?? 0) / _questions.length * 100).round();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Carte résultat (capturable pour partage)
          RepaintBoundary(
            key: _resultKey,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [profile.color, profile.color.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                children: [
                  Icon(profile.icon, size: 56, color: Colors.white),
                  const SizedBox(height: 12),
                  Text(
                    'Tu es un cerveau',
                    style: TextStyle(fontSize: 14, color: Colors.white.withValues(alpha: 0.85)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    profile.title,
                    style: const TextStyle(
                      fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$pct% de correspondance',
                    style: TextStyle(fontSize: 13, color: Colors.white.withValues(alpha: 0.8)),
                  ),
                  const SizedBox(height: 16),
                  // Forces
                  _resultChip('Forces : ${profile.strengths}'),
                  const SizedBox(height: 6),
                  _resultChip('Conseil : ${profile.advice}'),
                  const SizedBox(height: 12),
                  // Watermark
                  Text(
                    'Academia',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.5),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          // CTA Academia
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF0EDFF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              children: [
                Text(
                  profile.ctaTitle,
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                const SizedBox(height: 4),
                Text(
                  profile.ctaDescription,
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey[700]),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          // Boutons partage
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _shareResult,
              icon: const Icon(Icons.share, size: 20),
              label: const Text('Partager mon résultat'),
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

  Widget _resultChip(String text) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(fontSize: 12, color: Colors.white, height: 1.3),
      ),
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
      final xFile = XFile.fromData(bytes, mimeType: 'image/png', name: 'mon_type_de_cerveau.png');

      final profile = _profileData(_result);
      await Share.shareXFiles(
        [xFile],
        text: 'Je suis un cerveau ${profile.title} ! Et toi ? '
            'Découvre ton type sur Academia 🧠🔥',
        subject: 'Mon Type de Cerveau - Academia',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur de partage : $e')),
        );
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
  final String strengths;
  final String advice;
  final String ctaTitle;
  final String ctaDescription;
  const _ProfileData({
    required this.title,
    required this.icon,
    required this.color,
    required this.strengths,
    required this.advice,
    required this.ctaTitle,
    required this.ctaDescription,
  });
}

_ProfileData _profileData(_BrainType type) {
  switch (type) {
    case _BrainType.visual:
      return const _ProfileData(
        title: 'VISUEL',
        icon: Icons.visibility,
        color: Color(0xFF4CAF50),
        strengths: 'Mémoire photographique, bon en schémas et mind maps',
        advice: 'Utilise des couleurs, des graphiques et des vidéos pour réviser',
        ctaTitle: 'Adapté pour toi sur Academia',
        ctaDescription: 'Découvre les cours vidéo et les fiches visuelles dans les TD',
      );
    case _BrainType.auditory:
      return const _ProfileData(
        title: 'AUDITIF',
        icon: Icons.headphones,
        color: Color(0xFF2196F3),
        strengths: 'Bon à l\'oral, retient les discussions et explications',
        advice: 'Révise en groupe, écoute des podcasts, répète à voix haute',
        ctaTitle: 'Adapté pour toi sur Academia',
        ctaDescription: 'Rejoins les TD en groupe et les sessions live de révision',
      );
    case _BrainType.kinesthetic:
      return const _ProfileData(
        title: 'KINESTHÉSIQUE',
        icon: Icons.pan_tool,
        color: Color(0xFFFF9800),
        strengths: 'Apprend par la pratique, bon en TP et projets concrets',
        advice: 'Fais des exercices, des simulations et des cas pratiques',
        ctaTitle: 'Adapté pour toi sur Academia',
        ctaDescription: 'Teste les jeux éducatifs et les exercices interactifs',
      );
    case _BrainType.analytical:
      return const _ProfileData(
        title: 'ANALYTIQUE',
        icon: Icons.psychology,
        color: Color(0xFF9C27B0),
        strengths: 'Logique, rigoureux, bon en organisation et planification',
        advice: 'Fais des fiches structurées, des quiz et des plans de révision',
        ctaTitle: 'Adapté pour toi sur Academia',
        ctaDescription: 'Utilise la préparation concours et les quiz chronométrés',
      );
  }
}
