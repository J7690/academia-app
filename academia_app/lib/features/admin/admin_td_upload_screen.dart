import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../config/supabase_config.dart';
import '../../theme/td_theme.dart';

/// Admin — Upload PDF cours/sujets universitaires BF → pipeline TD séparé (td_doc_chunks).
class AdminTdUploadScreen extends StatefulWidget {
  const AdminTdUploadScreen({super.key});

  @override
  State<AdminTdUploadScreen> createState() => _AdminTdUploadScreenState();
}

class _AdminTdUploadScreenState extends State<AdminTdUploadScreen> {
  bool _uploading = false;
  String? _status;

  static const _universities = [
    'Université Joseph Ki-Zerbo', 'Université Nazi Boni', 'Université Norbert Zongo',
    'Université Thomas Sankara', 'Université Aube Nouvelle', 'Université Saint Thomas d\'Aquin',
    'UCAO - Burkina Faso', 'Université Virtuelle du BF', 'Autre',
  ];

  static const _subjects = [
    'Mathématiques', 'Physique', 'Chimie', 'Biologie',
    'Droit Civil', 'Droit Constitutionnel', 'Droit Administratif', 'Droit Pénal',
    'Économie', 'Microéconomie', 'Macroéconomie', 'Gestion', 'Comptabilité SYSCOHADA',
    'Informatique', 'Anglais', 'Français', 'Philosophie', 'Sociologie',
    'Histoire', 'Géographie', 'Médecine', 'Pharmacie', 'Agronomie',
  ];

