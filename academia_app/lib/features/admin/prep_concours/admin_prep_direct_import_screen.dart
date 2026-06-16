import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Écran admin pour importer des questions SANS consommation de tokens.
/// 3 modes : JSON structuré (fichier), JSON collé, Texte brut (sujet/corrigé).
class AdminPrepDirectImportScreen extends StatefulWidget {
  const AdminPrepDirectImportScreen({super.key});

  @override
  State<AdminPrepDirectImportScreen> createState() => _AdminPrepDirectImportScreenState();
}

class _AdminPrepDirectImportScreenState extends State<AdminPrepDirectImportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Shared metadata
  String? _concoursType;
  String? _subjectName;

  // JSON mode
  final _jsonController = TextEditingController();
  bool _jsonFromFile = false;

  // Text mode
  final _textController = TextEditingController();
  String _docType = 'sujet';

  // State
  bool _isImporting = false;
  String? _result;
  String? _error;

  final _concoursOptions = [
    'ENAREF', 'ADMIN_CIVIL', 'DOUANE', 'GREFFIERS', 'SANTE', 'EDUCATION', 'GRH', 'PARAMILITAIRE',
  ];

  final _subjectOptions = [
    'Culture Générale', 'Actualités BF', 'Droit Constitutionnel', 'Droit Administratif',
    'Économie', 'Finances Publiques', 'Fiscalité', 'Français', 'Mathématiques',
    'Tests Psychotechniques', 'Physique', 'Chimie', 'Biologie', 'Philosophie',
    'Histoire', 'Géographie',
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _jsonController.dispose();
    _textController.dispose();
    super.dispose();
  }

  // ─── Import JSON ──────────────────────────────────────────────────

  Future<void> _pickJsonFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;

    final content = await File(result.files.first.path!).readAsString();
    setState(() {
      _jsonController.text = content;
      _jsonFromFile = true;
    });
  }

  Future<void> _importJson() async {
    final text = _jsonController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Veuillez coller ou charger du JSON.');
      return;
    }

    dynamic parsed;
    try {
      parsed = jsonDecode(text);
    } catch (e) {
      setState(() => _error =
          'Le JSON est mal formaté. Vérifiez les accolades, crochets et virgules.\n'
          'Détail : $e');
      return;
    }

    List questions;
    if (parsed is List) {
      questions = parsed;
    } else if (parsed is Map && parsed['questions'] is List) {
      questions = parsed['questions'];
      _concoursType ??= parsed['concours_type']?.toString();
      _subjectName ??= parsed['subject']?.toString() ?? parsed['subject_name']?.toString();
    } else {
      setState(() => _error =
          'Format non reconnu.\n'
          'Attendu : un tableau [...] ou un objet {"questions": [...]}');
      return;
    }

    if (questions.isEmpty) {
      setState(() => _error = 'Aucune question trouvée dans le JSON.');
      return;
    }

    // Pré-validation locale
    final preErrors = <String>[];
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      if (q is! Map) {
        preErrors.add('Élément ${i + 1} : ce n\'est pas un objet JSON {...}');
        continue;
      }
      final hasText = (q['question'] ?? q['content'] ?? q['enonce'] ?? '') != '';
      if (!hasText) {
        preErrors.add('Question ${i + 1} : clé "question" manquante ou vide');
      }
    }
    if (preErrors.length == questions.length) {
      setState(() => _error =
          'Aucune question valide détectée :\n${preErrors.take(5).join('\n')}');
      return;
    }

    setState(() {
      _isImporting = true;
      _error = null;
      _result = null;
    });

    try {
      final client = Supabase.instance.client;
      final res = await client.rpc('app_admin_prep_import_questions_json', params: {
        'p_questions': questions,
        if (_concoursType != null) 'p_concours_type': _concoursType,
        if (_subjectName != null) 'p_subject_name': _subjectName,
        'p_source': 'admin_json_import',
      });

      if (res is Map && res['success'] == true) {
        final imported = res['imported_count'] ?? 0;
        final skipped = res['skipped_count'] ?? 0;
        final errors = res['errors'];
        var msg = '✅ $imported question(s) importée(s) avec succès !';
        if (skipped > 0) {
          msg += '\n⚠️ $skipped question(s) ignorée(s).';
        }
        msg += '\nPubliées et immédiatement disponibles pour les étudiants.';
        if (errors is List && errors.isNotEmpty) {
          msg += '\n\nDétails :\n${errors.take(5).join('\n')}';
        }
        setState(() => _result = msg);
      } else if (res is Map && res['error'] != null) {
        setState(() => _error = '${res['error']}');
      } else {
        setState(() => _error = 'Erreur inconnue lors de l\'import.');
      }
    } catch (e) {
      setState(() => _error = _parseFrenchError(e));
    } finally {
      setState(() => _isImporting = false);
    }
  }

  String _parseFrenchError(Object e) {
    final msg = e.toString();
    if (msg.contains('FunctionException')) {
      return 'Erreur serveur lors de l\'import. Vérifiez votre connexion et réessayez.';
    }
    if (msg.contains('SocketException') || msg.contains('TimeoutException')) {
      return 'Impossible de contacter le serveur. Vérifiez votre connexion internet.';
    }
    if (msg.contains('not_authenticated') || msg.contains('Non authentifié')) {
      return 'Session expirée. Veuillez vous reconnecter.';
    }
    return 'Erreur inattendue : $msg';
  }

  // ─── Import Texte brut ────────────────────────────────────────────

  Future<void> _importText() async {
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Veuillez coller du texte avant d\'indexer.');
      return;
    }

    if (text.length < 50) {
      setState(() => _error =
          'Le texte est trop court (${text.length} caractères).\n'
          'Minimum requis : 50 caractères.');
      return;
    }

    setState(() {
      _isImporting = true;
      _error = null;
      _result = null;
    });

    try {
      final client = Supabase.instance.client;
      final res = await client.rpc('app_admin_prep_import_text_bulk', params: {
        'p_text': text,
        if (_concoursType != null) 'p_concours_type': _concoursType,
        if (_subjectName != null) 'p_subject_name': _subjectName,
        'p_doc_type': _docType,
      });

      if (res is Map && res['success'] == true) {
        final msg = res['message'] ?? 'Texte indexé avec succès.';
        setState(() {
          _result = '✅ $msg\n'
              'Type : $_docType\n'
              'L\'IA utilisera ce contenu pour générer des questions et améliorer ses réponses.';
        });
      } else if (res is Map && res['error'] != null) {
        setState(() => _error = '${res['error']}');
      } else {
        setState(() => _error = 'Erreur inconnue lors de l\'indexation.');
      }
    } catch (e) {
      setState(() => _error = _parseFrenchError(e));
    } finally {
      setState(() => _isImporting = false);
    }
  }

  // ─── Build ────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Import direct (0 token)'),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF059669), Color(0xFF047857)],
            ),
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.code, size: 18), text: 'JSON structuré'),
            Tab(icon: Icon(Icons.text_snippet, size: 18), text: 'Texte brut'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Métadonnées communes
          _buildMetadataBar(),

          // Tabs
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildJsonTab(),
                _buildTextTab(),
              ],
            ),
          ),

          // Résultat / Erreur
          if (_result != null || _error != null)
            _buildResultBar(),
        ],
      ),
    );
  }

  Widget _buildMetadataBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Row(
        children: [
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _concoursType,
              decoration: const InputDecoration(
                labelText: 'Concours',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: _concoursOptions.map((c) => DropdownMenuItem(value: c, child: Text(c, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _concoursType = v),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String>(
              value: _subjectName,
              decoration: const InputDecoration(
                labelText: 'Matière',
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              ),
              items: _subjectOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 12)))).toList(),
              onChanged: (v) => setState(() => _subjectName = v),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildJsonTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF059669).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF059669).withAlpha(40)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.eco, color: Color(0xFF059669), size: 20),
                    SizedBox(width: 8),
                    Text('0 token consommé', style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF059669))),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Les questions sont insérées directement dans la base et immédiatement disponibles pour les étudiants.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Format example
          ExpansionTile(
            title: const Text('Format JSON attendu', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            leading: const Icon(Icons.help_outline, size: 20),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey[100],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const SelectableText(
                  'Format minimal :\n'
                  '[{"question": "...", "options": [...], "correct_index": 0}]\n\n'
                  'Exemple complet :\n'
                  '[\n'
                  '  {\n'
                  '    "question": "Quelle est la capitale du BF ?",\n'
                  '    "options": ["Bobo", "Ouaga", "Koudougou", "Banfora"],\n'
                  '    "correct_index": 1,\n'
                  '    "explanation": "Ouagadougou est la capitale.",\n'
                  '    "difficulty": 2\n'
                  '  }\n'
                  ']\n\n'
                  'Clés acceptées :\n'
                  '• question / content / enonce (obligatoire)\n'
                  '• options (tableau, optionnel)\n'
                  '• correct_index / reponse_correcte (défaut: 0)\n'
                  '• explanation / explication / correction\n'
                  '• difficulty / difficulte (1-5, défaut: 2)',
                  style: TextStyle(fontSize: 11, fontFamily: 'monospace'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _pickJsonFile,
                  icon: const Icon(Icons.file_open, size: 18),
                  label: Text(_jsonFromFile ? 'Fichier chargé ✓' : 'Charger fichier .json'),
                ),
              ),
              const SizedBox(width: 8),
              const Text('ou', style: TextStyle(color: Colors.grey)),
              const SizedBox(width: 8),
              const Text('collez ci-dessous', style: TextStyle(fontSize: 12, color: Colors.grey)),
            ],
          ),
          const SizedBox(height: 12),

          // JSON input
          TextField(
            controller: _jsonController,
            maxLines: 12,
            decoration: const InputDecoration(
              hintText: 'Collez votre JSON ici...',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 12, fontFamily: 'monospace'),
          ),
          const SizedBox(height: 16),

          // Import button
          ElevatedButton.icon(
            onPressed: _isImporting ? null : _importJson,
            icon: _isImporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload),
            label: Text(_isImporting ? 'Import en cours...' : 'Importer les questions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF059669),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Info card
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.blue.withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue.withAlpha(40)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.library_books, color: Colors.blue, size: 20),
                    SizedBox(width: 8),
                    Text('Nourrir la base de connaissances', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue)),
                  ],
                ),
                SizedBox(height: 6),
                Text(
                  'Collez un sujet, un corrigé ou des annales. Le texte sera indexé et l\'IA l\'utilisera pour '
                  'générer des questions plus pertinentes et améliorer ses réponses.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Doc type
          DropdownButtonFormField<String>(
            value: _docType,
            decoration: const InputDecoration(
              labelText: 'Type de document',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'sujet', child: Text('Sujet d\'épreuve')),
              DropdownMenuItem(value: 'corrige', child: Text('Corrigé')),
              DropdownMenuItem(value: 'annale', child: Text('Annale complète')),
              DropdownMenuItem(value: 'cours', child: Text('Support de cours')),
            ],
            onChanged: (v) => setState(() => _docType = v ?? 'sujet'),
          ),
          const SizedBox(height: 12),

          // Text input
          TextField(
            controller: _textController,
            maxLines: 15,
            decoration: const InputDecoration(
              hintText: 'Collez le texte du sujet, corrigé ou annale ici...\n\n'
                  'Exemple:\n'
                  '1. Quelle est la capitale du Burkina Faso ?\n'
                  'A) Bobo-Dioulasso\n'
                  'B) Ouagadougou\n'
                  'C) Koudougou\n'
                  'D) Banfora\n\n'
                  '2. En quelle année...',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 13),
          ),
          const SizedBox(height: 8),
          Text(
            '${_textController.text.length} caractères',
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
          const SizedBox(height: 16),

          // Import button
          ElevatedButton.icon(
            onPressed: _isImporting ? null : _importText,
            icon: _isImporting
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_isImporting ? 'Indexation en cours...' : 'Indexer dans la base IA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResultBar() {
    final isError = _error != null;
    return Container(
      padding: const EdgeInsets.all(14),
      color: isError ? Colors.red[50] : Colors.green[50],
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline : Icons.check_circle,
            color: isError ? Colors.red : Colors.green,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isError ? _error! : _result!,
              style: TextStyle(
                fontSize: 12,
                color: isError ? Colors.red[800] : Colors.green[800],
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => setState(() {
              _error = null;
              _result = null;
            }),
          ),
        ],
      ),
    );
  }
}
