import 'dart:io';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../providers/admin_prep_concours_provider.dart';
import '../../../theme/prep_theme.dart';

/// Écran admin pour uploader des sujets PDF/Image et déclencher l'indexation/génération/analyse IA.
class AdminPrepUploadScreen extends StatefulWidget {
  const AdminPrepUploadScreen({super.key});

  @override
  State<AdminPrepUploadScreen> createState() => _AdminPrepUploadScreenState();
}

class _AdminPrepUploadScreenState extends State<AdminPrepUploadScreen> {
  bool _uploading = false;
  bool _loadingPredictions = false;
  String? _uploadStatus;
  List<Map<String, dynamic>> _predictions = [];

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    setState(() => _loadingPredictions = true);
    try {
      final res = await Supabase.instance.client.rpc('app_prep_get_predictions', params: {
        'p_min_score': 0,
        'p_limit': 30,
      });
      if (res is Map && res['success'] == true && res['predictions'] is List) {
        _predictions = (res['predictions'] as List)
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      }
    } catch (e) {
      debugPrint('[AdminPrepUpload] Erreur chargement prédictions: $e');
    }
    if (mounted) setState(() => _loadingPredictions = false);
  }

  Future<void> _uploadDocument({bool imageMode = false}) async {
    final PlatformFile? file;

    if (imageMode) {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'jpeg', 'png', 'webp'],
      );
      if (result == null || result.files.isEmpty) return;
      file = result.files.first;
    } else {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null || result.files.isEmpty) return;
      file = result.files.first;
    }

    if (file == null || file.path == null) return;

    // Show metadata dialog
    if (!mounted) return;
    final meta = await _showMetadataDialog();
    if (meta == null) return;

    final ext = file.name.split('.').last.toLowerCase();
    final isPdf = ext == 'pdf';
    final contentType = isPdf
        ? 'application/pdf'
        : ext == 'png'
            ? 'image/png'
            : 'image/jpeg';

    setState(() {
      _uploading = true;
      _uploadStatus = 'Téléversement en cours...';
    });

    try {
      final client = Supabase.instance.client;
      final userId = client.auth.currentUser?.id ?? 'admin';
      final filename = file.name;
      final storagePath = '$userId/${DateTime.now().millisecondsSinceEpoch}_$filename';

      // 1. Upload to Storage
      await client.storage.from('prep-documents').upload(
        storagePath,
        File(file.path!),
        fileOptions: FileOptions(contentType: contentType),
      );

      setState(() => _uploadStatus = 'Création du document en base...');

      // 2. Create source document record
      final provider = context.read<AdminPrepConcoursProvider>();
      final ok = await provider.upsertSourceDocument(
        storageBucket: 'prep-documents',
        storagePath: storagePath,
        sourceType: isPdf ? 'pdf' : 'image',
        docType: meta['doc_type'],
        year: meta['year'],
        subjectId: meta['subject_id'],
        status: 'received',
      );

      if (!ok) {
        setState(() => _uploadStatus = 'Erreur lors de la création du document : ${provider.error ?? "erreur inconnue"}');
        return;
      }

      // 3. Get the document ID (last inserted)
      await provider.loadSourceDocuments();
      final docs = provider.documents;
      if (docs.isNotEmpty) {
        final docId = docs.first.id;

        setState(() => _uploadStatus = 'Indexation IA en cours (peut prendre quelques secondes)...');

        // 4. Trigger ingestion Edge Function
        final ingested = await provider.triggerIngestion(documentId: docId);
        if (ingested) {
          setState(() => _uploadStatus = '✅ Indexation terminée avec succès.');
        } else {
          setState(() => _uploadStatus = '⚠️ Document uploadé mais l\'indexation a échoué. Relancez-la manuellement.');
        }
      }
    } catch (e) {
      setState(() => _uploadStatus = _parseFrenchError(e));
    } finally {
      setState(() => _uploading = false);
    }
  }

  String _parseFrenchError(Object e) {
    final msg = e.toString();
    if (msg.contains('StorageException') || msg.contains('storage')) {
      return 'Erreur lors du téléversement du fichier. Vérifiez la taille et réessayez.';
    }
    if (msg.contains('SocketException') || msg.contains('TimeoutException')) {
      return 'Impossible de contacter le serveur. Vérifiez votre connexion internet.';
    }
    if (msg.contains('not_authenticated') || msg.contains('Non authentifié')) {
      return 'Session expirée. Veuillez vous reconnecter.';
    }
    if (msg.contains('FunctionException')) {
      return 'Erreur serveur lors du traitement. Réessayez dans quelques instants.';
    }
    return 'Erreur inattendue : $msg';
  }

  Future<Map<String, dynamic>?> _showMetadataDialog() async {
    String? concoursType;
    String? subjectName;
    String? docType = 'sujet';
    final yearCtrl = TextEditingController(text: '2024');

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Text('Métadonnées du document',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: concoursType,
                  decoration: const InputDecoration(labelText: 'Concours *', border: OutlineInputBorder()),
                  items: ['ENAREF', 'ADMIN_CIVIL', 'DOUANE', 'GREFFIERS', 'SANTE', 'EDUCATION', 'GRH', 'PARAMILITAIRE', 'TOUS']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (v) => setDialogState(() => concoursType = v),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: subjectName,
                  decoration: const InputDecoration(labelText: 'Matière', border: OutlineInputBorder()),
                  items: ['Culture Générale', 'Actualités BF', 'Droit Constitutionnel', 'Droit Administratif',
                          'Économie', 'Finances Publiques', 'Fiscalité', 'Français', 'Tests Psychotechniques', 'Mathématiques']
                      .map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                  onChanged: (v) => setDialogState(() => subjectName = v),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: yearCtrl,
                  decoration: const InputDecoration(labelText: 'Année', border: OutlineInputBorder()),
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: docType,
                  decoration: const InputDecoration(labelText: 'Type de document', border: OutlineInputBorder()),
                  items: const [
                    DropdownMenuItem(value: 'sujet', child: Text('Sujet d\'épreuve')),
                    DropdownMenuItem(value: 'corrige', child: Text('Corrigé')),
                    DropdownMenuItem(value: 'cours', child: Text('Support de cours')),
                    DropdownMenuItem(value: 'annale', child: Text('Annale complète')),
                  ],
                  onChanged: (v) => setDialogState(() => docType = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: PrepTheme.primary),
              onPressed: () {
                Navigator.of(ctx).pop({
                  'concours_type': concoursType,
                  'subject_name': subjectName,
                  'year': int.tryParse(yearCtrl.text.trim()),
                  'doc_type': docType,
                });
              },
              child: const Text('Continuer', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _triggerGeneration() async {
    final provider = context.read<AdminPrepConcoursProvider>();
    setState(() => _uploadStatus = 'Génération de questions IA en cours...');

    final result = await provider.triggerGenerateQuestions(
      count: 10,
      mode: 'similar',
    );

    if (result != null) {
      final count = result['inserted_count'] ?? 0;
      setState(() => _uploadStatus = '✅ $count question(s) générée(s) avec succès.');
    } else {
      setState(() => _uploadStatus = provider.error ?? 'Erreur lors de la génération des questions.');
    }
  }

  Future<void> _triggerAnalysis() async {
    final provider = context.read<AdminPrepConcoursProvider>();
    setState(() => _uploadStatus = 'Analyse des tendances en cours...');

    final result = await provider.triggerAnalyzeTrends(targetYear: '2026');

    if (result != null) {
      final topics = result['topics_created'] ?? 0;
      final preds = result['predictions_created'] ?? 0;
      setState(() => _uploadStatus = '✅ $topics thème(s) et $preds prédiction(s) créé(s).');
      _loadPredictions();
    } else {
      setState(() => _uploadStatus = provider.error ?? 'Erreur lors de l\'analyse des tendances.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
      children: [
        // Upload section
        Container(
          padding: const EdgeInsets.all(20),
          decoration: PrepTheme.gradientBox(PrepTheme.headerGradient, radius: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  Icon(Icons.upload_file, color: Colors.white, size: 24),
                  SizedBox(width: 10),
                  Text('Upload de sujets réels',
                      style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Uploadez des PDF de sujets de concours du Burkina Faso. L\'IA les indexera automatiquement.',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : () => _uploadDocument(),
                      icon: _uploading
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.picture_as_pdf, size: 18),
                      label: Text(_uploading ? 'En cours...' : 'PDF'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: PrepTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _uploading ? null : () => _uploadDocument(imageMode: true),
                      icon: const Icon(Icons.image, size: 18),
                      label: const Text('Image'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: PrepTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
              if (_uploadStatus != null) ...[
                const SizedBox(height: 10),
                Text(_uploadStatus!, style: const TextStyle(color: Colors.white, fontSize: 12)),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Quick actions
        Row(
          children: [
            Expanded(
              child: _ActionButton(
                icon: Icons.auto_awesome,
                label: 'Générer QCM',
                color: PrepTheme.xpPurple,
                onTap: _triggerGeneration,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _ActionButton(
                icon: Icons.trending_up,
                label: 'Analyser tendances',
                color: PrepTheme.accent,
                onTap: _triggerAnalysis,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        // Predictions section
        Row(
          children: [
            const Icon(Icons.auto_graph, color: PrepTheme.accent, size: 20),
            const SizedBox(width: 8),
            const Expanded(
              child: Text('Prédictions sujets probables',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: PrepTheme.textPrimary)),
            ),
            IconButton(
              onPressed: _loadPredictions,
              icon: const Icon(Icons.refresh, size: 18, color: PrepTheme.textTertiary),
            ),
          ],
        ),
        const SizedBox(height: 10),

        if (_loadingPredictions)
          const Center(child: Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator()))
        else if (_predictions.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: PrepTheme.cardBox(),
            child: const Column(
              children: [
                Icon(Icons.auto_graph, size: 36, color: PrepTheme.textTertiary),
                SizedBox(height: 8),
                Text('Aucune prédiction disponible',
                    style: TextStyle(color: PrepTheme.textTertiary, fontSize: 13)),
                SizedBox(height: 4),
                Text('Téléversez des sujets puis lancez l\'analyse des tendances.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: PrepTheme.textTertiary, fontSize: 11)),
              ],
            ),
          )
        else
          ..._predictions.map((p) => _PredictionCard(prediction: p)),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionButton({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: color.withAlpha(20),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withAlpha(60)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 6),
            Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color)),
          ],
        ),
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final Map<String, dynamic> prediction;

  const _PredictionCard({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final topicName = (prediction['topic_name'] ?? '').toString();
    final category = (prediction['topic_category'] ?? '').toString();
    final concours = (prediction['concours_type'] ?? '').toString();
    final score = (prediction['probability_score'] as int?) ?? 0;
    final frequency = (prediction['frequency_count'] as int?) ?? 0;
    final lastYear = (prediction['last_appeared_year'] ?? '').toString();
    final reasoning = (prediction['reasoning'] ?? '').toString();

    Color scoreColor;
    String scoreLabel;
    if (score >= 90) { scoreColor = Colors.red; scoreLabel = 'Très probable'; }
    else if (score >= 70) { scoreColor = Colors.orange; scoreLabel = 'Probable'; }
    else if (score >= 50) { scoreColor = Colors.amber; scoreLabel = 'Possible'; }
    else { scoreColor = Colors.grey; scoreLabel = 'Peu probable'; }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: PrepTheme.cardBox(borderColor: scoreColor.withAlpha(60)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44, height: 44,
                decoration: BoxDecoration(color: scoreColor.withAlpha(30), borderRadius: BorderRadius.circular(10)),
                child: Center(child: Text('$score%', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: scoreColor))),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(topicName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(scoreLabel, style: TextStyle(fontSize: 11, color: scoreColor, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              if (concours.isNotEmpty) ...[PrepTheme.chip(concours, PrepTheme.primary), const SizedBox(width: 6)],
              if (category.isNotEmpty) PrepTheme.chip(category, PrepTheme.success),
              const Spacer(),
              if (frequency > 0) Text('$frequency× ', style: const TextStyle(fontSize: 10, color: PrepTheme.textTertiary)),
              if (lastYear.isNotEmpty) Text('Dernier: $lastYear', style: const TextStyle(fontSize: 10, color: PrepTheme.textTertiary)),
            ],
          ),
          if (reasoning.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(reasoning, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: PrepTheme.textSecondary, fontStyle: FontStyle.italic)),
          ],
        ],
      ),
    );
  }
}