  Future<void> _uploadPdf() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['pdf']);
    if (result == null || result.files.isEmpty || result.files.first.path == null) return;
    final file = result.files.first;

    if (!mounted) return;
    final meta = await _showMetadataDialog();
    if (meta == null) return;

    setState(() { _uploading = true; _status = 'Upload en cours...'; });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id ?? 'admin';
      final storagePath = 'td/$userId/${DateTime.now().millisecondsSinceEpoch}_${file.name}';

      await client.storage.from('prep-documents').upload(storagePath, File(file.path!),
          fileOptions: const FileOptions(contentType: 'application/pdf'));

      setState(() => _status = 'Création du document TD...');

      // Insert into td_source_documents (SEPARATE from prep)
      final insertSql = "INSERT INTO app.td_source_documents (created_by, subject, university, study_year, doc_type, storage_bucket, storage_path, original_filename, status) "
          "VALUES ('$userId', '${(meta['subject'] ?? '').toString().replaceAll("'", "''")}', "
          "'${(meta['university'] ?? '').toString().replaceAll("'", "''")}', "
          "'${(meta['study_year'] ?? '').toString().replaceAll("'", "''")}', "
          "'${(meta['doc_type'] ?? 'cours').toString().replaceAll("'", "''")}', "
          "'prep-documents', '$storagePath', '${file.name.replaceAll("'", "''")}', 'received') RETURNING id";

      final res = await client.rpc('admin_execute_sql', params: {'p_sql': insertSql});
      String? docId;
      if (res is Map && res['ok'] == true && res['rows'] is List && (res['rows'] as List).isNotEmpty) {
        docId = ((res['rows'] as List)[0] as Map)['id']?.toString();
      }

      if (docId != null) {
        setState(() => _status = 'Indexation IA en cours...');
        final session = client.auth.currentSession;
        if (session != null) {
          final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/td-ingest-document');
          final resp = await http.post(uri, headers: {
            'Authorization': 'Bearer ${session.accessToken}',
            'Content-Type': 'application/json',
            'apikey': SupabaseConfig.anonKey,
          }, body: jsonEncode({'document_id': docId})).timeout(const Duration(seconds: 120));

          if (resp.statusCode == 200) {
            final data = jsonDecode(resp.body);
            if (data is Map && data['success'] == true) {
              setState(() => _status = 'Indexé ✓ (${data['chunks_count']} chunks, ${data['page_count']} pages)');
            } else {
              setState(() => _status = 'Upload OK. Indexation à relancer.');
            }
          } else {
            setState(() => _status = 'Upload OK. Indexation échouée (${resp.statusCode}).');
          }
        }
      } else {
        setState(() => _status = 'Upload OK. Document créé.');
      }
    } catch (e) {
      setState(() => _status = 'Erreur: $e');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _triggerGenerateExercises() async {
    setState(() => _status = 'Génération d\'exercices IA...');
    try {
      final session = Supabase.instance.client.auth.currentSession;
      if (session == null) return;
      final uri = Uri.parse('${SupabaseConfig.url}/functions/v1/td-generate-exercises');
      final resp = await http.post(uri, headers: {
        'Authorization': 'Bearer ${session.accessToken}',
        'Content-Type': 'application/json',
        'apikey': SupabaseConfig.anonKey,
      }, body: jsonEncode({'count': 10, 'mode': 'exercise'})).timeout(const Duration(seconds: 60));

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        setState(() => _status = 'Généré ${data['inserted_count'] ?? 0} exercices dans td_questions ✓');
      } else {
        setState(() => _status = 'Erreur génération (${resp.statusCode})');
      }
    } catch (e) {
      setState(() => _status = 'Erreur: $e');
    }
  }

  Future<Map<String, dynamic>?> _showMetadataDialog() async {
    String? university;
    String? subject;
    String? studyYear;
    String docType = 'cours';

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Métadonnées du document', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
            DropdownButtonFormField<String>(
              value: university,
              decoration: const InputDecoration(labelText: 'Université *', border: OutlineInputBorder()),
              items: _universities.map((u) => DropdownMenuItem(value: u, child: Text(u, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setDialogState(() => university = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: subject,
              decoration: const InputDecoration(labelText: 'Matière *', border: OutlineInputBorder()),
              items: _subjects.map((s) => DropdownMenuItem(value: s, child: Text(s, style: const TextStyle(fontSize: 13)))).toList(),
              onChanged: (v) => setDialogState(() => subject = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: studyYear,
              decoration: const InputDecoration(labelText: 'Niveau', border: OutlineInputBorder()),
              items: ['L1', 'L2', 'L3', 'Master 1', 'Master 2', 'Doctorat', 'Tous niveaux']
                  .map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
              onChanged: (v) => setDialogState(() => studyYear = v),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: docType,
              decoration: const InputDecoration(labelText: 'Type', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'cours', child: Text('Cours / Support pédagogique')),
                DropdownMenuItem(value: 'td', child: Text('Feuille de TD')),
                DropdownMenuItem(value: 'examen', child: Text('Sujet d\'examen')),
                DropdownMenuItem(value: 'corrige', child: Text('Corrigé')),
              ],
              onChanged: (v) => setDialogState(() => docType = v ?? 'cours'),
            ),
          ])),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: TdTheme.adminTdPrimary),
              onPressed: () => Navigator.of(ctx).pop({'university': university, 'subject': subject, 'study_year': studyYear, 'doc_type': docType}),
              child: const Text('Continuer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TdTheme.scaffoldBg,
      appBar: AppBar(
        elevation: 0, centerTitle: false,
        title: const Text('Upload Contenu TD'),
        foregroundColor: Colors.white,
        flexibleSpace: Container(decoration: const BoxDecoration(gradient: LinearGradient(colors: TdTheme.adminTdGradient))),
      ),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        // Upload section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(gradient: const LinearGradient(colors: TdTheme.adminTdGradient), borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Row(children: [
              Icon(Icons.upload_file, color: Colors.white, size: 24),
              SizedBox(width: 10),
              Text('Upload cours / sujets universitaires', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
            ]),
            const SizedBox(height: 8),
            Text('Les PDF uploadés alimentent le pipeline TD séparé (td_doc_chunks).\nL\'IA s\'en inspirera pour le tuteur et la génération d\'exercices.',
                style: TextStyle(color: Colors.white.withAlpha(190), fontSize: 12)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: ElevatedButton.icon(
              onPressed: _uploading ? null : _uploadPdf,
              icon: _uploading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.upload, size: 18),
              label: Text(_uploading ? 'Upload en cours...' : 'Sélectionner un PDF'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: TdTheme.adminTdPrimary, padding: const EdgeInsets.symmetric(vertical: 14)),
            )),
            if (_status != null) ...[
              const SizedBox(height: 10),
              Text(_status!, style: const TextStyle(color: Colors.white, fontSize: 12)),
            ],
          ]),
        ),
        const SizedBox(height: 16),

        // Generate exercises button
        GestureDetector(
          onTap: _triggerGenerateExercises,
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF7C3AED).withAlpha(20), borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF7C3AED).withAlpha(60)),
            ),
            child: const Column(children: [
              Icon(Icons.auto_awesome, color: Color(0xFF7C3AED), size: 28),
              SizedBox(height: 6),
              Text('Générer des exercices IA', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: Color(0xFF7C3AED))),
              SizedBox(height: 2),
              Text('Insère dans td_questions (séparé du concours)', style: TextStyle(fontSize: 10, color: Color(0xFF9E9E9E))),
            ]),
          ),
        ),
        const SizedBox(height: 20),

        // Info
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: const Color(0xFFE3F2FD), borderRadius: BorderRadius.circular(12)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pipeline TD séparé', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: Color(0xFF1565C0))),
            SizedBox(height: 6),
            Text('• Les PDF uploadés ici vont dans td_source_documents\n• L\'indexation crée des chunks dans td_doc_chunks\n• Le tuteur IA TD utilise td-tutor-chat (séparé)\n• Les exercices générés vont dans td_questions\n• Rien ne se mélange avec le module Concours',
                style: TextStyle(fontSize: 11, color: Color(0xFF424242), height: 1.5)),
          ]),
        ),
      ]),
    );
  }
}
