import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../providers/admin_prep_concours_provider.dart';
import '../../../providers/prep_concours_provider.dart';

/// Écran admin pour importer les questions du document scanné dans Supabase
class AdminPrepImportScreen extends StatefulWidget {
  const AdminPrepImportScreen({super.key});

  @override
  State<AdminPrepImportScreen> createState() => _AdminPrepImportScreenState();
}

class _AdminPrepImportScreenState extends State<AdminPrepImportScreen> {
  bool _isRunning = false;
  String _log = '';
  Map<String, int> _results = {};
  bool _done = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<PrepConcoursProvider>().loadSubjects();
    });
  }

  void _appendLog(String msg) {
    setState(() {
      _log += '• $msg\n';
    });
  }

  Future<void> _runImport() async {
    setState(() {
      _isRunning = true;
      _log = '';
      _results = {};
      _done = false;
    });

    final prepProvider = context.read<PrepConcoursProvider>();
    final adminProvider = context.read<AdminPrepConcoursProvider>();

    _appendLog('Chargement des matières depuis Supabase...');
    await prepProvider.loadSubjects();
    final subjects = prepProvider.subjects;

    if (subjects.isEmpty) {
      _appendLog('❌ Aucune matière trouvée. Exécutez d\'abord le SQL de seed.');
      setState(() => _isRunning = false);
      return;
    }

    // Construire le mapping slug → id
    // Le JSON utilise des slugs comme "mathématiques", "physique", etc.
    // On mappe les titres normalisés aux IDs Supabase
    final subjectSlugToId = <String, String>{};
    for (final s in subjects) {
      final normalized = s.title.toLowerCase()
          .replaceAll('é', 'e').replaceAll('è', 'e').replaceAll('ê', 'e')
          .replaceAll('à', 'a').replaceAll('â', 'a')
          .replaceAll('ô', 'o').replaceAll('î', 'i')
          .replaceAll('ù', 'u').replaceAll('û', 'u')
          .trim();
      subjectSlugToId[normalized] = s.id;
      // Aussi stocker le titre direct
      subjectSlugToId[s.title.toLowerCase().trim()] = s.id;
      // Et le slug Supabase
      subjectSlugToId[s.slug.toLowerCase().trim()] = s.id;
    }

    _appendLog('${subjects.length} matière(s) chargée(s):');
    for (final s in subjects) {
      _appendLog('  → ${s.title} (${s.id.substring(0, 8)}...)');
    }

    _appendLog('\nDémarrage de l\'injection des questions...');

    final results = await adminProvider.importQuestionsFromAsset(
      subjectSlugToId: subjectSlugToId,
    );

    if (results.isEmpty) {
      final err = adminProvider.error;
      _appendLog('❌ Aucune question injectée.');
      if (err != null) _appendLog('Erreur: $err');
    } else {
      int total = 0;
      for (final entry in results.entries) {
        _appendLog('✅ ${entry.key}: ${entry.value} question(s) publiée(s)');
        total += entry.value;
      }
      _appendLog('\n🎉 Total: $total question(s) injectée(s) avec succès!');
    }

    setState(() {
      _results = results;
      _isRunning = false;
      _done = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Import questions — Document scanné'),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFA3D65C), Color(0xFF1EA75C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoCard(),
            const SizedBox(height: 16),
            _buildPrerequisiteCard(),
            const SizedBox(height: 16),
            _buildActionCard(),
            if (_log.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildLogCard(),
            ],
            if (_done && _results.isNotEmpty) ...[
              const SizedBox(height: 16),
              _buildResultsCard(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.info_outline, color: Color(0xFF1EA75C)),
                SizedBox(width: 8),
                Text(
                  'Source des questions',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              'Ce module injecte les questions extraites du document de préparation '
              'au concours (Burkina Faso) scanné à l\'envers et reconverti.\n\n'
              'Matières: Mathématiques, Physique, Chimie, Biologie, Économie, Droit\n'
              'Source: assets/data/prep_concours_questions_burkina.json\n'
              'Nombre de questions: 20',
              style: TextStyle(fontSize: 13, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPrerequisiteCard() {
    return Card(
      elevation: 0,
      color: const Color(0xFFFFF8E1),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFFFFCC02), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded, color: Color(0xFFF59E0B)),
                SizedBox(width: 8),
                Text(
                  'Prérequis',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ],
            ),
            SizedBox(height: 8),
            Text(
              '1. Exécutez d\'abord le script SQL:\n'
              '   .windsurf/sql_changes/20260324_inject_scanned_questions.sql\n'
              '   dans l\'éditeur SQL de Supabase.\n\n'
              '2. Ce script crée les matières, chapitres et questions directement.\n\n'
              '3. Ce bouton injecte via les RPCs (méthode alternative via IA).',
              style: TextStyle(fontSize: 12, color: Colors.black87),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Text(
              'Injection via RPCs Admin',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 8),
            const Text(
              'Cette action crée une génération IA validée pour chaque matière '
              'et la publie immédiatement. Les matières doivent exister dans Supabase.',
              style: TextStyle(fontSize: 12, color: Colors.black54),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _isRunning ? null : _runImport,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1EA75C),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: _isRunning
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.upload_rounded),
                label: Text(
                  _isRunning ? 'Injection en cours...' : 'Lancer l\'injection',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLogCard() {
    return Card(
      elevation: 0,
      color: const Color(0xFF1A1A2E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Log d\'exécution',
              style: TextStyle(
                color: Colors.white70,
                fontWeight: FontWeight.bold,
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _log,
              style: const TextStyle(
                color: Color(0xFF4ADE80),
                fontFamily: 'monospace',
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsCard() {
    final total = _results.values.fold(0, (a, b) => a + b);
    return Card(
      elevation: 0,
      color: const Color(0xFFE8F5E9),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: Color(0xFF1EA75C), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const Icon(Icons.check_circle, color: Color(0xFF1EA75C), size: 40),
            const SizedBox(height: 8),
            Text(
              '$total questions injectées',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Color(0xFF1EA75C),
              ),
            ),
            const SizedBox(height: 8),
            ..._results.entries.map((e) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(e.key, style: const TextStyle(fontSize: 13)),
                      Text(
                        '${e.value} questions',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1EA75C),
                        ),
                      ),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}
