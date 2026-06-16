import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Écran admin TD pour importer des questions/contenus SANS consommation de tokens.
/// 2 onglets : JSON structuré (questions prêtes) et Texte brut (sujet/corrigé/cours).
class AdminTdDirectImportScreen extends StatefulWidget {
  const AdminTdDirectImportScreen({super.key});

  @override
  State<AdminTdDirectImportScreen> createState() =>
      _AdminTdDirectImportScreenState();
}

class _AdminTdDirectImportScreenState extends State<AdminTdDirectImportScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Metadata
  String? _subject;
  String? _university;
  String? _studyYear;

  // JSON tab
  final _jsonController = TextEditingController();
  bool _jsonFromFile = false;

  // Text tab
  final _textController = TextEditingController();
  String _docType = 'exercice';

  // State
  bool _isImporting = false;
  String? _result;
  String? _error;

  static const _subjectOptions = [
    'Mathématiques',
    'Physique',
    'Chimie',
    'Biologie',
    'Informatique',
    'Économie',
    'Droit',
    'Comptabilité',
    'Gestion',
    'Français',
    'Anglais',
    'Philosophie',
    'Histoire-Géo',
  ];

  static const _levelOptions = [
    'Licence 1',
    'Licence 2',
    'Licence 3',
    'Master 1',
    'Master 2',
    'BTS',
    'Terminale',
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
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) return;

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
      _subject ??= parsed['subject']?.toString();
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
      final res = await Supabase.instance.client
          .rpc('app_td_admin_import_questions_json', params: {
        'p_questions': questions,
        if (_subject != null) 'p_subject': _subject,
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
      final res = await Supabase.instance.client
          .rpc('app_td_admin_import_text_bulk', params: {
        'p_text': text,
        if (_subject != null) 'p_subject': _subject,
        if (_university != null) 'p_university': _university,
        if (_studyYear != null) 'p_study_year': _studyYear,
        'p_doc_type': _docType,
      });

      if (res is Map && res['success'] == true) {
        final msg = res['message'] ?? 'Texte indexé avec succès.';
        setState(() {
          _result = '✅ $msg\n'
              'Type : $_docType\n'
              'L\'IA utilisera ce contenu pour générer des exercices.';
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
        title: const Text('Import direct TD (0 token)'),
        foregroundColor: Colors.white,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF7C3AED), Color(0xFF6D28D9)],
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
            Tab(
                icon: Icon(Icons.text_snippet, size: 18),
                text: 'Texte brut'),
          ],
        ),
      ),
      body: Column(
        children: [
          _buildMetadataBar(),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [_buildJsonTab(), _buildTextTab()],
            ),
          ),
          if (_result != null || _error != null) _buildResultBar(),
        ],
      ),
    );
  }

  Widget _buildMetadataBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _subject,
                  decoration: const InputDecoration(
                    labelText: 'Matière',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: _subjectOptions
                      .map((s) => DropdownMenuItem(
                          value: s,
                          child:
                              Text(s, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setState(() => _subject = v),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _studyYear,
                  decoration: const InputDecoration(
                    labelText: 'Niveau',
                    border: OutlineInputBorder(),
                    isDense: true,
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  ),
                  items: _levelOptions
                      .map((l) => DropdownMenuItem(
                          value: l,
                          child:
                              Text(l, style: const TextStyle(fontSize: 12))))
                      .toList(),
                  onChanged: (v) => setState(() => _studyYear = v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextFormField(
            decoration: const InputDecoration(
              labelText: 'Université (optionnel)',
              border: OutlineInputBorder(),
              isDense: true,
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            style: const TextStyle(fontSize: 12),
            onChanged: (v) =>
                _university = v.trim().isEmpty ? null : v.trim(),
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
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withAlpha(20),
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: const Color(0xFF7C3AED).withAlpha(40)),
            ),
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Icon(Icons.eco, color: Color(0xFF7C3AED), size: 20),
                  SizedBox(width: 8),
                  Text('0 token consommé',
                      style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF7C3AED))),
                ]),
                SizedBox(height: 6),
                Text(
                  'Les questions sont insérées directement dans la base TD '
                  'et immédiatement disponibles pour les étudiants.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          ExpansionTile(
            title: const Text('Format JSON attendu',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
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
                  '    "question": "Calculer la dérivée de f(x)=x²+3x",\n'
                  '    "options": ["2x+3", "x²+3", "2x", "3x+2"],\n'
                  '    "correct_index": 0,\n'
                  '    "explanation": "f\'(x) = 2x + 3",\n'
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
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _pickJsonFile,
                icon: const Icon(Icons.file_open, size: 18),
                label: Text(
                    _jsonFromFile ? 'Fichier chargé ✓' : 'Charger .json'),
              ),
            ),
            const SizedBox(width: 8),
            const Text('ou collez ci-dessous',
                style: TextStyle(fontSize: 12, color: Colors.grey)),
          ]),
          const SizedBox(height: 12),
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
          ElevatedButton.icon(
            onPressed: _isImporting ? null : _importJson,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload),
            label: Text(
                _isImporting ? 'Import en cours...' : 'Importer les questions'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF7C3AED),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
                Row(children: [
                  Icon(Icons.library_books, color: Colors.blue, size: 20),
                  SizedBox(width: 8),
                  Text('Nourrir la base de connaissances TD',
                      style: TextStyle(
                          fontWeight: FontWeight.bold, color: Colors.blue)),
                ]),
                SizedBox(height: 6),
                Text(
                  'Collez un exercice, un corrigé-type ou un support de cours. '
                  'Le texte sera indexé et l\'IA l\'utilisera pour générer '
                  'des exercices et améliorer les corrections.',
                  style: TextStyle(fontSize: 12, color: Colors.black87),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: _docType,
            decoration: const InputDecoration(
              labelText: 'Type de document',
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(value: 'exercice', child: Text('Exercice')),
              DropdownMenuItem(value: 'corrige', child: Text('Corrigé-type')),
              DropdownMenuItem(value: 'examen', child: Text('Sujet d\'examen')),
              DropdownMenuItem(value: 'cours', child: Text('Support de cours')),
            ],
            onChanged: (v) => setState(() => _docType = v ?? 'exercice'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            maxLines: 15,
            decoration: const InputDecoration(
              hintText:
                  'Collez le texte de l\'exercice, corrigé ou cours ici...',
              border: OutlineInputBorder(),
              filled: true,
              fillColor: Colors.white,
            ),
            style: const TextStyle(fontSize: 13),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 4),
          Text('${_textController.text.length} caractères',
              style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _isImporting ? null : _importText,
            icon: _isImporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.save),
            label: Text(_isImporting
                ? 'Indexation en cours...'
                : 'Indexer dans la base IA'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
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
          Icon(isError ? Icons.error_outline : Icons.check_circle,
              color: isError ? Colors.red : Colors.green),
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
